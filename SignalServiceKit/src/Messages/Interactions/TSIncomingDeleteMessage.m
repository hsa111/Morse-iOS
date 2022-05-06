//
//  TSIncomingDeleteMessage.m
//  SignalServiceKit
//
//  Created by ZhengHong Li on 2022/5/6.
//

#import "TSIncomingDeleteMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSIncomingDeleteMessage ()

@property (nonatomic, readonly) uint64_t messageTimestamp;
@property (nonatomic, readonly, nullable) NSString *messageUniqueId;
@property (nonatomic, readonly, nullable) NSString *authorNumber;

@end

#pragma mark -

@implementation TSIncomingDeleteMessage

- (instancetype)initWithThread:(TSThread *)thread message:(TSIncomingMessage *)message
{
    OWSAssertDebug([thread.uniqueId isEqualToString:message.uniqueThreadId]);

    TSOutgoingMessageBuilder *messageBuilder = [TSOutgoingMessageBuilder outgoingMessageBuilderWithThread:thread];
    self = [super initOutgoingMessageWithBuilder:messageBuilder];
    
    if (!self) {
        return self;
    }

    _messageTimestamp = message.timestamp;
    _messageUniqueId = message.uniqueId;
    _authorNumber = message.authorPhoneNumber;

    return self;
}

- (BOOL)shouldBeSaved
{
    return NO;
}

- (nullable SSKProtoDataMessageBuilder *)dataMessageBuilderWithThread:(TSThread *)thread
                                                          transaction:(SDSAnyReadTransaction *)transaction
{
//    SSKProtoDataMessageDeleteBuilder *deleteBuilder =
//        [SSKProtoDataMessageDelete builderWithTargetSentTimestamp:self.messageTimestamp];
    SSKProtoDataMessageDeleteBuilder *deleteBuilder =
        [SSKProtoDataMessageDelete builderWithTargetSentTimestamp:self.messageTimestamp authorNumber:_authorNumber];

    NSError *error;
    SSKProtoDataMessageDelete *_Nullable deleteProto = [deleteBuilder buildAndReturnError:&error];
    if (error || !deleteProto) {
        OWSFailDebug(@"could not build protobuf: %@", error);
        return nil;
    }

    SSKProtoDataMessageBuilder *builder = [super dataMessageBuilderWithThread:thread transaction:transaction];
    [builder setTimestamp:self.timestamp];
    [builder setDelete:deleteProto];

    return builder;
}

- (void)anyUpdateOutgoingMessageWithTransaction:(SDSAnyWriteTransaction *)transaction
                                          block:(void(NS_NOESCAPE ^)(TSOutgoingMessage *_Nonnull))block
{
    [super anyUpdateOutgoingMessageWithTransaction:transaction block:block];

    // Some older outgoing delete messages didn't store the deleted message's unique id.
    // We want to mirror our sending state onto the original message, so it shows up
    // within the conversation.
//    if (self.messageUniqueId) {
//        TSOutgoingMessage *deletedMessage = [TSOutgoingMessage anyFetchOutgoingMessageWithUniqueId:self.messageUniqueId
//                                                                                       transaction:transaction];
//        [deletedMessage updateWithRecipientAddressStates:self.recipientAddressStates transaction:transaction];
//    }
}

- (NSSet<NSString *> *)relatedUniqueIds
{
    return [[super relatedUniqueIds] setByAddingObjectsFromArray:@[ self.messageUniqueId ]];
}

@end

NS_ASSUME_NONNULL_END

