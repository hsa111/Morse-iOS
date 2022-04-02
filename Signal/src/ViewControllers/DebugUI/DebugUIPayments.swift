//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalMessaging

#if DEBUG

class DebugUIPayments: DebugUIPage {

    // MARK: Overrides 

    override func name() -> String {
        return "Payments"
    }

    override func section(thread: TSThread?) -> OWSTableSection? {
        var sectionItems = [OWSTableItem]()

        if let contactThread = thread as? TSContactThread {
            sectionItems.append(OWSTableItem(title: "Send payment request") { [weak self] in
                self?.sendPaymentRequestMessage(contactThread: contactThread)
            })
            sectionItems.append(OWSTableItem(title: "Send payment notification") { [weak self] in
                self?.sendPaymentNotificationMessage(contactThread: contactThread)
            })
            sectionItems.append(OWSTableItem(title: "Send payment cancellation") { [weak self] in
                self?.sendPaymentCancellationMessage(contactThread: contactThread)
            })
            sectionItems.append(OWSTableItem(title: "Send payment request + cancellation") { [weak self] in
                self?.sendPaymentRequestAndCancellation(contactThread: contactThread)
            })
            sectionItems.append(OWSTableItem(title: "Create all possible payment models") { [weak self] in
                self?.insertAllPaymentModelVariations(contactThread: contactThread)
            })
            sectionItems.append(OWSTableItem(title: "Send tiny payments: 10") {
                Self.sendTinyPayments(contactThread: contactThread, count: 10)
            })
            // For testing defragmentation.
            sectionItems.append(OWSTableItem(title: "Send tiny payments: 17") {
                Self.sendTinyPayments(contactThread: contactThread, count: 17)
            })
            // For testing defragmentation.
            sectionItems.append(OWSTableItem(title: "Send tiny payments: 40") {
                Self.sendTinyPayments(contactThread: contactThread, count: 40)
            })
            // For testing defragmentation.
            sectionItems.append(OWSTableItem(title: "Send tiny payments: 100") {
                Self.sendTinyPayments(contactThread: contactThread, count: 100)
            })
            sectionItems.append(OWSTableItem(title: "Send tiny payments: 1000") {
                Self.sendTinyPayments(contactThread: contactThread, count: 1000)
            })
        }

        sectionItems.append(OWSTableItem(title: "Delete all payment models") { [weak self] in
            self?.deleteAllPaymentModels()
        })
        
        return OWSTableSection(title: "Payments", items: sectionItems)
    }

    private func sendPaymentRequestMessage(contactThread: TSContactThread) {
    }

    private func sendPaymentNotificationMessage(contactThread: TSContactThread) {
    }

    private func sendPaymentCancellationMessage(contactThread: TSContactThread) {
    }

    private func sendPaymentRequestAndCancellation(contactThread: TSContactThread) {
    }

    private func insertAllPaymentModelVariations(contactThread: TSContactThread) {
        let address = contactThread.contactAddress
        let uuid = address.uuid!

        databaseStorage.write { transaction in
            let paymentAmounts = [
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1),
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1000),
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1000 * 1000),
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1000 * 1000 * 1000),
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1000 * 1000 * 1000 * 1000),
                TSPaymentAmount(currency: .mobileCoin, picoMob: 1000 * 1000 * 1000 * 1000 * 1000)
            ]

            func insertPaymentModel(paymentType: TSPaymentType,
                                    paymentState: TSPaymentState) -> TSPaymentModel {
                let mcReceiptData = Randomness.generateRandomBytes(32)
                var mcTransactionData: Data?
                if paymentState.isIncoming {
                } else {
                    mcTransactionData = Randomness.generateRandomBytes(32)
                }
                var memoMessage: String?
                if arc4random_uniform(2) == 0 {
                    memoMessage = "Pizza Party 🍕"
                }
                var addressUuidString: String?
                if !paymentType.isUnidentified {
                    addressUuidString = uuid.uuidString
                }
                // TODO: requestUuidString
                // TODO: isUnread
                // TODO: mcRecipientPublicAddressData
                // TODO: mobileCoin
                // TODO: feeAmount

                let mobileCoin = MobileCoinPayment(recipientPublicAddressData: nil,
                                                   transactionData: mcTransactionData,
                                                   receiptData: mcReceiptData,
                                                   incomingTransactionPublicKeys: nil,
                                                   spentKeyImages: nil,
                                                   outputPublicKeys: nil,
                                                   ledgerBlockTimestamp: 0,
                                                   ledgerBlockIndex: 0,
                                                   feeAmount: nil)

                let paymentModel = TSPaymentModel(paymentType: paymentType,
                                                  paymentState: paymentState,
                                                  paymentAmount: paymentAmounts.randomElement()!,
                                                  createdDate: Date(),
                                                  addressUuidString: addressUuidString,
                                                  memoMessage: memoMessage,
                                                  requestUuidString: nil,
                                                  isUnread: false,
                                                  mobileCoin: mobileCoin)
                do {
                    try Self.paymentsHelper.tryToInsertPaymentModel(paymentModel, transaction: transaction)
                } catch {
                    owsFailDebug("Error: \(error)")
                }
                return paymentModel
            }

            var paymentModel: TSPaymentModel

            // MARK: - Incoming

            paymentModel = insertPaymentModel(paymentType: .incomingPayment, paymentState: .incomingUnverified)
            paymentModel = insertPaymentModel(paymentType: .incomingPayment, paymentState: .incomingVerified)
            paymentModel = insertPaymentModel(paymentType: .incomingPayment, paymentState: .incomingComplete)

            // MARK: - Outgoing

            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingUnsubmitted)
            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingUnverified)
            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingVerified)
            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingSending)
            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingSent)
            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingComplete)

            // MARK: - Failures

            // TODO: We probably don't want to create .none and .unknown
//            paymentModel = insertPaymentModel(paymentState: .outgoingFailed)
//            paymentModel.update(withPaymentFailure: .none,
//                                paymentState: .outgoingFailed,
//                                transaction: transaction)
//
//            paymentModel = insertPaymentModel(paymentState: .incomingFailed)
//            paymentModel.update(withPaymentFailure: .none,
//                                paymentState: .incomingFailed,
//                                transaction: transaction)
//
//            paymentModel = insertPaymentModel(paymentState: .outgoingFailed)
//            paymentModel.update(withPaymentFailure: .unknown,
//                                paymentState: .outgoingFailed,
//                                transaction: transaction)
//
//            paymentModel = insertPaymentModel(paymentState: .incomingFailed)
//            paymentModel.update(withPaymentFailure: .unknown,
//                                paymentState: .incomingFailed,
//                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingFailed)
            paymentModel.update(withPaymentFailure: .insufficientFunds,
                                paymentState: .outgoingFailed,
                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingFailed)
            paymentModel.update(withPaymentFailure: .validationFailed,
                                paymentState: .outgoingFailed,
                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .incomingPayment, paymentState: .incomingFailed)
            paymentModel.update(withPaymentFailure: .validationFailed,
                                paymentState: .incomingFailed,
                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingFailed)
            paymentModel.update(withPaymentFailure: .notificationSendFailed,
                                paymentState: .outgoingFailed,
                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .incomingPayment, paymentState: .incomingFailed)
            paymentModel.update(withPaymentFailure: .invalid,
                                paymentState: .incomingFailed,
                                transaction: transaction)

            paymentModel = insertPaymentModel(paymentType: .outgoingPayment, paymentState: .outgoingFailed)
            paymentModel.update(withPaymentFailure: .invalid,
                                paymentState: .outgoingFailed,
                                transaction: transaction)

            // MARK: - Unidentified

            paymentModel = insertPaymentModel(paymentType: .incomingUnidentified, paymentState: .incomingComplete)
            paymentModel = insertPaymentModel(paymentType: .outgoingUnidentified, paymentState: .outgoingComplete)
        }
    }

    private static func sendTinyPayments(contactThread: TSContactThread, count: UInt) {
        
    }

    private func deleteAllPaymentModels() {
        databaseStorage.write { transaction in
            TSPaymentModel.anyRemoveAllWithInstantation(transaction: transaction)
        }
    }
}

#endif
