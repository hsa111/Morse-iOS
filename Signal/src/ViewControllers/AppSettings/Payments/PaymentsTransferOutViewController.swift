//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import Lottie

@objc
public class PaymentsTransferOutViewController: OWSTableViewController2 {

    private let transferAmount: TSPaymentAmount?

    // TODO: Should this be a text area?
    private let addressTextfield = UITextField()

    private var addressValue: String? {
        addressTextfield.text?.ows_stripped()
    }

    private var hasValidAddress: Bool {
        guard let addressValue = addressValue else {
            return false
        }
        return !addressValue.isEmpty
    }

    public required init(transferAmount: TSPaymentAmount?) {
        self.transferAmount = transferAmount
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("SETTINGS_PAYMENTS_TRANSFER_OUT_TITLE",
                                  comment: "Label for 'transfer currency out' view in the payment settings.")

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(didTapDismiss),
                                                           accessibilityIdentifier: "dismiss")

        createViews()

        updateTableContents()

        updateNavbar()
    }

    private func updateNavbar() {
        let rightBarButtonItem = UIBarButtonItem(title: CommonStrings.nextButton,
            style: .plain,
            target: self,
            action: #selector(didTapNext)
        )
        rightBarButtonItem.isEnabled = hasValidAddress
        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateTableContents()
        updateNavbar()

        addressTextfield.becomeFirstResponder()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)


        addressTextfield.becomeFirstResponder()
    }

    private func createViews() {
        addressTextfield.delegate = self
        addressTextfield.font = .ows_dynamicTypeBodyClamped
        addressTextfield.keyboardAppearance = Theme.keyboardAppearance
        addressTextfield.accessibilityIdentifier = "payments.transfer.out.addressTextfield"
        addressTextfield.addTarget(self, action: #selector(addressDidChange), for: .editingChanged)
    }

    public override func applyTheme() {
        super.applyTheme()

        updateTableContents()
    }

    @objc
    private func updateTableContents() {
        AssertIsOnMainThread()

        addressTextfield.textColor = Theme.primaryTextColor
        let placeholder = NSAttributedString(string: NSLocalizedString("SETTINGS_PAYMENTS_TRANSFER_OUT_PLACEHOLDER",
                                                                       comment: "Placeholder text for the address text field in the 'transfer currency out' settings view."),
                                             attributes: [
                                                .foregroundColor: Theme.secondaryTextAndIconColor
                                             ])
        addressTextfield.attributedPlaceholder = placeholder

        let contents = OWSTableContents()

        let section = OWSTableSection()
        section.footerTitle = NSLocalizedString("SETTINGS_PAYMENTS_TRANSFER_OUT_FOOTER",
                                                comment: "Footer of the 'transfer currency out' view in the payment settings.")
        let addressTextfield = self.addressTextfield

        let iconView = UIImageView.withTemplateImageName("qr-24", tintColor: Theme.primaryIconColor)
        iconView.autoSetDimensions(to: .square(24))
        iconView.setCompressionResistanceHigh()
        iconView.setContentHuggingHigh()
        iconView.isUserInteractionEnabled = true
        iconView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapScanQR)))

        section.shouldDisableCellSelection = true
        section.add(OWSTableItem(customCellBlock: {
            let cell = OWSTableItem.newCell()

            let stackView = UIStackView(arrangedSubviews: [ addressTextfield, iconView ])
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = 8
            cell.contentView.addSubview(stackView)
            stackView.autoPinEdgesToSuperviewMargins()

            return cell
        },
        actionBlock: nil))
        contents.addSection(section)

        self.contents = contents
    }

    // MARK: - Events

    @objc
    func didTapDismiss() {
        dismiss(animated: true, completion: nil)
    }

    @objc
    private func didTapNext() {
        
            OWSActionSheets.showActionSheet(title: NSLocalizedString("SETTINGS_PAYMENTS_TRANSFER_OUT_INVALID_PUBLIC_ADDRESS_TITLE",
                                                                     comment: "Title for error alert indicating that MobileCoin public address is not valid."),
                                            message: NSLocalizedString("SETTINGS_PAYMENTS_TRANSFER_OUT_INVALID_PUBLIC_ADDRESS",
                                                                       comment: "Error indicating that MobileCoin public address is not valid."))
            return
        
    }

    @objc
    private func addressDidChange() {
        updateNavbar()
    }

    @objc
    private func didTapScanQR() {
        let view = PaymentsQRScanViewController(delegate: self)
        navigationController?.pushViewController(view, animated: true)
    }
}

// MARK: -

extension PaymentsTransferOutViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }
}

// MARK: -

extension PaymentsTransferOutViewController: SendPaymentViewDelegate {
    public func didSendPayment() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: -

extension PaymentsTransferOutViewController: PaymentsQRScanDelegate {
    public func didScanPaymentAddressQRCode(publicAddressBase58: String) {
        addressTextfield.text = publicAddressBase58
        updateNavbar()
    }
}
