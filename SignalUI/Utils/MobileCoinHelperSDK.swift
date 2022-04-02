//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
//import MobileCoin

@objc
public class MobileCoinHelperSDK: NSObject, MobileCoinHelper {

    public func info(forReceiptData receiptData: Data) throws -> MobileCoinReceiptInfo {
        throw OWSAssertionError("Invalid receipt.")
//        guard let receipt = MobileCoin.Receipt(serializedData: receiptData) else {
//            throw OWSAssertionError("Invalid receipt.")
//        }
//        return MobileCoinReceiptInfo(txOutPublicKey: receipt.txOutPublicKey)
    }

    public func isValidMobileCoinPublicAddress(_ addressData: Data) -> Bool {
        return true
        //MobileCoin.PublicAddress(serializedData: addressData) != nil
    }
}
