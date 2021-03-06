//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import <SignalServiceKit/BaseModel.h>

NS_ASSUME_NONNULL_BEGIN

@class SignalServiceAddress;

@interface TSMention : BaseModel

@property (nonatomic, readonly) NSString *uniqueMessageId;
@property (nonatomic, readonly) NSString *uniqueThreadId;
@property (nonatomic, readonly) NSString *uuidString;
@property (nonatomic, readonly) NSDate *creationTimestamp;

@property (nonatomic, readonly) SignalServiceAddress *address;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithUniqueId:(NSString *)uniqueId NS_UNAVAILABLE;
- (instancetype)initWithGrdbId:(int64_t)grdbId uniqueId:(NSString *)uniqueId NS_UNAVAILABLE;

- (instancetype)initWithUniqueMessageId:(NSString *)uniqueMessageId
                         uniqueThreadId:(NSString *)uniqueThreadId
                             uuidString:(NSString *)uuidString NS_DESIGNATED_INITIALIZER;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
               creationTimestamp:(NSDate *)creationTimestamp
                 uniqueMessageId:(NSString *)uniqueMessageId
                  uniqueThreadId:(NSString *)uniqueThreadId
                      uuidString:(NSString *)uuidString
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:creationTimestamp:uniqueMessageId:uniqueThreadId:uuidString:));

// clang-format on

// --- CODE GENERATION MARKER

@end

NS_ASSUME_NONNULL_END
