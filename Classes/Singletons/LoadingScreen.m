//
//  LoadingScreen.m
//  iSub
//
//  Created by Benjamin Baron on 1/10/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

#import "LoadingScreen.h"
#import "iSub-Swift.h"
#import <MBProgressHUD/MBProgressHUD.h>

#define n2N(value) (value ? value : [NSNull null])
#define N2n(value) (value == [NSNull null] ? nil : value)

@implementation LoadingScreen

static BOOL isLoadingScreenShowing = NO;
static __strong MBProgressHUD *hud;

static NSString * const kViewKey = @"view";
static NSString * const kMessageKey = @"message";
static NSString * const kSenderKey = @"sender";
static NSTimeInterval const kDelay = .5;

+ (void)showLoadingScreenOnMainWindowNotification:(NSNotification *)notification
{
    [self showLoadingScreenOnMainWindowWithMessage:notification.userInfo[@"message"]];
}

+ (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message
{
    [self showLoadingScreen:AppDelegate.si.window withMessage:message];
}

+ (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message
{
    if (isLoadingScreenShowing)
    {
        hud.label.text = message ? message : hud.label.text;
        return;
    }
    
    NSDictionary *options = @{ kViewKey: view, kMessageKey: n2N(message) };
    [self performSelector:@selector(_showLoadingScreenWithOptions:) withObject:options afterDelay:kDelay];
}

+ (void)_showLoadingScreenWithOptions:(NSDictionary *)options
{
    UIView *view = options[kViewKey];
    NSString *message = N2n(options[kMessageKey]);
    
    isLoadingScreenShowing = YES;
    
    hud = [[MBProgressHUD alloc] initWithView:view];
    [AppDelegate.si.window addSubview:hud];
    hud.delegate = (id)self;
    hud.label.text = message ? message : @"Loading";
    [hud showAnimated:YES];
}

+ (void)showAlbumLoadingScreenOnMainWindowNotification:(NSNotification *)notification
{
    [self showAlbumLoadingScreenOnMainWindowWithSender:notification.userInfo[@"sender"]];
}

+ (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender
{
    [self showAlbumLoadingScreen:AppDelegate.si.window sender:sender];
}

+ (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender
{
    if (isLoadingScreenShowing)
        return;
    
    NSDictionary *options = @{ kViewKey: view, kSenderKey: sender };
    [self performSelector:@selector(_showAlbumLoadingScreenWithOptions:) withObject:options afterDelay:kDelay];
}

+ (void)_showAlbumLoadingScreenWithOptions:(NSDictionary *)options
{
    //UIView *view = options[kViewKey];
    id sender = options[kSenderKey];
    
    isLoadingScreenShowing = YES;
    
    hud = [[MBProgressHUD alloc] initWithView:AppDelegate.si.window];
    hud.userInteractionEnabled = YES;
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.bounds = CGRectMake(0, 0, 1024, 1024);
    cancelButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cancelButton addTarget:sender action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [hud addSubview:cancelButton];
    
    [AppDelegate.si.window addSubview:hud];
    hud.delegate = (id)self;
    hud.label.text = @"Loading";
    hud.detailsLabel.text = @"tap to cancel";
    [hud showAnimated:YES];
}

+ (void)hideLoadingScreen
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if (!isLoadingScreenShowing)
        return;
    
    isLoadingScreenShowing = NO;
    
    [hud hideAnimated:YES];
}

+ (void)hudWasHidden:(MBProgressHUD *)hud
{
    // Remove HUD from screen when the HUD was hidden
    [hud removeFromSuperview];
    hud = nil;
}

@end
