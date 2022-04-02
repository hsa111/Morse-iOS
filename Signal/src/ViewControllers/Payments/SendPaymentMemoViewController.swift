//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import UIKit
import SignalUI

@objc
public protocol SendPaymentMemoViewDelegate {
    func didChangeMemo(memoMessage: String?)
}

// MARK: -

@objc
public class SendPaymentMemoViewController: OWSViewController {

    @objc
    public weak var delegate: SendPaymentMemoViewDelegate?

    private let rootStack = UIStackView()

    private let memoTextField = UITextField()
    private let memoCharacterCountLabel = UILabel()

    public required init(memoMessage: String?) {
        super.init()

        memoTextField.text = memoMessage
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        createContents()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        memoTextField.becomeFirstResponder()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        memoTextField.becomeFirstResponder()
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.isIPad ? .all : .portrait
    }

    private func createContents() {
        navigationItem.title = NSLocalizedString("PAYMENTS_NEW_PAYMENT_ADD_MEMO",
                                                 comment: "Label for the 'add memo' ui in the 'send payment' UI.")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(didTapCancelMemo),
                                                           accessibilityIdentifier: "memo.cancel")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self,
                                                            action: #selector(didTapDoneMemo),
                                                            accessibilityIdentifier: "memo.done")

        rootStack.axis = .vertical
        rootStack.alignment = .fill
        rootStack.layoutMargins = UIEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        rootStack.isLayoutMarginsRelativeArrangement = true
        view.addSubview(rootStack)
        rootStack.autoPinEdge(toSuperviewMargin: .leading)
        rootStack.autoPinEdge(toSuperviewMargin: .trailing)
        rootStack.autoPin(toTopLayoutGuideOf: self, withInset: 0)
        autoPinView(toBottomOfViewControllerOrKeyboard: rootStack, avoidNotch: true)

        updateContents()
    }

    private func updateContents() {
        AssertIsOnMainThread()

        rootStack.removeAllSubviews()

        view.backgroundColor = OWSTableViewController2.tableBackgroundColor(isUsingPresentedStyle: true)

        memoTextField.backgroundColor = .clear
        memoTextField.font = .ows_dynamicTypeBodyClamped
        memoTextField.textColor = Theme.primaryTextColor
        let placeholder = NSAttributedString(string: NSLocalizedString("PAYMENTS_NEW_PAYMENT_MESSAGE_PLACEHOLDER",
                                                                       comment: "Placeholder for the new payment or payment request message."),
                                             attributes: [
                                                .foregroundColor: Theme.secondaryTextAndIconColor
                                             ])
        memoTextField.attributedPlaceholder = placeholder
        memoTextField.delegate = self
        memoTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        memoCharacterCountLabel.font = .ows_dynamicTypeBodyClamped
        memoCharacterCountLabel.textColor = Theme.ternaryTextColor

        memoCharacterCountLabel.setCompressionResistanceHorizontalHigh()
        memoCharacterCountLabel.setContentHuggingHorizontalHigh()

        let memoRow = UIStackView(arrangedSubviews: [
            memoTextField,
            memoCharacterCountLabel
        ])
        memoRow.axis = .horizontal
        memoRow.spacing = 8
        memoRow.alignment = .center
        memoRow.isLayoutMarginsRelativeArrangement = true
        memoRow.layoutMargins = UIEdgeInsets(hMargin: 16, vMargin: 14)
        let backgroundColor = OWSTableViewController2.cellBackgroundColor(isUsingPresentedStyle: true)
        let backgroundView = memoRow.addBackgroundView(withBackgroundColor: backgroundColor)
        backgroundView.layer.cornerRadius = 10

        updateMemoCharacterCount()

        rootStack.addArrangedSubviews([
            UIView.spacer(withHeight: SendPaymentHelper.minTopVSpacing),
            memoRow,
            UIView.vStretchingSpacer()
        ])
    }

    public override func applyTheme() {
        super.applyTheme()

        updateContents()
    }

    // MARK: -

    fileprivate func updateMemoCharacterCount() {
    }

    // MARK: - Events

    @objc
    func didTapCancelMemo() {
        navigationController?.popViewController(animated: true)
    }

    @objc
    func didTapDoneMemo() {
        let memoMessage = memoTextField.text?.ows_stripped()
        delegate?.didChangeMemo(memoMessage: memoMessage)
        navigationController?.popViewController(animated: true)
    }

    @objc
    func textFieldDidChange(_ textField: UITextField) {
        updateMemoCharacterCount()
    }
}

// MARK: 

extension SendPaymentMemoViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString: String) -> Bool {
        return false
    }
}
