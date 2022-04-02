//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SignalServiceKit
import SignalMessaging
import UIKit

@objc
public extension HomeViewController {

    func reloadTableDataAndResetCellContentCache() {
        AssertIsOnMainThread()

        cellContentCache.clear()
        conversationCellHeightCache = nil
        reloadTableData()
    }

    func reloadTableData() {
        AssertIsOnMainThread()

        tableView.reloadData()
    }

    func updateCellVisibility() {
        AssertIsOnMainThread()

        for cell in tableView.visibleCells {
            guard let cell = cell as? HomeViewCell else {
                continue
            }
            updateCellVisibility(cell: cell, isCellVisible: true)
        }
    }

    func updateCellVisibility(cell: HomeViewCell, isCellVisible: Bool) {
        AssertIsOnMainThread()

        cell.isCellVisible = self.isViewVisible && isCellVisible
    }

    func ensureCellAnimations() {
        AssertIsOnMainThread()

        for cell in tableView.visibleCells {
            guard let cell = cell as? HomeViewCell else {
                continue
            }
            cell.ensureCellAnimations()
        }
    }

    // MARK: -

    func showBadgeExpirationSheetIfNeeded() {
        guard !hasShownBadgeExpiration else { // Do this once per launch
            return
        }

        let expiredBadgeID = SubscriptionManager.mostRecentlyExpiredBadgeIDWithSneakyTransaction()
        guard let expiredBadgeID = expiredBadgeID else {
            Logger.info("No expired badgeIDs, not showing sheet")
            return
        }

        let shouldShow = databaseStorage.read { transaction in
            SubscriptionManager.showExpirySheetOnHomeScreenKey(transaction: transaction)
        }

        guard shouldShow else { return }

        Logger.info("showing expiry sheet for badge \(expiredBadgeID)")

        if BoostBadgeIds.contains(expiredBadgeID) {
            firstly {
                SubscriptionManager.getBoostBadge()
            }.done(on: .global()) { boostBadge in
                firstly {
                    self.profileManager.badgeStore.populateAssetsOnBadge(boostBadge)
                }.done(on: .main) {
                    // Make sure we're still the active VC
                    guard UIApplication.shared.frontmostViewController == self.conversationSplitViewController,
                          self.conversationSplitViewController?.selectedThread == nil else { return }

                    let badgeSheet = BadgeExpirationSheet(badge: boostBadge)
                    badgeSheet.delegate = self
                    self.present(badgeSheet, animated: true)
                    self.hasShownBadgeExpiration = true
                    self.databaseStorage.write { transaction in
                        SubscriptionManager.setShowExpirySheetOnHomeScreenKey(show: false, transaction: transaction)
                    }
                }.catch { error in
                    owsFailDebug("Failed to fetch boost badge assets for expiry \(error)")
                }
            }.catch { error in
                owsFailDebug("Failed to fetch boost badge for expiry \(error)")
            }
        } else if SubscriptionBadgeIds.contains(expiredBadgeID) {
            // Fetch current subscriptions, required to populate badge assets
            firstly {
                SubscriptionManager.getSubscriptions()
            }.done(on: .global()) { (subscriptions: [SubscriptionLevel]) in
                let subscriptionLevel = subscriptions.first { $0.badge.id == expiredBadgeID }
                guard let subscriptionLevel = subscriptionLevel else {
                    owsFailDebug("Unable to find matching subscription level for expired badge")
                    return
                }

                firstly {
                    self.profileManager.badgeStore.populateAssetsOnBadge(subscriptionLevel.badge)
                }.done(on: .main) {
                    // Make sure we're still the active VC
                    guard UIApplication.shared.frontmostViewController == self.conversationSplitViewController,
                          self.conversationSplitViewController?.selectedThread == nil else { return }

                    let badgeSheet = BadgeExpirationSheet(badge: subscriptionLevel.badge)
                    badgeSheet.delegate = self
                    self.present(badgeSheet, animated: true)
                    self.hasShownBadgeExpiration = true
                    self.databaseStorage.write { transaction in
                        SubscriptionManager.setShowExpirySheetOnHomeScreenKey(show: false, transaction: transaction)
                    }
                }.catch { error in
                    owsFailDebug("Failed to fetch subscription badge assets for expiry \(error)")
                }

            }.catch { error in
                owsFailDebug("Failed to fetch subscriptions for expiry \(error)")
            }
        }
    }

    // MARK: -

    func configureUnreadPaymentsBannerSingle(_ paymentsReminderView: UIView,
                                             paymentModel: TSPaymentModel,
                                             transaction: SDSAnyReadTransaction) {
    }

    func configureUnreadPaymentsBannerMultiple(_ paymentsReminderView: UIView,
                                               unreadCount: UInt) {
        let title: String
        if unreadCount == 1 {
            title = NSLocalizedString("PAYMENTS_NOTIFICATION_BANNER_1",
                                      comment: "Label for the payments notification banner for a single payment notification.")
        } else {
            let format = NSLocalizedString("PAYMENTS_NOTIFICATION_BANNER_N_FORMAT",
                                           comment: "Format for the payments notification banner for multiple payment notifications. Embeds: {{ the number of unread payment notifications }}.")
            title = String(format: format, OWSFormat.formatUInt(unreadCount))
        }

        let iconView = UIImageView.withTemplateImageName(Theme.iconName(.paymentNotification),
                                                         tintColor: (Theme.isDarkThemeEnabled
                                                                        ? .ows_gray15
                                                                        : .ows_white))
        iconView.autoSetDimensions(to: .square(24))
        let iconCircleView = OWSLayerView.circleView(size: CGFloat(Self.paymentsBannerAvatarSize))
        iconCircleView.backgroundColor = (Theme.isDarkThemeEnabled
                                            ? .ows_gray80
                                            : .ows_gray95)
        iconCircleView.addSubview(iconView)
        iconView.autoCenterInSuperview()

        configureUnreadPaymentsBanner(paymentsReminderView,
                                      title: title,
                                      avatarView: iconCircleView) { [weak self] in
            self?.showAppSettings(mode: .payments)
        }
    }

    private static let paymentsBannerAvatarSize: UInt = 40

    private class PaymentsBannerView: UIView {
        let block: () -> Void

        required init(block: @escaping () -> Void) {
            self.block = block

            super.init(frame: .zero)

            isUserInteractionEnabled = true
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc
        func didTap() {
            block()
        }
    }

    private func configureUnreadPaymentsBanner(_ paymentsReminderView: UIView,
                                               title: String,
                                               avatarView: UIView,
                                               block: @escaping () -> Void) {
        paymentsReminderView.removeAllSubviews()

        let paymentsBannerView = PaymentsBannerView(block: block)
        paymentsReminderView.addSubview(paymentsBannerView)
        paymentsBannerView.autoPinEdgesToSuperviewEdges()

        if UIDevice.current.isIPad {
            paymentsReminderView.backgroundColor = (Theme.isDarkThemeEnabled
                                                        ? .ows_gray75
                                                        : .ows_gray05)
        } else {
            paymentsReminderView.backgroundColor = (Theme.isDarkThemeEnabled
                                                        ? .ows_gray90
                                                        : .ows_gray02)
        }

        avatarView.setCompressionResistanceHigh()
        avatarView.setContentHuggingHigh()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = Theme.primaryTextColor
        titleLabel.font = UIFont.ows_dynamicTypeSubheadlineClamped.ows_semibold

        let viewLabel = UILabel()
        viewLabel.text = CommonStrings.viewButton
        viewLabel.textColor = Theme.accentBlueColor
        viewLabel.font = UIFont.ows_dynamicTypeSubheadlineClamped

        let textStack = UIStackView(arrangedSubviews: [ titleLabel, viewLabel ])
        textStack.axis = .vertical
        textStack.alignment = .leading

        let dismissButton = OWSLayerView.circleView(size: 20)
        dismissButton.backgroundColor = (Theme.isDarkThemeEnabled
                                            ? .ows_gray65
                                            : .ows_gray05)
        dismissButton.setCompressionResistanceHigh()
        dismissButton.setContentHuggingHigh()

        let dismissIcon = UIImageView.withTemplateImageName("x-16",
                                                            tintColor: (Theme.isDarkThemeEnabled
                                                                            ? .ows_white
                                                                            : .ows_gray60))
        dismissIcon.autoSetDimensions(to: .square(16))
        dismissButton.addSubview(dismissIcon)
        dismissIcon.autoCenterInSuperview()

        let stack = UIStackView(arrangedSubviews: [ avatarView,
                                                    textStack,
                                                    dismissButton ])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(
            top: OWSTableViewController2.cellVInnerMargin,
            left: OWSTableViewController2.cellHOuterLeftMargin(in: view),
            bottom: OWSTableViewController2.cellVInnerMargin,
            right: OWSTableViewController2.cellHOuterRightMargin(in: view)
        )
        stack.isLayoutMarginsRelativeArrangement = true
        paymentsBannerView.addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges()
    }
}

// MARK: -

public enum ShowAppSettingsMode {
    case none
    case payments
    case payment(paymentsHistoryItem: PaymentsHistoryItem)
    case paymentsTransferIn
    case appearance
    case avatarBuilder
    case subscriptions
    case boost
}

// MARK: -

public extension HomeViewController {

    @objc
    func createAvatarBarButtonViewWithSneakyTransaction() -> UIView {
        let avatarView = ConversationAvatarView(sizeClass: .twentyEight, localUserDisplayMode: .asUser)
        databaseStorage.read { readTx in
            avatarView.update(readTx) { config in
                if let address = tsAccountManager.localAddress(with: readTx) {
                    config.dataSource = .address(address)
                    config.applyConfigurationSynchronously()
                }
            }
        }
        return avatarView
    }

    @objc
    func showAppSettings() {
        showAppSettings(mode: .none)
    }

    @objc
    func showAppSettingsInAppearanceMode() {
        showAppSettings(mode: .appearance)
    }

    @objc
    func showAppSettingsInAvatarBuilderMode() {
        showAppSettings(mode: .avatarBuilder)
    }

    func showAppSettings(mode: ShowAppSettingsMode) {
        AssertIsOnMainThread()

        Logger.info("")

        // Dismiss any message actions if they're presented
        if FeatureFlags.contextMenus {
            conversationSplitViewController?.selectedConversationViewController?.dismissMessageContextMenu(animated: true)
        } else {
            conversationSplitViewController?.selectedConversationViewController?.dismissMessageActions(animated: true)
        }

        let navigationController = AppSettingsViewController.inModalNavigationController()

        var completion: (() -> Void)?

        var viewControllers = navigationController.viewControllers
        switch mode {
        case .none:
            break
        case .payments:
            let paymentsSettings = PaymentsSettingsViewController(mode: .inAppSettings)
            viewControllers += [ paymentsSettings ]
        case .payment(let paymentsHistoryItem):
            let paymentsSettings = PaymentsSettingsViewController(mode: .inAppSettings)
            let paymentsDetail = PaymentsDetailViewController(paymentItem: paymentsHistoryItem)
            viewControllers += [ paymentsSettings, paymentsDetail ]
        case .paymentsTransferIn:
            let paymentsSettings = PaymentsSettingsViewController(mode: .inAppSettings)
            let paymentsTransferIn = PaymentsTransferInViewController()
            viewControllers += [ paymentsSettings, paymentsTransferIn ]
        case .appearance:
            let appearance = AppearanceSettingsTableViewController()
            viewControllers += [ appearance ]
        case .avatarBuilder:
            let profile = ProfileSettingsViewController()
            viewControllers += [ profile ]
            completion = { profile.presentAvatarSettingsView() }
        case .subscriptions:
            let subscriptions = SubscriptionViewController()
            viewControllers += [ subscriptions ]
        case .boost:
            let boost = BoostViewController()
            viewControllers += [ boost ]
        }
        navigationController.setViewControllers(viewControllers, animated: false)
        presentFormSheet(navigationController, animated: true, completion: completion)
    }
}

extension HomeViewController: BadgeExpirationSheetDelegate {
    func badgeExpirationSheetActionButtonTapped(_ badgeExpirationSheet: BadgeExpirationSheet) {
        SubscriptionManager.clearMostRecentlyExpiredBadgeIDWithSneakyTransaction()
        if BoostBadgeIds.contains(badgeExpirationSheet.badgeID), SubscriptionManager.hasCurrentSubscriptionWithSneakyTransaction() {
            showAppSettings(mode: .boost)
        } else {
            showAppSettings(mode: .subscriptions)
        }
    }

    func badgeExpirationSheetNotNowButtonTapped(_ badgeExpirationSheet: BadgeExpirationSheet) { }
}
