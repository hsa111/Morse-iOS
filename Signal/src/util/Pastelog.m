//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "Pastelog.h"
#import "Morse-Swift.h"
#import "zlib.h"
#import <SSZipArchive/SSZipArchive.h>
#import <SignalCoreKit/Threading.h>
#import <SignalMessaging/DebugLogger.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/ThreadUtil.h>
#import <SignalServiceKit/AppContext.h>
#import <SignalServiceKit/MIMETypeUtil.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/TSContactThread.h>
#import <SignalUI/AttachmentSharing.h>
#import <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain PastelogErrorDomain = @"PastelogErrorDomain";

typedef NS_ERROR_ENUM(PastelogErrorDomain, PastelogError) {
    PastelogErrorInvalidNetworkResponse = 10001,
    PastelogErrorEmailFailed = 10002
};

#pragma mark -

@interface Pastelog () <UIAlertViewDelegate>

@property (nonatomic) DebugLogUploader *currentUploader;

@end

#pragma mark -

@implementation Pastelog

+ (instancetype)shared
{
    static Pastelog *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

#pragma mark -

+ (void)submitLogs
{
    [self submitLogsWithCompletion:nil];
}

+ (void)submitLogsWithCompletion:(nullable SubmitDebugLogsCompletion)completionParam
{
    SubmitDebugLogsCompletion completion = ^{
        if (completionParam) {
            // Wait a moment. If PasteLog opens a URL, it needs a moment to complete.
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), completionParam);
        }
    };

    [[self shared] uploadLogsWithUIWithSuccess:^(NSURL *url) {
        ActionSheetController *alert = [[ActionSheetController alloc]
            initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_TITLE", @"Title of the debug log alert.")
                  message:NSLocalizedString(@"DEBUG_LOG_ALERT_MESSAGE", @"Message of the debug log alert.")];
        [alert
            addAction:[[ActionSheetAction alloc]
                                    initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_OPTION_EMAIL",
                                                      @"Label for the 'email debug log' option of the debug log alert.")
                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"send_email")
                                            style:ActionSheetActionStyleDefault
                                          handler:^(ActionSheetAction *action) {
                                              [ComposeSupportEmailOperation
                                                  sendEmailWithDefaultErrorHandlingWithSupportFilter:
                                                      @"Signal - iOS Debug Log"
                                                                                              logUrl:url];
                                              completion();
                                          }]];
        [alert addAction:[[ActionSheetAction alloc]
                                       initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_OPTION_COPY_LINK",
                                                         @"Label for the 'copy link' option of the debug log alert.")
                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"copy_link")
                                               style:ActionSheetActionStyleDefault
                                             handler:^(ActionSheetAction *action) {
                                                 UIPasteboard *pb = [UIPasteboard generalPasteboard];
                                                 [pb setString:url.absoluteString];

                                                 completion();
                                             }]];
#ifdef DEBUG
        [alert
            addAction:[[ActionSheetAction alloc]
                                    initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_OPTION_SEND_TO_SELF",
                                                      @"Label for the 'send to self' option of the debug log alert.")
                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"send_to_self")
                                            style:ActionSheetActionStyleDefault
                                          handler:^(ActionSheetAction *action) { [Pastelog.shared sendToSelf:url]; }]];
#endif
        [alert
            addAction:[[ActionSheetAction
                          alloc] initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_OPTION_BUG_REPORT",
                                                   @"Label for the 'Open a Bug Report' option of the debug log alert.")
                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"submit_bug_report")
                                            style:ActionSheetActionStyleDefault
                                          handler:^(ActionSheetAction *action) {
                                              [Pastelog.shared prepareRedirection:url completion:completion];
                                          }]];
        [alert addAction:[[ActionSheetAction alloc]
                                       initWithTitle:NSLocalizedString(@"DEBUG_LOG_ALERT_OPTION_SHARE",
                                                         @"Label for the 'Share' option of the debug log alert.")
                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"share")
                                               style:ActionSheetActionStyleDefault
                                             handler:^(ActionSheetAction *action) {
                                                 [AttachmentSharing showShareUIForText:url.absoluteString
                                                                                sender:nil
                                                                            completion:completion];
                                             }]];
        [alert addAction:[OWSActionSheets cancelAction]];
        UIViewController *presentingViewController
            = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
        [presentingViewController presentActionSheet:alert];
    }];
}

- (void)uploadLogsWithUIWithSuccess:(UploadDebugLogsSuccess)successParam {
    OWSAssertIsOnMainThread();

    [ModalActivityIndicatorViewController
        presentFromViewController:UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts
                        canCancel:YES
                  backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
                      [self
                          uploadLogsWithSuccess:^(NSURL *url) {
                              OWSAssertIsOnMainThread();

                              if (modalActivityIndicator.wasCancelled) {
                                  return;
                              }

                              [modalActivityIndicator dismissWithCompletion:^{
                                  OWSAssertIsOnMainThread();

                                  successParam(url);
                              }];
                          }
                          failure:^(NSString *localizedErrorMessage) {
                              OWSAssertIsOnMainThread();

                              if (modalActivityIndicator.wasCancelled) {
                                  return;
                              }

                              [modalActivityIndicator dismissWithCompletion:^{
                                  OWSAssertIsOnMainThread();

                                  [Pastelog showFailureAlertWithMessage:localizedErrorMessage];
                              }];
                          }];
                  }];
}

+ (void)uploadLogsWithSuccess:(UploadDebugLogsSuccess)successParam failure:(UploadDebugLogsFailure)failureParam
{
    [[self shared] uploadLogsWithSuccess:successParam failure:failureParam];
}

- (void)uploadLogsWithSuccess:(UploadDebugLogsSuccess)successParam failure:(UploadDebugLogsFailure)failureParam {
    OWSAssertDebug(successParam);
    OWSAssertDebug(failureParam);

    // Ensure that we call the completions on the main thread.
    UploadDebugLogsSuccess success = ^(NSURL *url) {
        DispatchMainThreadSafe(^{
            successParam(url);
        });
    };
    UploadDebugLogsFailure failure = ^(NSString *localizedErrorMessage) {
        DispatchMainThreadSafe(^{
            failureParam(localizedErrorMessage);
        });
    };

    // Phase 1. Make a local copy of all of the log files.
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateFormat:@"yyyy.MM.dd hh.mm.ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate new]];
    NSString *logsName = [[dateString stringByAppendingString:@" "] stringByAppendingString:NSUUID.UUID.UUIDString];
    NSString *tempDirectory = OWSTemporaryDirectory();
    NSString *zipFilePath =
        [tempDirectory stringByAppendingPathComponent:[logsName stringByAppendingPathExtension:@"zip"]];
    NSString *zipDirPath = [tempDirectory stringByAppendingPathComponent:logsName];
    [OWSFileSystem ensureDirectoryExists:zipDirPath];

    NSArray<NSString *> *logFilePaths = DebugLogger.sharedLogger.allLogFilePaths;
    if (logFilePaths.count < 1) {
        failure(NSLocalizedString(@"DEBUG_LOG_ALERT_NO_LOGS", @"Error indicating that no debug logs could be found."));
        return;
    }

    for (NSString *logFilePath in logFilePaths) {
        NSString *copyFilePath = [zipDirPath stringByAppendingPathComponent:logFilePath.lastPathComponent];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:logFilePath toPath:copyFilePath error:&error];
        if (error) {
            failure(NSLocalizedString(
                @"DEBUG_LOG_ALERT_COULD_NOT_COPY_LOGS", @"Error indicating that the debug logs could not be copied."));
            return;
        }
        [OWSFileSystem protectFileOrFolderAtPath:copyFilePath];
    }

    // Phase 2. Zip up the log files.
    BOOL zipSuccess = [SSZipArchive createZipFileAtPath:zipFilePath
                                withContentsOfDirectory:zipDirPath
                                    keepParentDirectory:YES
                                       compressionLevel:Z_DEFAULT_COMPRESSION
                                               password:nil
                                                    AES:NO
                                        progressHandler:nil];
    if (!zipSuccess) {
        failure(NSLocalizedString(
            @"DEBUG_LOG_ALERT_COULD_NOT_PACKAGE_LOGS", @"Error indicating that the debug logs could not be packaged."));
        return;
    }

    [OWSFileSystem protectFileOrFolderAtPath:zipFilePath];
    [OWSFileSystem deleteFile:zipDirPath];

    // Phase 3. Upload the log files.

    __weak Pastelog *weakSelf = self;
    self.currentUploader = [DebugLogUploader new];
    [self.currentUploader uploadFileWithFileUrl:[NSURL fileURLWithPath:zipFilePath]
        mimeType:OWSMimeTypeApplicationZip
        success:^(DebugLogUploader *uploader, NSURL *url) {
            if (uploader != weakSelf.currentUploader) {
                // Ignore events from obsolete uploaders.
                return;
            }
            [OWSFileSystem deleteFile:zipFilePath];
            success(url);
        }
        failure:^(DebugLogUploader *uploader, NSError *error) {
            if (uploader != weakSelf.currentUploader) {
                // Ignore events from obsolete uploaders.
                return;
            }
            [OWSFileSystem deleteFile:zipFilePath];
            failure(NSLocalizedString(
                @"DEBUG_LOG_ALERT_ERROR_UPLOADING_LOG", @"Error indicating that a debug log could not be uploaded."));
        }];
}

+ (void)showFailureAlertWithMessage:(NSString *)message
{
    ActionSheetController *alert = [[ActionSheetController alloc] initWithTitle:nil message:message];
    [alert addAction:[[ActionSheetAction alloc] initWithTitle:CommonStrings.okButton
                                      accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"ok")
                                                        style:ActionSheetActionStyleDefault
                                                      handler:nil]];
    UIViewController *presentingViewController = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
    [presentingViewController presentActionSheet:alert];
}

- (void)prepareRedirection:(NSURL *)url completion:(SubmitDebugLogsCompletion)completion
{
    OWSAssertDebug(completion);

    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    [pb setString:url.absoluteString];

    ActionSheetController *alert =
        [[ActionSheetController alloc] initWithTitle:NSLocalizedString(@"DEBUG_LOG_GITHUB_ISSUE_ALERT_TITLE",
                                                         @"Title of the alert before redirecting to GitHub Issues.")
                                             message:NSLocalizedString(@"DEBUG_LOG_GITHUB_ISSUE_ALERT_MESSAGE",
                                                         @"Message of the alert before redirecting to GitHub Issues.")];
    [alert
        addAction:[[ActionSheetAction alloc]
                                initWithTitle:CommonStrings.okButton
                      accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"ok")
                                        style:ActionSheetActionStyleDefault
                                      handler:^(ActionSheetAction *action) {
                                          [UIApplication.sharedApplication
                                              openURL:[NSURL
                                                          URLWithString:[[NSBundle mainBundle]
                                                                            objectForInfoDictionaryKey:@"LOGS_URL"]]];

                                          completion();
                                      }]];
    UIViewController *presentingViewController = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
    [presentingViewController presentActionSheet:alert];
}

- (void)sendToSelf:(NSURL *)url
{
    if (![self.tsAccountManager isRegistered]) {
        return;
    }
    SignalServiceAddress *recipientAddress = TSAccountManager.localAddress;

    DispatchMainThreadSafe(^{
        __block TSThread *thread = nil;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            thread = [TSContactThread getOrCreateThreadWithContactAddress:recipientAddress transaction:transaction];
        });
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
            [ThreadUtil enqueueMessageWithBody:[[MessageBody alloc] initWithText:url.absoluteString
                                                                          ranges:MessageBodyRanges.empty]
                                        thread:thread
                              quotedReplyModel:nil
                              linkPreviewDraft:nil
                                   transaction:transaction];
        }];
    });

    // Also copy to pasteboard.
    [[UIPasteboard generalPasteboard] setString:url.absoluteString];
}

@end

NS_ASSUME_NONNULL_END
