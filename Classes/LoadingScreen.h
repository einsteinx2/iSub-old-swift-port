//
//  LoadingScreen.h
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface LoadingScreen : UIViewController
{
	IBOutlet UIButton *inputBlocker;
	IBOutlet UIImageView *loadingScreenRectangle;
	IBOutlet UILabel *loadingLabel;
	IBOutlet UILabel *loadingTitle1;
	IBOutlet UILabel *loadingMessage1;
	IBOutlet UILabel *loadingTitle2;
	IBOutlet UILabel *loadingMessage2;
	IBOutlet UIActivityIndicatorView *activityIndicator;
}

@property (retain) UIButton *inputBlocker;
@property (retain) UIImageView *loadingScreenRectangle;
@property (retain) UILabel *loadingLabel;
@property (retain) UILabel *loadingTitle1;
@property (retain) UILabel *loadingMessage1;
@property (retain) UILabel *loadingTitle2;
@property (retain) UILabel *loadingMessage2;
@property (retain) UIActivityIndicatorView *activityIndicator;


- (id)initOnView:(UIView *)view withMessage:(NSArray *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow; 
//- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow;
- (void)setAllMessagesText:(NSArray *)messages;
- (void)setMessage1Text:(NSString *)message;
- (void)setMessage2Text:(NSString *)message;
- (void)hide;

- (IBAction)inputBlockerAction:(id)sender;

@end
