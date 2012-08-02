//
//  EX2NotificationBar.h
//
//  Created by Ben Baron on 4/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

#define EX2NotificationBarWillShow @"EX2NotificationBarWillShow"
#define EX2NotificationBarWillHide @"EX2NotificationBarWillHide"
#define EX2NotificationBarDidShow @"EX2NotificationBarDidShow"
#define EX2NotificationBarDidHide @"EX2NotificationBarDidHide"

typedef enum 
{
	EX2NotificationBarPositionTop,
	EX2NotificationBarPositionBottom
} 
EX2NotificationBarPosition;

@interface EX2NotificationBar : UIViewController

// View to place notification bar content. May add any custom subviews, etc. 
// Think of like UITableViewCell contentView.
@property (unsafe_unretained, nonatomic, readonly) IBOutlet UIView *notificationBarContent;

// The notification bar area. Contains the content view and shadows. Always add
// subviews to the content view, NOT to this view, or they will be placed
// above the shadows unless you specifically move them backwards in the hierarchy
@property (unsafe_unretained, nonatomic, readonly) IBOutlet UIView *notificationBar;

// The view that contains the main view. This is where you would add your UITabBarController,
// UINavigationController, etc.
@property (unsafe_unretained, nonatomic, readonly) IBOutlet UIView *mainViewHolder;

// YES when the notificationBar is visible
@property (nonatomic, readonly) BOOL isNotificationBarShowing;

// This can be changed during runtime, but only when isNotificationBarShowing == NO
@property EX2NotificationBarPosition position;

// This is a reference to whatever controller manages the view you placed in mainViewHolder
@property (nonatomic, strong) IBOutlet UIViewController *mainViewController;

// The height of the content area when shown
@property CGFloat notificationBarHeight;

- (id)initWithPosition:(EX2NotificationBarPosition)thePosition;

// Show the notificationBar temporarily, then automatically dismiss
- (void)showAndHideForDuration:(NSTimeInterval)duration;
- (void)showAndHide;

// Show the notificationBar indefinitely
- (void)show;
- (void)show:(void (^)(void))completionBlock;

// Hide the notificationBar
- (void)hide;
- (void)hide:(void (^)(void))completionBlock;

@end
