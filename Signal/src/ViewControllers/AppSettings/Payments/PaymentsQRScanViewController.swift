//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

public protocol PaymentsQRScanDelegate: AnyObject {
    func didScanPaymentAddressQRCode(publicAddressBase58: String)
}

// MARK: -

public class PaymentsQRScanViewController: OWSViewController {

    private weak var delegate: PaymentsQRScanDelegate?

    private let qrCodeScanViewController = QRCodeScanViewController(appearance: .normal)

    public required init(delegate: PaymentsQRScanDelegate) {
        self.delegate = delegate
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("SETTINGS_PAYMENTS_SCAN_QR_TITLE",
                                  comment: "Label for 'scan payment address QR code' view in the payment settings.")

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(didTapCancel),
                                                           accessibilityIdentifier: "cancel")

        createViews()
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.isIPad ? .all : .portrait
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func createViews() {
        view.backgroundColor = .ows_black

        qrCodeScanViewController.delegate = self
        addChild(qrCodeScanViewController)
        let qrView = qrCodeScanViewController.view!
        view.addSubview(qrView)
        qrView.autoPinWidthToSuperview()
        qrView.autoPin(toTopLayoutGuideOf: self, withInset: 0)

        let footer = UIView.container()
        footer.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        view.addSubview(footer)
        footer.autoPinWidthToSuperview()
        footer.autoPinEdge(toSuperviewEdge: .bottom)
        footer.autoPinEdge(.top, to: .bottom, of: qrView)

        let instructionsLabel = UILabel()
        instructionsLabel.text = NSLocalizedString("SETTINGS_PAYMENTS_SCAN_QR_INSTRUCTIONS",
                                                        comment: "Instructions in the 'scan payment address QR code' view in the payment settings.")
        instructionsLabel.font = .ows_dynamicTypeBody
        instructionsLabel.textColor = .ows_white
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        instructionsLabel.lineBreakMode = .byWordWrapping
        footer.addSubview(instructionsLabel)
        instructionsLabel.autoPinWidthToSuperview(withMargin: 20)
        instructionsLabel.autoPin(toBottomLayoutGuideOf: self, withInset: 16)
        instructionsLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 16)
    }

    // MARK: - Events

    @objc
    func didTapCancel() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: -

extension PaymentsQRScanViewController: QRCodeScanDelegate {

    func qrCodeScanViewDismiss(_ qrCodeScanViewController: QRCodeScanViewController) {
        AssertIsOnMainThread()

        navigationController?.popViewController(animated: true)
    }

    func qrCodeScanViewScanned(_ qrCodeScanViewController: QRCodeScanViewController,
                               qrCodeData: Data?,
                               qrCodeString: String?) -> QRCodeScanOutcome {
        AssertIsOnMainThread()

        return .stopScanning
   }
}
