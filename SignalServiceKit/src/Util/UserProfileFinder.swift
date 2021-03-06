//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

@objc
public class AnyUserProfileFinder: NSObject {
    let grdbAdapter = GRDBUserProfileFinder()
}

public extension AnyUserProfileFinder {
    @objc(userProfileForAddress:transaction:)
    func userProfile(for address: SignalServiceAddress, transaction: SDSAnyReadTransaction) -> OWSUserProfile? {
        let profile: OWSUserProfile?
        switch transaction.readTransaction {
        case .grdbRead(let transaction):
            profile = grdbAdapter.userProfile(for: address, transaction: transaction)
        }
        profile?.loadBadgeContent(with: transaction)
        return profile
    }

    @objc(userProfileForUUID:transaction:)
    func userProfileForUUID(_ uuid: UUID, transaction: SDSAnyReadTransaction) -> OWSUserProfile? {
        let profile: OWSUserProfile?
        switch transaction.readTransaction {
        case .grdbRead(let transaction):
            profile = grdbAdapter.userProfileForUUID(uuid, transaction: transaction)
        }
        profile?.loadBadgeContent(with: transaction)
        return profile
    }

    @objc(userProfileForPhoneNumber:transaction:)
    func userProfileForPhoneNumber(_ phoneNumber: String, transaction: SDSAnyReadTransaction) -> OWSUserProfile? {
        let profile: OWSUserProfile?
        switch transaction.readTransaction {
        case .grdbRead(let transaction):
            profile = grdbAdapter.userProfileForPhoneNumber(phoneNumber, transaction: transaction)
        }
        profile?.loadBadgeContent(with: transaction)
        return profile
    }

    @objc
    func userProfile(forUsername username: String, transaction: SDSAnyReadTransaction) -> OWSUserProfile? {
        let profile: OWSUserProfile?
        switch transaction.readTransaction {
        case .grdbRead(let transaction):
            profile = grdbAdapter.userProfile(forUsername: username.lowercased(), transaction: transaction)
        }
        profile?.loadBadgeContent(with: transaction)
        return profile
    }

    @objc
    func enumerateMissingAndStaleUserProfiles(transaction: SDSAnyReadTransaction, block: @escaping (OWSUserProfile) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let transaction):
            grdbAdapter.enumerateMissingAndStaleUserProfiles(transaction: transaction, block: block)
        }
    }
}

// MARK: -

@objc
class GRDBUserProfileFinder: NSObject {
    func userProfile(for address: SignalServiceAddress, transaction: GRDBReadTransaction) -> OWSUserProfile? {
        if let userProfile = userProfileForUUID(address.uuid, transaction: transaction) {
            return userProfile
        } else if let userProfile = userProfileForPhoneNumber(address.phoneNumber, transaction: transaction) {
            return userProfile
        } else {
            return nil
        }
    }

    fileprivate func userProfileForUUID(_ uuid: UUID?, transaction: GRDBReadTransaction) -> OWSUserProfile? {
        guard let uuidString = uuid?.uuidString else { return nil }
        let sql = "SELECT * FROM \(UserProfileRecord.databaseTableName) WHERE \(userProfileColumn: .recipientUUID) = ?"
        return OWSUserProfile.grdbFetchOne(sql: sql, arguments: [uuidString], transaction: transaction)
    }

    fileprivate func userProfileForPhoneNumber(_ phoneNumber: String?, transaction: GRDBReadTransaction) -> OWSUserProfile? {
        guard let phoneNumber = phoneNumber else { return nil }
        let sql = "SELECT * FROM \(UserProfileRecord.databaseTableName) WHERE \(userProfileColumn: .recipientPhoneNumber) = ?"
        return OWSUserProfile.grdbFetchOne(sql: sql, arguments: [phoneNumber], transaction: transaction)
    }

    func userProfile(forUsername username: String, transaction: GRDBReadTransaction) -> OWSUserProfile? {
        let sql = "SELECT * FROM \(UserProfileRecord.databaseTableName) WHERE \(userProfileColumn: .username) = ? LIMIT 1"
        return OWSUserProfile.grdbFetchOne(sql: sql, arguments: [username], transaction: transaction)
    }

    func enumerateMissingAndStaleUserProfiles(transaction: GRDBReadTransaction, block: @escaping (OWSUserProfile) -> Void) {
        // We are only interested in active users, e.g. users
        // which the local user has sent or received a message
        // from in the last N days.
        let activeTimestamp = NSDate.ows_millisecondTimeStamp() - (30 * kDayInMs)
        let activeDate = NSDate.ows_date(withMillisecondsSince1970: activeTimestamp)

        // We are only interested in stale profiles, e.g. profiles
        // that have never been fetched or haven't been fetched
        // in the last N days.
        let staleTimestamp = NSDate.ows_millisecondTimeStamp() - (1 * kDayInMs)
        let staleDate = NSDate.ows_date(withMillisecondsSince1970: staleTimestamp)

        // TODO: Skip if no profile key?

        // SQLite treats NULL as less than any other value for the purposes of ordering, so:
        //
        // * ".lastFetchDate ASC" will correct order rows without .lastFetchDate first.
        //
        // But SQLite date comparison clauses will be false if a date is NULL, so:
        //
        // * ".lastMessagingDate > activeDate" will correctly filter out rows without .lastMessagingDate.
        // * ".lastFetchDate < staleDate" will _NOT_ correctly include rows without .lastFetchDate;
        //   we need to explicitly test for NULL.
        let sql = """
        SELECT *
        FROM \(UserProfileRecord.databaseTableName)
        WHERE \(userProfileColumn: .lastMessagingDate) > ?
        AND (
        \(userProfileColumn: .lastFetchDate) < ? OR
        \(userProfileColumn: .lastFetchDate) IS NULL
        )
        ORDER BY \(userProfileColumn: .lastFetchDate) ASC
        LIMIT 50
        """
        let arguments: StatementArguments = [convertDateForGrdb(activeDate), convertDateForGrdb(staleDate)]
        let cursor = OWSUserProfile.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)

        do {
            while let userProfile = try cursor.next() {
                block(userProfile)
            }
        } catch {
            owsFailDebug("unexpected error \(error)")
        }
    }
}
