//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

struct CDSRegisteredContact: Hashable {
    let signalUuid: UUID
    let e164PhoneNumber: String
}

/// Fetches contact info from the ContactDiscoveryService
/// Intended to be used by ContactDiscoveryTask. You probably don't want to use this directly.
class ModernContactDiscoveryOperation: ContactDiscovering {
    static let batchSize = 2048

    private let e164sToLookup: Set<String>
    required init(e164sToLookup: Set<String>) {
        self.e164sToLookup = e164sToLookup
        Logger.debug("with e164sToLookup.count: \(e164sToLookup.count)")
    }

    func perform(on queue: DispatchQueue) -> Promise<Set<DiscoveredContactInfo>> {
        firstly { () -> Promise<[Set<CDSRegisteredContact>]> in
            // First, build a bunch of batch Promises
            let batchOperationPromises = Array(e164sToLookup)
                .chunked(by: Self.batchSize)
                .map{ makeContactRequestFromChatServer(e164sToLookup: $0) }
                //.map { makeContactDiscoveryRequest(e164sToLookup: $0) }

            // Then, wait for them all to be fulfilled before joining the subsets together
            return Promise.when(fulfilled: batchOperationPromises)

        }.map(on: queue) { (setArray) -> Set<DiscoveredContactInfo> in
            setArray.reduce(into: Set()) { (builder, cdsContactSubset) in
                builder.formUnion(cdsContactSubset.map {
                    DiscoveredContactInfo(e164: $0.e164PhoneNumber, uuid: $0.signalUuid)
                })
            }
        }.recover(on: queue) { error -> Promise<Set<DiscoveredContactInfo>> in
            throw Self.prepareExternalError(from: error)
        }
    }

    // Below, we have a bunch of then blocks being performed on a global concurrent queue
    // It might be worthwhile to audit and see if we can move these onto the queue passed into `perform(on:)`

    private func makeContactDiscoveryRequest(e164sToLookup: [String]) -> Promise<Set<CDSRegisteredContact>> {
        firstly { () -> Promise<RemoteAttestation.CDSAttestation> in
            RemoteAttestation.performForCDS()

        }.then(on: .global()) { (attestation: RemoteAttestation.CDSAttestation) -> Promise<(RemoteAttestation.CDSAttestation, ContactDiscoveryService.IntersectionResponse)> in
            let service = ContactDiscoveryService()
            let query = try self.buildIntersectionQuery(e164sToLookup: e164sToLookup,
                                                        remoteAttestations: attestation.remoteAttestations)
            return service.getRegisteredSignalUsers(
                query: query,
                cookies: attestation.cookies,
                authUsername: attestation.auth.username,
                authPassword: attestation.auth.password,
                enclaveName: attestation.enclaveConfig.enclaveName,
                host: attestation.enclaveConfig.host,
                censorshipCircumventionPrefix: attestation.enclaveConfig.censorshipCircumventionPrefix
            ).map {(attestation, $0)}

        }.map(on: .global()) { attestation, response -> Set<CDSRegisteredContact> in
            let allEnclaveAttestations = attestation.remoteAttestations
            let respondingEnclaveAttestation = allEnclaveAttestations.first(where: { $1.requestId == response.requestId })

            guard let responseAttestion = respondingEnclaveAttestation?.value else {
                throw ContactDiscoveryError.assertionError(description: "Invalid responding enclave for requestId: \(response.requestId)")
            }
            guard let plaintext = Cryptography.decryptAESGCM(
                withInitializationVector: response.iv,
                ciphertext: response.data,
                additionalAuthenticatedData: nil,
                authTag: response.mac,
                key: responseAttestion.keys.serverKey) else {
                throw ContactDiscoveryError.assertionError(description: "decryption failed")
            }

            // 16 bytes per UUID
            let contactCount = UInt(e164sToLookup.count)
            guard plaintext.count == contactCount * 16 else {
                throw ContactDiscoveryError.assertionError(description: "failed check: invalid byte count")
            }
            let dataParser = OWSDataParser(data: plaintext)
            let uuidsData = try dataParser.nextData(length: contactCount * 16, name: "uuids")

            guard dataParser.isEmpty else {
                throw ContactDiscoveryError.assertionError(description: "failed check: dataParse.isEmpty")
            }

            let uuids = type(of: self).uuidArray(from: uuidsData)

            guard uuids.count == contactCount else {
                throw ContactDiscoveryError.assertionError(description: "failed check: uuids.count == contactCount")
            }

            let unregisteredUuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

            var registeredContacts: Set<CDSRegisteredContact> = Set()

            for (index, e164PhoneNumber) in e164sToLookup.enumerated() {
                let uuid = uuids[index]
                guard uuid != unregisteredUuid else {
                    Logger.verbose("not a signal user: \(e164PhoneNumber)")
                    continue
                }

                Logger.verbose("Morse user. e164: \(e164PhoneNumber), uuid: \(uuid)")
                registeredContacts.insert(CDSRegisteredContact(signalUuid: uuid,
                                                               e164PhoneNumber: e164PhoneNumber))
            }

            return registeredContacts
        }
    }

    private func makeContactRequestFromChatServer(e164sToLookup: [String]) -> Promise<Set<CDSRegisteredContact>> {
        firstly { () -> Promise<Any> in
            let service = ContactDiscoveryService()
          
            return service.getRegisteredSignalUsersFromChatServer(
               e164sToLookup: e164sToLookup
            )

        }.map(on: .global()) { json -> Set<CDSRegisteredContact> in
            guard let params = ParamParser(responseObject: json) else {
                throw OWSAssertionError("invalid response: \(String(describing: json))")
            }
            guard let contacts: [Any] = try params.required(key: "contacts") else {
                throw OWSAssertionError("Missing or invalid contacts.")
            }
            var registeredContacts: Set<CDSRegisteredContact> = Set()
            for contact in contacts {
                guard let contactParser = ParamParser(responseObject: contact) else {
                    throw OWSAssertionError("invalid contact: \(String(describing: contact))")
                }
                guard let number: String = try contactParser.required(key: "number") else {
                    throw OWSAssertionError("Missing or invalid number.")
                }
                guard let token: String = try contactParser.required(key: "token") else {
                    throw OWSAssertionError("Missing or invalid token.")
                }
         
                guard let uuid = UUID(uuidString:token) else {
                    throw OWSAssertionError("invalid uuid.")
                }

                registeredContacts.insert(CDSRegisteredContact(signalUuid: uuid,
                                                               e164PhoneNumber: number))
            }
            return registeredContacts
        }
    }
    
    private func parseContactsResponse(responseObject: Any?) throws -> Set<CDSRegisteredContact> {
        guard let responseObject = responseObject else {
            throw OWSAssertionError("Missing response.")
        }

        guard let params = ParamParser(responseObject: responseObject) else {
            throw OWSAssertionError("invalid response: \(String(describing: responseObject))")
        }
        guard let contacts: [Any] = try params.required(key: "contacts") else {
            throw OWSAssertionError("Missing or invalid contacts.")
        }
        var registeredContacts: Set<CDSRegisteredContact> = Set()
        for contact in contacts {
            guard let contactParser = ParamParser(responseObject: contact) else {
                throw OWSAssertionError("invalid contact: \(String(describing: contact))")
            }
            guard let number: String = try contactParser.required(key: "number") else {
                throw OWSAssertionError("Missing or invalid number.")
            }
            guard let token: String = try contactParser.required(key: "token") else {
                throw OWSAssertionError("Missing or invalid token.")
            }
     
            guard let uuid = UUID(uuidString:token) else {
                throw OWSAssertionError("invalid uuid.")
            }

            registeredContacts.insert(CDSRegisteredContact(signalUuid: uuid,
                                                           e164PhoneNumber: number))
        }
        return registeredContacts
    }

    func buildIntersectionQuery(e164sToLookup: [String], remoteAttestations: [RemoteAttestation.CDSAttestation.Id: RemoteAttestation]) throws -> ContactDiscoveryService.IntersectionQuery {
        let noncePlainTextData = Randomness.generateRandomBytes(32)
        let addressPlainTextData = try type(of: self).encodePhoneNumbers(e164sToLookup)
        let queryData = Data.join([noncePlainTextData, addressPlainTextData])

        let key = OWSAES256Key.generateRandom()
        guard let encryptionResult = Cryptography.encryptAESGCM(plainTextData: queryData,
                                                                initializationVectorLength: kAESGCM256_DefaultIVLength,
                                                                additionalAuthenticatedData: nil,
                                                                key: key) else {
                                                                    throw ContactDiscoveryError.assertionError(description: "Encryption failure")
        }
        assert(encryptionResult.ciphertext.count == e164sToLookup.count * 8 + 32)

        let queryEnvelopes: [RemoteAttestation.CDSAttestation.Id: ContactDiscoveryService.IntersectionQuery.EnclaveEnvelope] = try remoteAttestations.mapValues { remoteAttestation in
            guard let perEnclaveKey = Cryptography.encryptAESGCM(plainTextData: key.keyData,
                                                                 initializationVectorLength: kAESGCM256_DefaultIVLength,
                                                                 additionalAuthenticatedData: remoteAttestation.requestId,
                                                                 key: remoteAttestation.keys.clientKey) else {
                                                                    throw ContactDiscoveryError.assertionError(description: "failed to encrypt perEnclaveKey")
            }

            return ContactDiscoveryService.IntersectionQuery.EnclaveEnvelope(requestId: remoteAttestation.requestId,
                                                                             data: perEnclaveKey.ciphertext,
                                                                             iv: perEnclaveKey.initializationVector,
                                                                             mac: perEnclaveKey.authTag)
        }

        guard let commitment = Cryptography.computeSHA256Digest(queryData) else {
            throw ContactDiscoveryError.assertionError(description: "commitment was unexpectedly nil")
        }

        return ContactDiscoveryService.IntersectionQuery(addressCount: UInt(e164sToLookup.count),
                                                         commitment: commitment,
                                                         data: encryptionResult.ciphertext,
                                                         iv: encryptionResult.initializationVector,
                                                         mac: encryptionResult.authTag,
                                                         envelopes: queryEnvelopes)
    }
    
    class func encodePhoneNumbers(_ phoneNumbers: [String]) throws -> Data {
        var output = Data()

        for phoneNumber in phoneNumbers {
            guard phoneNumber.prefix(1) == "+" else {
                throw ContactDiscoveryError.assertionError(description: "unexpected id format")
            }

            let numericPortionIndex = phoneNumber.index(after: phoneNumber.startIndex)
            let numericPortion = phoneNumber.suffix(from: numericPortionIndex)

            guard let numericIdentifier = UInt64(numericPortion), numericIdentifier > 99 else {
                throw ContactDiscoveryError.assertionError(description: "unexpectedly short identifier")
            }

            var bigEndian: UInt64 = CFSwapInt64HostToBig(numericIdentifier)
            withUnsafePointer(to: &bigEndian) { pointer in
                output.append(UnsafeBufferPointer(start: pointer, count: 1))
            }
        }

        return output
    }

  
    
    class func uuidArray(from data: Data) -> [UUID] {
//        return data.withUnsafeBytes {
//            [uuid_t]($0.bindMemory(to: uuid_t.self))
//        }.map {
//            UUID(uuid: $0)
//        }
        //chatgpt修改后的版本
//        return (0.stride(to: data.count, by: MemoryLayout<UUID>.stride))
//                .compactMap { index in
//                    guard let uuid = try? UUID(uuid: data.withUnsafeBytes({ $0.advanced(by: index).pointee })) else {
//                        return nil
//                    }
//                    return uuid
//                }
        //还是没对，editor就检查出两个错误，stride方法错误，return nil也错了
//        var uuids: [UUID] = []
//            for index in stride(from: 0, to: data.count, by: MemoryLayout<UUID>.size) {
//                let uuidData = data.subdata(in: index..<(index + MemoryLayout<UUID>.size))
//                if let uuid = UUID(data: uuidData) {
//                    uuids.append(uuid)
//                }
//            }
//            return uuids
        //Argument passed to call that takes no arguments。 UUID(data: uuidData)错了
//        var uuids: [UUID] = []
//            for index in stride(from: 0, to: data.count, by: MemoryLayout<UUID>.size) {
//                let uuidBytes = data.subdata(in: index..<(index + MemoryLayout<UUID>.size))
//                let uuid = UUID(uuid: uuidBytes)
//                uuids.append(uuid)
//            }
//            return uuids
        //Cannot convert value of type 'Data' to expected argument type 'uuid_t' (aka '(UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)') UUID(uuid: uuidBytes)
//        var uuids: [UUID] = []
//            for index in stride(from: 0, to: data.count, by: MemoryLayout<uuid_t>.size) {
//                var uuid_bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//                data.copyBytes(to: &uuid_bytes, from: index..<(index + MemoryLayout<uuid_t>.size))
//                let uuid = UUID(uuid: uuid_bytes)
//                uuids.append(uuid)
//            }
//            return uuids
        //Cannot convert value of type 'uuid_t' (aka '(UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)') to expected argument type 'UnsafeMutableRawBufferPointer'
//        var uuids: [UUID] = []
//            for index in stride(from: 0, to: data.count, by: MemoryLayout<uuid_t>.size) {
//                var uuid_bytes = [UInt8](repeating: 0, count: MemoryLayout<uuid_t>.size)
//                data.copyBytes(to: &uuid_bytes, from: index..<(index + MemoryLayout<uuid_t>.size))
//                let uuid = UUID(uuid: uuid_bytes)
//                uuids.append(uuid)
//            }
//            return uuids
        ///Users/zhenghongli/work/morse/Morse-iOS/SignalServiceKit/src/Contacts/Discovery/ModernContactDiscoveryOperation.swift:300:39 Cannot convert value of type '[UInt8]' to expected argument type 'uuid_t' (aka '(UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)')
//        var uuids: [UUID] = []
//            for index in stride(from: 0, to: data.count, by: MemoryLayout<uuid_t>.size) {
//                var uuid_bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//                data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
//                    let destPtr = buffer.baseAddress!.advanced(by: index)
//                    buffer.copyBytes(from: destPtr, count: MemoryLayout<uuid_t>.size)
//                }
//                let uuid = UUID(uuid: uuid_bytes)
//                uuids.append(uuid)
//            }
//            return uuids
        //最后coze 修改的版本，至少editor语法没有错误，看看编译情况
        return data.withUnsafeBytes { (rawBufferPointer) -> [UUID] in
                // Ensure the raw pointer is bound to the correct type
                let bufferPointer = rawBufferPointer.bindMemory(to: uuid_t.self)
                
                // Convert the buffer pointer to an array of uuid_t
                let uuidArray = Array(bufferPointer)
                
                // Map the array of uuid_t to an array of UUID
                return uuidArray.map { UUID(uuid: $0) }
            }
        
    }

    /// Parse the error and, if appropriate, construct an error appropriate to return upwards
    /// May return the provided error unchanged.
    class func prepareExternalError(from error: Error) -> Error {
        // Network connectivity failures should never be re-wrapped
        if error.isNetworkConnectivityFailure {
            return error
        }

        let retryAfterDate = error.httpRetryAfterDate

        if let statusCode = error.httpStatusCode {
            switch statusCode {
            case 401:
                return ContactDiscoveryError(
                    kind: .unauthorized,
                    debugDescription: "User is unauthorized",
                    retryable: false,
                    retryAfterDate: retryAfterDate)
            case 404:
                return ContactDiscoveryError(
                    kind: .unexpectedResponse,
                    debugDescription: "Unknown enclaveID",
                    retryable: false,
                    retryAfterDate: retryAfterDate)
            case 408:
                return ContactDiscoveryError(
                    kind: .timeout,
                    debugDescription: "Server rejected due to a timeout",
                    retryable: true,
                    retryAfterDate: retryAfterDate)
            case 409:
                // Conflict on a discovery request indicates that the requestId specified by the client
                // has been dropped due to a delay or high request rate since the preceding corresponding
                // attestation request. The client should not retry the request automatically
                return ContactDiscoveryError(
                    kind: .genericClientError,
                    debugDescription: "RequestID conflict",
                    retryable: false,
                    retryAfterDate: retryAfterDate)
            case 429:
                return ContactDiscoveryError(
                    kind: .rateLimit,
                    debugDescription: "Rate limit",
                    retryable: true,
                    retryAfterDate: retryAfterDate)
            case 400..<500:
                return ContactDiscoveryError(
                    kind: .genericClientError,
                    debugDescription: "Client error (\(statusCode)): \(error.userErrorDescription)",
                    retryable: false,
                    retryAfterDate: retryAfterDate)
            case 500..<600:
                return ContactDiscoveryError(
                    kind: .genericServerError,
                    debugDescription: "Server error (\(statusCode)): \(error.userErrorDescription)",
                    retryable: true,
                    retryAfterDate: retryAfterDate)
            default:
                return ContactDiscoveryError(
                    kind: .generic,
                    debugDescription: "Unknown error (\(statusCode)): \(error.userErrorDescription)",
                    retryable: false,
                    retryAfterDate: retryAfterDate)
            }

        } else {
            return error
        }
    }
}
