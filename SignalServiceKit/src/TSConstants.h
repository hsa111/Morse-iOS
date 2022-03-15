//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

#ifndef TextSecureKit_Constants_h
#define TextSecureKit_Constants_h

#pragma mark Server Address

#define textSecureHTTPTimeOut 10

#define kLegalTermsUrlString @"https://devplusone.com/legal/"

#define textSecureAccountsAPI @"v1/accounts"
#define textSecureAttributesAPI @"v1/accounts/attributes/"

#define textSecureMessagesAPI @"v1/messages/"
#define textSecureMultiRecipientMessageAPI @"v1/messages/multi_recipient"
#define textSecureKeysAPI @"v2/keys"
#define textSecureSignedKeysAPI @"v2/keys/signed"
#define textSecureDirectoryAPI @"v1/directory"
#define textSecureDeviceProvisioningCodeAPI @"v1/devices/provisioning/code"
#define textSecureDeviceProvisioningAPIFormat @"v1/provisioning/%@"
#define textSecureDevicesAPIFormat @"v1/devices/%@"
#define textSecureVersionedProfileAPI @"v1/profile/"
#define textSecureProfileAvatarFormAPI @"v1/profile/form/avatar"
#define textSecure2FAAPI @"v1/accounts/pin"
#define textSecureRegistrationLockV2API @"v1/accounts/registration_lock"

#endif

NS_ASSUME_NONNULL_END
