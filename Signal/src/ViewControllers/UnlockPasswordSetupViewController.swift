//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import UIKit
import SafariServices

let kUnlockPassword = "kUnlockPassword"

@objc(UnlockPasswordSetupViewController)
public class UnlockPasswordSetupViewController: OWSViewController {

    lazy private var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = Theme.primaryTextColor
        label.font = UIFont.ows_dynamicTypeTitle2Clamped.ows_semibold
        label.textAlignment = .center
        label.text = titleText
        return label
    }()

    lazy private var explanationLabel: LinkingTextView = {
        let explanationLabel = LinkingTextView()
        let explanationText: String
        switch mode {
        case .creating:
            explanationText = NSLocalizedString("UNLOCK_PASSWORD_CREATION_EXPLANATION",
                                                comment: "The explanation in the 'unlock-password creation' view.")
        case .recreating, .changing:
            explanationText = NSLocalizedString("UNLOCK_PASSWORD_CREATION_EXPLANATION",
                                                comment: "The re-creation explanation in the 'unlock-password creation' view.")
        case .confirming:
            explanationText = NSLocalizedString("UNLOCK_PASSWORD_CREATION_CONFIRMATION_EXPLANATION",
                                                comment: "The explanation of confirmation in the 'unlock-password creation' view.")
        }

        // The font is too long to fit wih dynamic type. Design is looking into
        // how to design this page to fit dyanmic type. In the meantime, we have
        // to pin the font size.
        let explanationLabelFont = UIFont.systemFont(ofSize: 15)

        let attributedString = NSMutableAttributedString(
            string: explanationText,
            attributes: [
                .font: explanationLabelFont,
                .foregroundColor: Theme.secondaryTextAndIconColor
            ]
        )

        if !mode.isConfirming {
            explanationLabel.isUserInteractionEnabled = true
        }
        explanationLabel.attributedText = attributedString
        explanationLabel.textAlignment = .center
        explanationLabel.accessibilityIdentifier = "unlockPasswordCreation.explanationLabel"
        return explanationLabel
    }()

    private let topSpacer = UIView.vStretchingSpacer()
    private var proportionalSpacerConstraint: NSLayoutConstraint?

    private let pinTextField: UITextField = {
        let pinTextField = UITextField()
        pinTextField.textAlignment = .center
        pinTextField.textColor = Theme.primaryTextColor

        let font = UIFont.systemFont(ofSize: 17)
        pinTextField.font = font
        pinTextField.autoSetDimension(.height, toSize: font.lineHeight + 2 * 8.0)

        pinTextField.textContentType = .password
        pinTextField.isSecureTextEntry = true
        pinTextField.defaultTextAttributes.updateValue(5, forKey: .kern)
        pinTextField.keyboardAppearance = Theme.keyboardAppearance
        pinTextField.accessibilityIdentifier = "unlockPasswordCreation.pinTextField"
        return pinTextField
    }()

    private lazy var pinTypeToggle: OWSFlatButton = {
        let pinTypeToggle = OWSFlatButton()
        pinTypeToggle.setTitle(font: .ows_dynamicTypeSubheadlineClamped, titleColor: Theme.accentBlueColor)
        pinTypeToggle.setBackgroundColors(upColor: .clear)

        pinTypeToggle.enableMultilineLabel()
        pinTypeToggle.button.clipsToBounds = true
        pinTypeToggle.button.layer.cornerRadius = 8
        pinTypeToggle.contentEdgeInsets = UIEdgeInsets(hMargin: 4, vMargin: 8)

        pinTypeToggle.addTarget(target: self, selector: #selector(togglePinType))
        pinTypeToggle.accessibilityIdentifier = "unlockPasswordCreation.pinTypeToggle"
        return pinTypeToggle
    }()

    private let nextButton: OWSFlatButton = {
        let nextButton = OWSFlatButton()
        nextButton.setTitle(
            title: CommonStrings.nextButton,
            font: UIFont.ows_dynamicTypeBodyClamped.ows_semibold,
            titleColor: .white)
        nextButton.setBackgroundColors(upColor: .ows_accentBlue)

        nextButton.button.clipsToBounds = true
        nextButton.button.layer.cornerRadius = 14
        nextButton.contentEdgeInsets = UIEdgeInsets(hMargin: 4, vMargin: 14)

        nextButton.addTarget(target: self, selector: #selector(nextPressed))
        nextButton.accessibilityIdentifier = "unlockPasswordCreation.nextButton"
        return nextButton
    }()
    
    private lazy var clearButton: OWSFlatButton = {
        let text = NSLocalizedString("UNLOCK_PASSWORD_CANCEL", comment: "Label for the 'cancel unlock-password' button.")
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.count))
        
        let clearButton = OWSFlatButton()
        clearButton.setTitle(
            title: text,
            font: .ows_dynamicTypeSubheadlineClamped,
            titleColor: Theme.accentBlueColor
        )
        clearButton.setAttributedTitle(attributedString)
        clearButton.setBackgroundColors(upColor: .clear)

        clearButton.enableMultilineLabel()
        clearButton.button.clipsToBounds = true
        clearButton.button.layer.cornerRadius = 8
        clearButton.contentEdgeInsets = UIEdgeInsets(hMargin: 4, vMargin: 8)

        clearButton.addTarget(target: self, selector: #selector(clearHandler))
        clearButton.accessibilityIdentifier = "unlockPasswordCreation.clearButton"
        return clearButton
    }()

    private let validationWarningLabel: UILabel = {
        let validationWarningLabel = UILabel()
        validationWarningLabel.textColor = .ows_accentRed
        validationWarningLabel.textAlignment = .center
        validationWarningLabel.font = UIFont.ows_dynamicTypeFootnoteClamped
        validationWarningLabel.numberOfLines = 0
        validationWarningLabel.accessibilityIdentifier = "unlockPasswordCreation.validationWarningLabel"
        return validationWarningLabel
    }()

    private let recommendationLabel: UILabel = {
        let recommendationLabel = UILabel()
        recommendationLabel.textColor = Theme.secondaryTextAndIconColor
        recommendationLabel.textAlignment = .center
        recommendationLabel.font = UIFont.ows_dynamicTypeFootnoteClamped
        recommendationLabel.numberOfLines = 0
        recommendationLabel.accessibilityIdentifier = "unlockPasswordCreation.recommendationLabel"
        return recommendationLabel
    }()

    private let backButton: UIButton = {
        let topButtonImage = CurrentAppContext().isRTL ? #imageLiteral(resourceName: "NavBarBackRTL") : #imageLiteral(resourceName: "NavBarBack")
        let backButton = UIButton.withTemplateImage(topButtonImage, tintColor: Theme.secondaryTextAndIconColor)

        backButton.autoSetDimensions(to: CGSize(square: 40))
        backButton.addTarget(self, action: #selector(navigateBack), for: .touchUpInside)
        return backButton
    }()

    private lazy var pinStrokeNormal = pinTextField.addBottomStroke()
    private lazy var pinStrokeError = pinTextField.addBottomStroke(color: .ows_accentRed, strokeWidth: 2)

    enum Mode {
        case creating
        case recreating
        case changing
        case confirming(pinToMatch: String)

        var isChanging: Bool {
            guard case .changing = self else { return false }
            return true
        }

        var isConfirming: Bool {
            guard case .confirming = self else { return false }
            return true
        }
    }
    private let mode: Mode

    private let initialMode: Mode

    enum ValidationState {
        case valid
        case tooShort
        case mismatch
        case weak
        case same

        var isInvalid: Bool {
            return self != .valid
        }
    }
    private var validationState: ValidationState = .valid {
        didSet {
            updateValidationWarnings()
        }
    }

    private var pinType: KeyBackupService.PinType {
        didSet {
            updatePinType()
        }
    }

    // Called once pin setup has finished. Error will be nil upon success
    private let completionHandler: (UnlockPasswordSetupViewController, Error?) -> Void

    private let enableRegistrationLock: Bool

    init(
        mode: Mode,
        initialMode: Mode? = nil,
        pinType: KeyBackupService.PinType = .numeric,
        enableRegistrationLock: Bool = OWS2FAManager.shared.isRegistrationLockEnabled,
        completionHandler: @escaping (UnlockPasswordSetupViewController, Error?) -> Void
    ) {
        assert(TSAccountManager.shared.isRegisteredPrimaryDevice)
        self.mode = mode
        self.initialMode = initialMode ?? mode
        self.pinType = pinType
        self.enableRegistrationLock = enableRegistrationLock
        self.completionHandler = completionHandler
        super.init()

        if case .confirming = self.initialMode {
            owsFailDebug("unlock-password setup flow should never start in the confirming state")
        }
    }

    @objc
    class func creatingRegistrationLock(completionHandler: @escaping (UnlockPasswordSetupViewController, Error?) -> Void) -> UnlockPasswordSetupViewController {
        return .init(mode: .creating, enableRegistrationLock: true, completionHandler: completionHandler)
    }

    @objc
    class func creating(completionHandler: @escaping (UnlockPasswordSetupViewController, Error?) -> Void) -> UnlockPasswordSetupViewController {
        return .init(mode: .creating, completionHandler: completionHandler)
    }

    @objc
    class func changing(completionHandler: @escaping (UnlockPasswordSetupViewController, Error?) -> Void) -> UnlockPasswordSetupViewController {
        return .init(mode: .changing, completionHandler: completionHandler)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldIgnoreKeyboardChanges = false

        if let navigationBar = navigationController?.navigationBar as? OWSNavigationBar {
            navigationBar.navbarBackgroundColorOverride = backgroundColor
            navigationBar.switchToStyle(.solid, animated: true)
        }

        // Hide the nav bar when not changing.
        navigationController?.setNavigationBarHidden(!initialMode.isChanging, animated: false)
        title = titleText

        let topMargin: CGFloat = navigationController?.isNavigationBarHidden == false ? 0 : 32
        let hMargin: CGFloat = UIDevice.current.isIPhone5OrShorter ? 13 : 26
        view.layoutMargins = UIEdgeInsets(top: topMargin, leading: hMargin, bottom: 0, trailing: hMargin)

        if navigationController?.isNavigationBarHidden == false {
            [backButton, titleLabel].forEach { $0.isHidden = true }
        } else {
            // If we're in creating mode AND we're the rootViewController, don't allow going back
            if case .creating = mode, navigationController?.viewControllers.first == self {
                backButton.isHidden = true
            } else {
                backButton.isHidden = false
            }
            titleLabel.isHidden = false
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // TODO: Maybe do this in will appear, to avoid the keyboard sliding in when the view is pushed?
        pinTextField.becomeFirstResponder()
    }

    private var backgroundColor: UIColor {
        presentingViewController == nil ? Theme.backgroundColor : Theme.tableView2PresentedBackgroundColor
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        shouldIgnoreKeyboardChanges = true

        if let navigationBar = navigationController?.navigationBar as? OWSNavigationBar {
            navigationBar.switchToStyle(.default, animated: true)
        }

        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.isDarkThemeEnabled ? .lightContent : .default
    }

    override public func loadView() {
        owsAssertDebug(navigationController != nil, "This view should always be presented in a nav controller")
        view = UIView()
        view.backgroundColor = backgroundColor

        view.addSubview(backButton)
        backButton.autoPinEdge(toSuperviewSafeArea: .top)
        backButton.autoPinEdge(toSuperviewSafeArea: .leading)

        let titleSpacer = SpacerView(preferredHeight: 12)
        let pinFieldSpacer = SpacerView(preferredHeight: 11)
        let bottomSpacer = SpacerView(preferredHeight: 10)
        let pinToggleSpacer = SpacerView(preferredHeight: 24)
        let clearSpacer = SpacerView(preferredHeight: 8)
        let buttonSpacer = SpacerView(preferredHeight: 32)

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            titleSpacer,
            explanationLabel,
            topSpacer,
            pinTextField,
            pinFieldSpacer,
            validationWarningLabel,
            recommendationLabel,
            bottomSpacer,
            pinTypeToggle,
            pinToggleSpacer,
            OnboardingBaseViewController.horizontallyWrap(primaryButton: nextButton)
        ])
        if (initialMode.isChanging) {
            stackView.addArrangedSubviews([clearSpacer, clearButton])
        }
        stackView.addArrangedSubview(buttonSpacer)
        stackView.axis = .vertical
        stackView.alignment = .center
        view.addSubview(stackView)

        stackView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        autoPinView(toBottomOfViewControllerOrKeyboard: stackView, avoidNotch: true)

        [pinTextField, validationWarningLabel, recommendationLabel].forEach {
            $0.autoSetDimension(.width, toSize: 227)
        }

        [titleLabel, explanationLabel, pinTextField, validationWarningLabel, recommendationLabel, pinTypeToggle, nextButton, clearButton]
            .forEach { $0.setCompressionResistanceVerticalHigh() }

        // Reduce priority of compression resistance for the spacer views
        // The array index serves as an ambiguous layout tiebreaker
        [titleSpacer, pinFieldSpacer, bottomSpacer, pinToggleSpacer, buttonSpacer].enumerated().forEach {
            $0.element.setContentCompressionResistancePriority(.defaultHigh - .init($0.offset), for: .vertical)
        }

        // Bottom spacer is the stack view item that grows when there's extra space
        // Ensure whitespace is balanced, so inputs are vertically centered.
        bottomSpacer.setContentHuggingPriority(.init(100), for: .vertical)
        proportionalSpacerConstraint = topSpacer.autoMatch(.height, to: .height, of: bottomSpacer)
        updateValidationWarnings()
        updatePinType()

        // Pin text field
        pinTextField.delegate = self
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Don't allow interactive dismissal.
        if #available(iOS 13, *) {
            isModalInPresentation = true
        }
    }

    var titleText: String {
        if mode.isConfirming {
            return NSLocalizedString("UNLOCK_PASSWORD_CREATION_CONFIRM_TITLE", comment: "Title of the 'unlock-password creation' confirmation view.")
        } else if case .recreating = initialMode {
            return NSLocalizedString("UNLOCK_PASSWORD_CREATION_RECREATION_TITLE", comment: "Title of the 'unlock-password creation' recreation view.")
        } else if initialMode.isChanging {
            return NSLocalizedString("UNLOCK_PASSWORD_CREATION_CHANGING_TITLE", comment: "Title of the 'unlock-password creation' recreation view.")
        } else {
            return NSLocalizedString("UNLOCK_PASSWORD_CREATION_TITLE", comment: "Title of the 'unlock-password creation' view.")
        }
    }

    // MARK: - Events

    @objc func navigateBack() {
        Logger.info("")

        if case .recreating = mode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc func nextPressed() {
        Logger.info("")

        tryToContinue()
    }
    
    @objc func clearHandler() {
        UserDefaults.standard.removeObject(forKey: kUnlockPassword)
        self.completionHandler(self, nil)
    }

    private func tryToContinue() {
        Logger.info("")

        guard let pin = pinTextField.text?.ows_stripped(), pin.count >= kMin2FAv2PinLength else {
            validationState = .tooShort
            return
        }

        if case .confirming(let pinToMatch) = mode, pinToMatch != pin {
            validationState = .mismatch
            return
        }

        if isWeakPin(pin) {
            validationState = .weak
            return
        }
        
        let destoryPwd = UserDefaults.standard.string(forKey: kDestoryPassword)
        if destoryPwd != nil && pin == destoryPwd {
            validationState = .same
            return
        }

        switch mode {
        case .creating, .changing, .recreating:
            let confirmingVC = UnlockPasswordSetupViewController(
                mode: .confirming(pinToMatch: pin),
                initialMode: initialMode,
                pinType: pinType,
                enableRegistrationLock: enableRegistrationLock,
                completionHandler: completionHandler
            )
            navigationController?.pushViewController(confirmingVC, animated: true)
        case .confirming:
            enable2FAAndContinue(withPin: pin)
        }
    }

    private func isWeakPin(_ pin: String) -> Bool {
        let normalizedPin = KeyBackupService.normalizePin(pin)

        // We only check numeric pins for weakness
        guard normalizedPin.digitsOnly() == normalizedPin else { return false }

        var allTheSame = true
        var forwardSequential = true
        var reverseSequential = true

        var previousWholeNumberValue: Int?
        for character in normalizedPin {
            guard let current = character.wholeNumberValue else {
                owsFailDebug("numeric unlock-password unexpectedly contatined non-numeric characters")
                break
            }

            defer { previousWholeNumberValue = current }
            guard let previous = previousWholeNumberValue else { continue }

            if previous != current { allTheSame = false }
            if previous + 1 != current { forwardSequential = false }
            if previous - 1 != current { reverseSequential = false }

            if !allTheSame && !forwardSequential && !reverseSequential { break }
        }

        return allTheSame || forwardSequential || reverseSequential
    }

    private func updateValidationWarnings() {
        AssertIsOnMainThread()

        pinStrokeNormal.isHidden = validationState.isInvalid
        pinStrokeError.isHidden = !validationState.isInvalid
        validationWarningLabel.isHidden = !validationState.isInvalid
        recommendationLabel.isHidden = validationState.isInvalid

        switch validationState {
        case .tooShort:
            switch pinType {
            case .numeric:
                validationWarningLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_NUMERIC_HINT",
                                                                comment: "Label indicating the user must use at least 4 digits")
            case .alphanumeric:
                validationWarningLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_ALPHANUMERIC_HINT",
                                                                comment: "Label indicating the user must use at least 4 characters")
            }
        case .mismatch:
            validationWarningLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_MISMATCH_ERROR",
                                                            comment: "Label indicating that the attempted UNLOCK-PASSWORD does not match the first UNLOCK-PASSWORD")
        case .weak:
            validationWarningLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_WEAK_ERROR",
                                                            comment: "Label indicating that the attempted UNLOCK-PASSWORD is too weak")
        case .same:
            validationWarningLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_DESTORY_PASSWORD_SAME_ERROR",
                                                            comment: "Label indicating that the attempted UNLOCK-PASSWORD is the same as DESTORY-PASSWORD")
        default:
            break
        }
    }

    private func updatePinType() {
        AssertIsOnMainThread()

        pinTextField.text = nil
        validationState = .valid

        let recommendationLabelText: String

        switch pinType {
        case .numeric:
            pinTypeToggle.setTitle(title: NSLocalizedString("UNLOCK_PASSWORD_CREATION_CREATE_ALPHANUMERIC",
                                                            comment: "Button asking if the user would like to create an alphanumeric UNLOCK-PASSWORD"))
            pinTextField.keyboardType = .asciiCapableNumberPad
            recommendationLabelText = NSLocalizedString("UNLOCK_PASSWORD_CREATION_NUMERIC_HINT",
                                                         comment: "Label indicating the user must use at least 4 digits")
        case .alphanumeric:
            pinTypeToggle.setTitle(title: NSLocalizedString("UNLOCK_PASSWORD_CREATION_CREATE_NUMERIC",
                                                            comment: "Button asking if the user would like to create an numeric UNLOCK-PASSWORD"))
            pinTextField.keyboardType = .default
            recommendationLabelText = NSLocalizedString("UNLOCK_PASSWORD_CREATION_ALPHANUMERIC_HINT",
                                                        comment: "Label indicating the user must use at least 4 characters")
        }

        pinTextField.reloadInputViews()

        if mode.isConfirming {
            clearButton.isHidden = true
            pinTypeToggle.isHidden = true
            recommendationLabel.text = NSLocalizedString("UNLOCK_PASSWORD_CREATION_UNLOCK_PASSWORD_CONFIRMATION_HINT",
                                                         comment: "Label indication the user must confirm their UNLOCK-PASSWORD.")
        } else {
            clearButton.isHidden = !mode.isChanging
            pinTypeToggle.isHidden = false
            recommendationLabel.text = recommendationLabelText
        }
    }

    @objc func togglePinType() {
        switch pinType {
        case .numeric:
            pinType = .alphanumeric
        case .alphanumeric:
            pinType = .numeric
        }
    }

    private func enable2FAAndContinue(withPin pin: String) {
        Logger.debug("")

        pinTextField.resignFirstResponder()

        let progressView = AnimatedProgressView(
            loadingText: NSLocalizedString("UNLOCK_PASSWORD_CREATION_UNLOCK_PASSWORD_PROGRESS",
                                           comment: "Indicates the work we are doing while creating the user's unlock-password")
        )
        view.addSubview(progressView)
        progressView.autoPinWidthToSuperview()
        progressView.autoVCenterInSuperview()

        progressView.startAnimating {
            self.view.isUserInteractionEnabled = false
            self.nextButton.alpha = 0.5
            self.pinTextField.alpha = 0
            self.validationWarningLabel.alpha = 0
            self.recommendationLabel.alpha = 0
        }
        
        // UserDefaults.standard.removeObject(forKey: "password")
        UserDefaults.standard.set(pin, forKey: kUnlockPassword)
        self.completionHandler(self, nil)
    }
}

// MARK: -

extension UnlockPasswordSetupViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let hasPendingChanges: Bool
        if pinType == .numeric {
            ViewControllerUtils.ows2FAPINTextField(textField, shouldChangeCharactersIn: range, replacementString: string)
            hasPendingChanges = false
        } else {
            hasPendingChanges = true
        }

        // Reset the validation state to clear errors, since the user is trying again
        validationState = .valid

        // Inform our caller whether we took care of performing the change.
        return hasPendingChanges
    }
}
