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

@property (nonatomic, retain) UIButton *inputBlocker;
@property (nonatomic, retain) UIImageView *loadingScreenRectangle;
@property (nonatomic, retain) UILabel *loadingLabel;
@property (nonatomic, retain) UILabel *loadingTitle1;
@property (nonatomic, retain) UILabel *loadingMessage1;
@property (nonatomic, retain) UILabel *loadingTitle2;
@property (nonatomic, retain) UILabel *loadingMessage2;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;


- (id)initOnView:(UIView *)view withMessage:(NSArray *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow; 
//- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow;
- (void)setAllMessagesText:(NSArray *)messages;
- (void)setMessage1Text:(NSString *)message;
- (void)setMessage2Text:(NSString *)message;
- (void)hide;

- (IBAction)inputBlockerAction:(id)sender;

@end
