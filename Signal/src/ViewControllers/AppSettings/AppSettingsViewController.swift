//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalUI
import UIKit

@objc
class AppSettingsViewController: OWSTableViewController2 {

    @objc
    class func inModalNavigationController() -> OWSNavigationController {
        OWSNavigationController(rootViewController: AppSettingsViewController())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("SETTINGS_NAV_BAR_TITLE", comment: "Title for settings activity")
        navigationItem.leftBarButtonItem = .init(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))

        defaultSeparatorInsetLeading = Self.cellHInnerMargin + 24 + OWSTableItem.iconSpacing

        updateTableContents()

        if let localAddress = tsAccountManager.localAddress {
            bulkProfileFetch.fetchProfile(address: localAddress)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localProfileDidChange),
            name: .localProfileDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionStateDidChange),
            name: SubscriptionManager.SubscriptionJobQueueDidFinishJobNotification,
            object: nil
        )
    }

    @objc
    func didTapDone() {
        dismiss(animated: true)
    }

    @objc
    func localProfileDidChange() {
        AssertIsOnMainThread()
        updateTableContents()
    }

    @objc
    func subscriptionStateDidChange() {
        AssertIsOnMainThread()

        updateTableContents()
    }

    override func themeDidChange() {
        super.themeDidChange()
        updateTableContents()
    }

    private lazy var hasCurrentSubscription: Bool = {
        return SubscriptionManager.hasCurrentSubscriptionWithSneakyTransaction()
    }()

    private lazy var hasExpiredSubscription: Bool = {
        return SubscriptionManager.mostRecentlyExpiredBadgeIDWithSneakyTransaction() != nil
    }()

    func updateTableContents() {
        let contents = OWSTableContents()

        let profileSection = OWSTableSection()
        profileSection.add(.init(customCellBlock: { [weak self] in
            guard let self = self else { return UITableViewCell() }
            return self.profileCell()
        },
            actionBlock: { [weak self] in
                let vc = ProfileSettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        contents.addSection(profileSection)

        let section1 = OWSTableSection()
        section1.add(.disclosureItem(
            icon: .settingsAccount,
            name: NSLocalizedString("SETTINGS_ACCOUNT", comment: "Title for the 'account' link in settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "account"),
            actionBlock: { [weak self] in
                let vc = AccountSettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section1.add(.disclosureItem(
            icon: .settingsPrivacy,
            name: NSLocalizedString("SETTINGS_UNLOCK_PASSWORD", comment: "Title for the 'unlock password' link in settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "unlock-password"),
            actionBlock: { [weak self] in
                let unlockPwd = UserDefaults.standard.string(forKey: kUnlockPassword)
                let vc = UnlockPasswordSetupViewController(mode: unlockPwd == nil ? .creating : .changing) { [weak self] pinSetupVC, _ in
                    self?.navigationController?.popToViewController(self!, animated: true)
                }
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section1.add(.disclosureItem(
            icon: .settingsPrivacy,
            name: NSLocalizedString("SETTINGS_DESTORY_PASSWORD", comment: "Title for the 'destory password' link in settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "destory-password"),
            actionBlock: { [weak self] in
                let destoryPwd = UserDefaults.standard.string(forKey: kDestoryPassword)
                let vc = DestoryPasswordSetupViewController(mode: destoryPwd == nil ? .creating : .changing) { [weak self] pinSetupVC, _ in
                    self?.navigationController?.popToViewController(self!, animated: true)
                }
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        
        section1.add(.disclosureItem(
            //icon: .settingsAdvanced,
            icon: .settingsMention,
            name: "Morse Server",
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "MorseServer"),
            actionBlock: { [weak self] in
                let vc = ServerSettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        
//        section1.add(.disclosureItem(
//            icon: .settingsLinkedDevices,
//            name: NSLocalizedString("LINKED_DEVICES_TITLE", comment: "Menu item and navbar title for the device manager"),
//            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "linked-devices"),
//            actionBlock: { [weak self] in
//                let vc = LinkedDevicesTableViewController()
//                self?.navigationController?.pushViewController(vc, animated: true)
//            }
//        ))
//        if payments.shouldShowPaymentsUI {
//            section1.add(.init(
//                customCellBlock: {
//                    let cell = OWSTableItem.newCell()
//                    cell.preservesSuperviewLayoutMargins = true
//                    cell.contentView.preservesSuperviewLayoutMargins = true
//
//                    var subviews = [UIView]()
//
//                    let iconView = OWSTableItem.imageView(forIcon: .settingsPayments,
//                                                          tintColor: nil,
//                                                          iconSize: OWSTableItem.iconSize)
//                    iconView.setCompressionResistanceHorizontalHigh()
//                    subviews.append(iconView)
//                    subviews.append(UIView.spacer(withWidth: OWSTableItem.iconSpacing))
//
//                    let nameLabel = UILabel()
//                    nameLabel.text = NSLocalizedString("SETTINGS_PAYMENTS_TITLE",
//                                                       comment: "Label for the 'payments' section of the app settings.")
//                    nameLabel.textColor = Theme.primaryTextColor
//                    nameLabel.font = OWSTableItem.primaryLabelFont
//                    nameLabel.adjustsFontForContentSizeCategory = true
//                    nameLabel.numberOfLines = 0
//                    nameLabel.lineBreakMode = .byWordWrapping
//                    nameLabel.setContentHuggingLow()
//                    nameLabel.setCompressionResistanceHigh()
//                    subviews.append(nameLabel)
//
//                    let betaIcon = UIImage(named: Theme.isDarkThemeEnabled ? "beta-dark-24" : "beta-light-24")
//                    let betaIconView = UIImageView(image: betaIcon)
//                    betaIconView.setCompressionResistanceHorizontalHigh()
//                    subviews.append(UIView.spacer(withWidth: 8))
//                    subviews.append(betaIconView)
//
//                    subviews.append(UIView.hStretchingSpacer())
//
//                    let unreadPaymentsCount = Self.databaseStorage.read { transaction in
//                        PaymentFinder.unreadCount(transaction: transaction)
//                    }
//                    if unreadPaymentsCount > 0 {
//                        let unreadLabel = UILabel()
//                        unreadLabel.text = OWSFormat.formatUInt(min(9, unreadPaymentsCount))
//                        unreadLabel.font = .ows_dynamicTypeBody2Clamped
//                        unreadLabel.textColor = .ows_white
//
//                        let unreadBadge = OWSLayerView.circleView()
//                        unreadBadge.backgroundColor = .ows_accentBlue
//                        unreadBadge.addSubview(unreadLabel)
//                        unreadLabel.autoCenterInSuperview()
//                        unreadLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 3)
//                        unreadLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 3)
//                        unreadBadge.autoPinToSquareAspectRatio()
//                        unreadBadge.setContentHuggingHorizontalHigh()
//                        unreadBadge.setCompressionResistanceHorizontalHigh()
//                        subviews.append(unreadBadge)
//                    }
//
//                    let contentRow = UIStackView(arrangedSubviews: subviews)
//                    contentRow.alignment = .center
//                    cell.contentView.addSubview(contentRow)
//
//                    contentRow.setContentHuggingHigh()
//                    contentRow.autoPinEdgesToSuperviewMargins()
//                    contentRow.autoSetDimension(.height, toSize: OWSTableItem.iconSize, relation: .greaterThanOrEqual)
//
//                    cell.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "payments")
//                    cell.accessoryType = .disclosureIndicator
//
//                    return cell
//                },
//                actionBlock: { [weak self] in
//                    let vc = PaymentsSettingsViewController(mode: .inAppSettings)
//                    self?.navigationController?.pushViewController(vc, animated: true)
//                }
//            ))
//        }
        contents.addSection(section1)

        let section2 = OWSTableSection()
        section2.add(.disclosureItem(
            icon: .settingsAppearance,
            name: NSLocalizedString("SETTINGS_APPEARANCE_TITLE", comment: "The title for the appearance settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "appearance"),
            actionBlock: { [weak self] in
                let vc = AppearanceSettingsTableViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section2.add(.disclosureItem(
            icon: .settingsChats,
            name: NSLocalizedString("SETTINGS_CHATS", comment: "Title for the 'chats' link in settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "chats"),
            actionBlock: { [weak self] in
                let vc = ChatsSettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section2.add(.disclosureItem(
            icon: .settingsNotifications,
            name: NSLocalizedString("SETTINGS_NOTIFICATIONS", comment: "The title for the notification settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "notifications"),
            actionBlock: { [weak self] in
                let vc = NotificationSettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section2.add(.disclosureItem(
            icon: .settingsPrivacy,
            name: NSLocalizedString("SETTINGS_PRIVACY_TITLE", comment: "The title for the privacy settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "privacy"),
            actionBlock: { [weak self] in
                let vc = PrivacySettingsViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        section2.add(.disclosureItem(
            icon: .settingsDataUsage,
            name: NSLocalizedString("SETTINGS_DATA", comment: "Label for the 'data' section of the app settings."),
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "data-usage"),
            actionBlock: { [weak self] in
                let vc = DataSettingsTableViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        contents.addSection(section2)

        let section3 = OWSTableSection()
        section3.add(.disclosureItem(
            icon: .settingsHelp,
            name: CommonStrings.help,
            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "help"),
            actionBlock: { [weak self] in
                let vc = HelpViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        ))
        contents.addSection(section3)

//        let section4 = OWSTableSection()
//        section4.add(.item(
//            icon: .settingsInvite,
//            name: NSLocalizedString("SETTINGS_INVITE_TITLE", comment: "Settings table view cell label"),
//            accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "invite"),
//            actionBlock: { [weak self] in
//                self?.showInviteFlow()
//            }
//        ))
//        if RemoteConfig.donorBadgeAcquisition {
//            if DonationUtilities.isApplePayAvailable {
//                section4.add(.init(customCellBlock: { [weak self] in
//                    guard let self = self else { return UITableViewCell() }
//                    let cell = OWSTableItem.buildCellWithAccessoryLabel(
//                        icon: .settingsDonate,
//                    itemName: self.hasCurrentSubscription ? NSLocalizedString("SETTINGS_CURRENT_SUBSCRIPTION", comment: "Title for the 'Subscription' link in settings.") : NSLocalizedString("SETTINGS_SUBSCRIPTION", comment: "Title for the 'become a sustainer' link in settings."),
//                        accessoryType: .disclosureIndicator,
//                    accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "sustainer"))
//
//                    if self.hasExpiredSubscription {
//                        let imageView = UIImageView(image: UIImage(named: "info-solid-24")?.withRenderingMode(.alwaysTemplate))
//                        imageView.tintColor = Theme.accentBlueColor
//                        cell.contentView.addSubview(imageView)
//
//                        imageView.autoSetDimensions(to: CGSize(square: 24))
//                        imageView.autoVCenterInSuperview()
//                        imageView.autoPinEdge(.trailing, to: .trailing, of: cell.contentView, withOffset: -8)
//                    }
//
//                    return cell
//                }, actionBlock: { [weak self] in
//                    let vc = SubscriptionViewController()
//                    self?.navigationController?.pushViewController(vc, animated: true)
//                }))
//
//                section4.add(.disclosureItem(
//                    icon: .settingsBoost,
//                    name: NSLocalizedString("SETTINGS_SIGNAL_BOOST", comment: "Title for the 'signal boost' link in settings."),
//                    accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "signal boost"),
//                    actionBlock: { [weak self] in
//                        let vc = BoostViewController()
//                        self?.navigationController?.pushViewController(vc, animated: true)
//                    }
//                ))
//            } else {
//                section4.add(.item(icon: .settingsDonate,
//                                   tintColor: Theme.primaryIconColor,
//                                   name: NSLocalizedString("SETTINGS_DONATE", comment: "Title for the 'donate to signal' link in settings."),
//                                   maxNameLines: 0,
//                                   textColor: Theme.primaryTextColor,
//                                   accessoryText: nil,
//                                   accessoryType: .none,
//                                   accessoryImage: #imageLiteral(resourceName: "open-20").withRenderingMode(.alwaysTemplate),
//                                   accessoryView: nil,
//                                   accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "donate"),
//                                   actionBlock: { () in
//                    UIApplication.shared.open(URL(string: "https://devplusone.com/donate")!, options: [:], completionHandler: nil)
//                }))
//            }
//
//        } else {
//            section4.add(.disclosureItem(
//                icon: .settingsDonate,
//                name: NSLocalizedString("SETTINGS_DONATE", comment: "Title for the 'donate to signal' link in settings."),
//                accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "donate"),
//                actionBlock: { [weak self] in
//                    let vc = DonationViewController()
//                    self?.navigationController?.pushViewController(vc, animated: true)
//                }
//            ))
//        }

        //contents.addSection(section4)

//        if DebugFlags.internalSettings {
//            let internalSection = OWSTableSection()
//            internalSection.add(.disclosureItem(
//                icon: .settingsAdvanced,
//                name: "Internal",
//                accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "internal"),
//                actionBlock: { [weak self] in
//                    let vc = InternalSettingsViewController()
//                    self?.navigationController?.pushViewController(vc, animated: true)
//                }
//            ))
//            contents.addSection(internalSection)
//        }

        self.contents = contents
    }

    private var inviteFlow: InviteFlow?
    private func showInviteFlow() {
        let inviteFlow = InviteFlow(presentingViewController: self)
        self.inviteFlow = inviteFlow
        inviteFlow.present(isAnimated: true, completion: nil)
    }

    private func profileCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.accessoryType = .disclosureIndicator

        let hStackView = UIStackView()
        hStackView.axis = .horizontal
        hStackView.spacing = 12

        cell.contentView.addSubview(hStackView)
        hStackView.autoPinEdgesToSuperviewMargins()

        let snapshot = profileManagerImpl.localProfileSnapshot(shouldIncludeAvatar: false)

        let avatarImageView = ConversationAvatarView(
            sizeClass: .sixtyFour,
            localUserDisplayMode: .asUser)

        if let localAddress = tsAccountManager.localAddress {
            avatarImageView.updateWithSneakyTransactionIfNecessary { config in
                config.dataSource = .address(localAddress)
            }
        }

        hStackView.addArrangedSubview(avatarImageView)

        let vStackView = UIStackView()
        vStackView.axis = .vertical
        vStackView.spacing = 0
        hStackView.addArrangedSubview(vStackView)

        let nameLabel = UILabel()
        vStackView.addArrangedSubview(nameLabel)
        nameLabel.font = UIFont.ows_dynamicTypeTitle2Clamped.ows_medium
        if let fullName = snapshot.fullName, !fullName.isEmpty {
            nameLabel.text = fullName
            nameLabel.textColor = Theme.primaryTextColor
        } else {
            nameLabel.text = NSLocalizedString(
                "APP_SETTINGS_EDIT_PROFILE_NAME_PROMPT",
                comment: "Text prompting user to edit their profile name."
            )
            nameLabel.textColor = Theme.accentBlueColor
        }

        func addSubtitleLabel(text: String?, isLast: Bool = false) {
            guard let text = text, !text.isEmpty else { return }

            let label = UILabel()
            label.font = .ows_dynamicTypeFootnoteClamped
            label.text = text
            label.textColor = Theme.secondaryTextAndIconColor

            let containerView = UIView()
            containerView.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: isLast ? 0 : 2, right: 0)
            containerView.addSubview(label)
            label.autoPinEdgesToSuperviewMargins()

            vStackView.addArrangedSubview(containerView)
        }

//        func createButton(title: String, action: Selector) -> UIButton {
//            //let buttonFont = UIFont.ows_semiboldFont(withSize: ScaleFromIPhone5To7Plus(18, 22))
////            let buttonWidth = ScaleFromIPhone5To7Plus(110, 140)
////            let buttonHeight = ScaleFromIPhone5To7Plus(35, 45)
//
//            let button = UIButton()
//            button.setImage(UIImage(systemName: "doc.on.clipboard"),
//                    for: .normal)
//            //button.setImage(UIImage(systemName: "search"), for: .normal)
//            button.setTitle(title, for: .normal)
//            button.setTitleColor(Theme.secondaryTextAndIconColor, for: .normal)
////            button.titleLabel!.font = buttonFont
//            button.addTarget(self, action: action, for: .touchUpInside)
////            button.autoSetDimension(.width, toSize: buttonWidth)
////            button.autoSetDimension(.height, toSize: buttonHeight)
//            return button
//        }
        
//        func addCopyButton() {
//            let copyButton = createButton(title: CommonStrings.copyButton,
//                                          action: #selector(copyPressed))
//
//            let copyContainerView = UIView()
//            copyContainerView.layoutMargins = UIEdgeInsets(top: 2, left: 0, bottom: 0 , right: 0)
//            copyContainerView.addSubview(copyButton)
//            copyButton.autoPinEdgesToSuperviewMargins()
//            vStackView.addArrangedSubview(copyContainerView)
//        }
        
        func addNumbers(phoneNumber:String){
            let hNumberStackView = UIStackView()
            hNumberStackView.axis = .horizontal
            hNumberStackView.spacing = 8
//            hNumberStackView.alignment = .leading
//            hNumberStackView.distribution = .fillProportionally
            hStackView.autoPinEdgesToSuperviewMargins()

//            let copyButton = createButton(title: CommonStrings.copyButton,
//                                          action: #selector(copyPressed))
//            copyButton.titleLabel!.font = .ows_dynamicTypeFootnoteClamped
//
//            let copyContainerView = UIView()
//            copyContainerView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0 , right: 0)
//            copyContainerView.addSubview(copyButton)
//            copyButton.autoPinEdgesToSuperviewMargins()
            
            //hNumberStackView.addArrangedSubview(copyButton)

            let text = UITextView()
            text.font = .ows_dynamicTypeFootnoteClamped
            text.text = phoneNumber
            text.textColor = Theme.secondaryTextAndIconColor
            text.isEditable = false
            text.isSelectable = true
            text.backgroundColor = UIColor.clear
            
            text.autoSetDimension(.height, toSize: 30)
            //text.autoSetDimension(.width, toSize: 120)
            hNumberStackView.addArrangedSubview(text)
            
//            let label = UILabel()
//            label.font = .ows_dynamicTypeFootnoteClamped
//            label.text = phoneNumber
//            label.textColor = Theme.secondaryTextAndIconColor

//            //label.autoSetDimension(.width, toSize: 100)
////            hNumberStackView.addArrangedSubview(label)
//
            
//            let button = UIButton()
//            button.setImage(UIImage(systemName: "doc.on.clipboard"),
//                    for: .normal)
//            button.autoSetDimension(.width, toSize: 30)

            //button.backgroundColor = UIColor.clear
//            button.layer.cornerRadius = 5
//            button.layer.borderWidth = 1
//            //button.layer.borderColor = UIColor(red: 74/255, green: 218/255, blue: 163/225, alpha: 1).cgColor
//            button.layer.borderColor = UIColor.black.cgColor
            
//            button.setTitle(CommonStrings.copyButton, for: .normal)
//            button.setTitleColor(Theme.secondaryTextAndIconColor, for: .normal)
//            button.titleLabel!.font = .ows_dynamicTypeFootnoteClamped
//            button.addTarget(self, action: #selector(copyPressed), for: .touchUpInside)
//            hNumberStackView.addArrangedSubview(button)

//            hNumberStackView.addArrangedSubview(UIView.spacer(withWidth: 30))
            
            vStackView.addArrangedSubview(hNumberStackView)
            //vStackView.addArrangedSubview(text)
        }
        
        addSubtitleLabel(text: OWSUserProfile.bioForDisplay(bio: snapshot.bio, bioEmoji: snapshot.bioEmoji))

        if let phoneNumber = tsAccountManager.localNumber {
            addNumbers(phoneNumber: phoneNumber)
//            addSubtitleLabel(
//                text: PhoneNumber.bestEffortFormatPartialUserSpecifiedText(toLookLikeAPhoneNumber: phoneNumber),
//                isLast: true
//            )
            //addCopyButton()
        } else {
            owsFailDebug("Missing local number")
        }

        let topSpacer = UIView.vStretchingSpacer()
        let bottomSpacer = UIView.vStretchingSpacer()
        vStackView.insertArrangedSubview(topSpacer, at: 0)
        vStackView.addArrangedSubview(bottomSpacer)
        topSpacer.autoMatch(.height, to: .height, of: bottomSpacer)

        return cell
    }
    
    @objc func copyPressed(sender: UIButton) {
        if let phoneNumber = tsAccountManager.localNumber {
            UIPasteboard.general.string = phoneNumber
            //self.view.makeToast("Your Number has copied!")
            self.view.makeToast(NSLocalizedString(
                "NUMBER_COPIED_TOAST",
                comment: "The Number has copied!"
            ),duration:3.0,position:ToastPosition.top)
//            self.view.makeToast(NSLocalizedString(
//                "NUMBER_COPIED_TOAST",
//                comment: "The Number has copied!"
//            ))
        }
    }
}
