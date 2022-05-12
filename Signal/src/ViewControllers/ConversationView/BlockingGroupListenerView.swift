//
//  BlockingGroupListenerView.swift
//  Morse
//
//  Copyright © 2022 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc
class BlockingGroupListenerView: UIStackView {

    private let thread: TSThread

    private weak var fromViewController: UIViewController?

    init(threadViewModel: ThreadViewModel, fromViewController: UIViewController) {
        let thread = threadViewModel.threadRecord
        self.thread = thread
        owsAssertDebug(thread as? TSGroupThread != nil)
        self.fromViewController = fromViewController

        super.init(frame: .zero)

        createDefaultContents()
    }

    private func createDefaultContents() {
        // We want the background to extend to the bottom of the screen
        // behind the safe area, so we add that inset to our bottom inset
        // instead of pinning this view to the safe area
        let safeAreaInset = safeAreaInsets.bottom

        autoresizingMask = .flexibleHeight

        axis = .vertical
        spacing = 11
        layoutMargins = UIEdgeInsets(top: 16, leading: 16, bottom: 20 + safeAreaInset, trailing: 16)
        isLayoutMarginsRelativeArrangement = true
        alignment = .fill

        let blurView = UIVisualEffectView(effect: Theme.barBlurEffect)
        addSubview(blurView)
        blurView.autoPinEdgesToSuperviewEdges()

        let format = NSLocalizedString("GROUPS_LISTENER_BLOCKING_SEND_OR_CALL_FORMAT",
                                       comment: "One user has been set as listener,can contact admins to change role. Embeds {{ a \"admins\" link. }}.")
        let adminsText = NSLocalizedString("GROUPS_ANNOUNCEMENT_ONLY_ADMINISTRATORS",
                                           comment: "Label for group administrators in the 'group listener' group UI.")
        let text = String(format: format, adminsText)
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.setAttributes([
            .foregroundColor: Theme.accentBlueColor
        ],
        forSubstring: adminsText)

        let label = UILabel()
        label.font = .ows_dynamicTypeSubheadlineClamped
        label.textColor = Theme.secondaryTextAndIconColor
        label.attributedText = attributedString
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapContactAdmins)))
        addArrangedSubview(label)

        let lineView = UIView()
        lineView.backgroundColor = Theme.hairlineColor
        addSubview(lineView)
        lineView.autoSetDimension(.height, toSize: 1)
        lineView.autoPinWidthToSuperview()
        lineView.autoPinEdge(toSuperviewEdge: .top)
    }

    private func groupAdmins() -> [SignalServiceAddress] {
        guard let groupThread = thread as? TSGroupThread,
              let groupModel = groupThread.groupModel as? TSGroupModelV2 else {
            owsFailDebug("Invalid group.")
            return []
        }
        owsAssertDebug(groupThread.isLocalUserFullMemberAndListener)
        return Array(groupModel.groupMembership.fullMemberAdministrators)

    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return .zero
    }

    // MARK: -

    @objc
    public func didTapContactAdmins() {
        guard let fromViewController = fromViewController else {
            owsFailDebug("Missing fromViewController.")
            return
        }

        let groupAdmins = self.groupAdmins()
        guard !groupAdmins.isEmpty else {
            owsFailDebug("No group admins.")
            return
        }

        let sheet = MessageUserSubsetSheet(addresses: groupAdmins)
        fromViewController.present(sheet, animated: true)
    }
}
