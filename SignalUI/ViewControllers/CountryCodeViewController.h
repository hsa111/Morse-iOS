//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import <SignalUI/OWSTableViewController.h>

NS_ASSUME_NONNULL_BEGIN

@class CountryCodeViewController;

@protocol CountryCodeViewControllerDelegate <NSObject>

- (void)countryCodeViewController:(CountryCodeViewController *)vc
             didSelectCountryCode:(NSString *)countryCode
                      countryName:(NSString *)countryName
                      callingCode:(NSString *)callingCode;

@end

#pragma mark -

@interface CountryCodeViewController : OWSTableViewController

@property (nonatomic, weak) id<CountryCodeViewControllerDelegate> countryCodeDelegate;

@property (nonatomic) BOOL isPresentedInNavigationController;

@property (nonatomic) UIInterfaceOrientationMask interfaceOrientationMask;

@end

NS_ASSUME_NONNULL_END
