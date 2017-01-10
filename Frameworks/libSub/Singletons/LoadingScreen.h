//
//  LoadingScreen.h
//  iSub
//
//  Created by Benjamin Baron on 1/10/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LoadingScreen : NSObject

+ (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message;
+ (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message;
+ (void)showAlbumLoadingScreenOnMainWindowWithSender:(id)sender;
+ (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
+ (void)hideLoadingScreen;

@end
