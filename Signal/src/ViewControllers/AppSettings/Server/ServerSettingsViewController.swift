//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalMessaging
import UIKit
import SignalUI

@objc
class ServerSettingsViewController: OWSTableViewController2 {

    private var hasUnsavedChanges = false {
        didSet { updateNavigationItem() }
    }


    private var serverDomain: String?
   
    override func viewDidLoad() {
        super.viewDidLoad()

        owsAssertDebug(navigationController != nil)

        title = NSLocalizedString("SERVER_VIEW_TITLE", comment: "Title for the morse server view.")

        serverDomain = self.preferences.getServerDomain()
       
        updateTableContents()
    }

    func updateTableContents() {
        let contents = OWSTableContents()

       

        let mainSection = OWSTableSection()
        mainSection.footerAttributedTitle = NSAttributedString.composed(of: [
            NSLocalizedString("SERVER_VIEW_DESCRIPTION",
                              comment: "Description of the server domain."),
            " ",
//            CommonStrings.learnMore.styled(
//                with: .link(URL(string: "https://support.devplusone.com/hc/articles/360007459591")!)
//            )
        ]).styled(
            with: .font(.ows_dynamicTypeCaption1Clamped),
            .color(Theme.secondaryTextAndIconColor)
        )
        
        if RemoteConfig.usernames {
            mainSection.add(.disclosureItem(
                icon: .settingsMention,
                name: serverDomain ?? TSConstants.mainServerDomain,
                accessibilityIdentifier: UIView.accessibilityIdentifier(in: self, name: "username"),
                actionBlock: { [weak self] in
                    guard let self = self else { return }
                    let vc = ServerDomainViewController(serverDomain: self.serverDomain,serverDomainDelegate: self)
                    self.presentFormSheet(OWSNavigationController(rootViewController: vc), animated: true)
                }
            ))
        }
        
        contents.addSection(mainSection)

        self.contents = contents
    }

    // MARK: - Event Handling

    override func themeDidChange() {
        super.themeDidChange()
        updateTableContents()
    }

    private func leaveViewCheckingForUnsavedChanges() {
        if !hasUnsavedChanges {
            // If user made no changes, return to conversation settings view.
            profileCompleted()
            return
        }

        OWSActionSheets.showPendingChangesActionSheet(discardAction: { [weak self] in
            self?.profileCompleted()
        })
    }

    private func updateNavigationItem() {
        if hasUnsavedChanges {
            // If we have a unsaved changes, right item should be a "save" button.
            let saveButton = UIBarButtonItem(
                barButtonSystemItem: .save,
                target: self,
                action: #selector(updateProfile),
                accessibilityIdentifier: "save_button"
            )
            navigationItem.rightBarButtonItem = saveButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc
    func updateProfile() {

        
    }

   

    private func profileCompleted() {
        AssertIsOnMainThread()
        Logger.verbose("")

        navigationController?.popViewController(animated: true)
    }
}

extension ServerSettingsViewController: ServerDomainViewControllerDelegate {
    func serverDomainViewDidComplete(serverDomain: String?) {
        self.serverDomain = serverDomain

        if self.serverDomain != nil && !(self.serverDomain?.elementsEqual(TSConstants.mainServerDomain))! {
            //print(TSConstants.mainServerDomain)
            TSConstants.mainServerDomain = self.serverDomain ?? TSConstants.mainServerDomain
            //print(TSConstants.mainServerDomain)
        }
        updateTableContents()
    }
}

extension ServerSettingsViewController: OWSNavigationView {

    @available(iOS 13, *)
    override public var isModalInPresentation: Bool {
        get { hasUnsavedChanges }
        set { /* noop superclass requirement */ }
    }

    public func shouldCancelNavigationBack() -> Bool {
        let result = hasUnsavedChanges
        if result {
            leaveViewCheckingForUnsavedChanges()
        }
        return result
    }
}


