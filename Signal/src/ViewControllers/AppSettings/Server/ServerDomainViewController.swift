//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import BonMot
import UIKit

protocol ServerDomainViewControllerDelegate: AnyObject {
    func serverDomainViewDidComplete(serverDomain: String?)
}

@objc
class ServerDomainViewController: OWSTableViewController2 {
    private let serverDomainTextField = OWSTextField()
    private let originalServerDomain: String?

    private weak var serverDomainDelegate: ServerDomainViewControllerDelegate?
    
    private static let minimumUsernameLength = 3
    private static let maximumUsernameLength: Int = 26

    private enum ValidationState {
        case valid
        case tooShort
        case invalidCharacters
        case notMainDomain
    }
    private var validationState: ValidationState = .valid {
        didSet {
            let didChange = oldValue != validationState
            if didChange, isViewLoaded {
                updateTableContents()
            }
        }
    }

    required init(serverDomain: String?,
                  serverDomainDelegate: ServerDomainViewControllerDelegate) {
        self.originalServerDomain = serverDomain
        self.serverDomainDelegate = serverDomainDelegate
        
        super.init()

        self.serverDomainTextField.text = serverDomain

        self.shouldAvoidKeyboard = true
    }

    // MARK: -

    public override func loadView() {
        view = UIView()
        createViews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateNavigation()
        updateTableContents()
    }

    private var normalizedServerDomain: String? {
        let normalizedDomain = serverDomainTextField.text?.stripped.lowercased()
        if normalizedDomain?.isEmpty == true { return nil }
        return normalizedDomain
    }

    private var hasUnsavedChanges: Bool {
        normalizedServerDomain != originalServerDomain
    }
    // Don't allow interactive dismiss when there are unsaved changes.
    override var isModalInPresentation: Bool {
        get { hasUnsavedChanges }
        set {}
    }

    private func updateNavigation() {
        title = NSLocalizedString("SERVERDOMAIN_TITLE", comment: "The title for the server domain view.")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didTapCancel),
            accessibilityIdentifier: "cancel_button"
        )

        if hasUnsavedChanges {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: CommonStrings.setButton,
                style: .done,
                target: self,
                action: #selector(didTapDone),
                accessibilityIdentifier: "set_button"
            )
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateNavigation()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateNavigation()

        serverDomainTextField.becomeFirstResponder()
    }

    private func createViews() {
        serverDomainTextField.returnKeyType = .done
        serverDomainTextField.autocorrectionType = .no
        serverDomainTextField.spellCheckingType = .no
        serverDomainTextField.placeholder = NSLocalizedString(
            "USERNAME_PLACEHOLDER",
            comment: "The placeholder for the username text entry in the username view."
        )
        serverDomainTextField.delegate = self
        serverDomainTextField.accessibilityIdentifier = "serverdomain_textfield"
        serverDomainTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    private func updateTableContents() {
        let contents = OWSTableContents()

        let section = OWSTableSection()

        var footerComponents = [Composable]()

        if let errorText = errorText {
            footerComponents.append(errorText.styled(with: .color(.ows_accentRed)))
            footerComponents.append("\n\n")
        }

        footerComponents.append(NSLocalizedString(
            "SERVERDOMAIN_ATTENTION",
            comment: "attent to need reboot app."
        ).styled(with:.color(.ows_accentRed)))
        footerComponents.append("\n\n")

        footerComponents.append(NSLocalizedString(
            "SERVER_VIEW_DESCRIPTION",
            comment: "An explanation of how server domain work on the domain view."
        ))
        
        section.footerAttributedTitle = NSAttributedString.composed(of: footerComponents).styled(
            with: .font(.ows_dynamicTypeCaption1Clamped),
            .color(Theme.secondaryTextAndIconColor)
        )

        section.add(.init(customCellBlock: { [weak self] in
            guard let self = self else { return UITableViewCell() }
            return self.nameCell(textField: self.serverDomainTextField)
        },
            actionBlock: { [weak self] in
                self?.serverDomainTextField.becomeFirstResponder()
            }
        ))
        contents.addSection(section)

        let wasFirstResponder = serverDomainTextField.isFirstResponder

        self.contents = contents

        if wasFirstResponder {
            serverDomainTextField.becomeFirstResponder()
        }
    }

    override func themeDidChange() {
        super.themeDidChange()
        updateTableContents()
    }

    private var errorText: String? {
        switch validationState {
        case .valid:
            return nil
        case .tooShort:
            return NSLocalizedString(
                "DOMAIN_TOO_SHORT_ERROR",
                comment: "An error indicating that the supplied domain is too short."
            )
        case .invalidCharacters:
            return NSLocalizedString(
                "DOMAIN_INVALID_CHARACTERS_ERROR",
                comment: "An error indicating that the supplied domain contains disallowed characters."
            )
        case .notMainDomain:
            let unavailableErrorFormat = NSLocalizedString(
                "DOMAIN_ERROR_FORMAT",
                comment: "An error indicating that the supplied domain is not main domain. Embeds {{requested username}}."
            )

            return String(format: unavailableErrorFormat, normalizedServerDomain ?? "")
        }
    }

    private func nameCell(textField: UITextField) -> UITableViewCell {
        let cell = OWSTableItem.newCell()

        cell.selectionStyle = .none

        textField.font = .ows_dynamicTypeBodyClamped
        textField.textColor = Theme.primaryTextColor

        cell.addSubview(textField)
        textField.autoPinEdgesToSuperviewMargins()

        return cell
    }

    @objc
    func didTapCancel() {
        guard hasUnsavedChanges else { return usernameSavedOrCanceled() }

        OWSActionSheets.showPendingChangesActionSheet(discardAction: { [weak self] in
            self?.usernameSavedOrCanceled()
        })
    }

    @objc
    func didTapDone() {
        // If we're trying to save, but we have nothing to save, just dismiss immediately.
        guard hasUnsavedChanges else { return usernameSavedOrCanceled() }

        guard serverDomainIsValid() else { return }

        self.preferences.setServerDomain(normalizedServerDomain)
        TSConstants.mainServerDomain = normalizedServerDomain!
        
        //serverDomainDelegate?.serverDomainViewDidComplete(serverDomain: normalizedServerDomain)
        //dismiss(animated: true)
        
        exit(0)
    }

    func serverDomainIsValid() -> Bool {
        // We allow empty usernames, as this is how you delete your username
        guard let normalizedServerDomain = normalizedServerDomain,(normalizedServerDomain as String).split(separator: ".").count == 2 else {
            validationState = .notMainDomain
            return false
        }

        guard normalizedServerDomain.count >= ServerDomainViewController.minimumUsernameLength else {
            validationState = .tooShort
            return false
        }

        // Usernames only allow a-z, 0-9, and underscore
        let validUsernameRegex = try! NSRegularExpression(pattern: "^[a-z0-9-.]+$", options: [])
        guard validUsernameRegex.hasMatch(input: normalizedServerDomain) else {
            validationState = .invalidCharacters
            return false
        }

        return true
    }

    func usernameSavedOrCanceled() {
        serverDomainTextField.resignFirstResponder()

        dismiss(animated: true)
    }
}

// MARK: -

extension ServerDomainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapDone()
        return false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        TextFieldHelper.textField(
            textField,
            shouldChangeCharactersInRange: range,
            replacementString: string,
            maxByteCount: ServerDomainViewController.maximumUsernameLength
        )
    }

    @objc func textFieldDidChange() {
        validationState = .valid
        updateNavigation()
    }
}
