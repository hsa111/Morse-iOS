//
//  TSIncomingDeleteMessage.h
//  Pods
//

#import <SignalServiceKit/TSIncomingMessage.h>
#import <SignalServiceKit/TSOutgoingMessage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSIncomingDeleteMessage : TSOutgoingMessage

- (instancetype)initOutgoingMessageWithBuilder:(TSOutgoingMessageBuilder *)outgoingMessageBuilder NS_UNAVAILABLE;

- (instancetype)initWithThread:(TSThread *)thread message:(TSIncomingMessage *)message;

@end

NS_ASSUME_NONNULL_END
