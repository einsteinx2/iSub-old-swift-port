//
//  CustomUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 12/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"
#import "ViewObjectsSingleton.h"
#import "CellOverlay.h"
#import "NSNotificationCenter+MainThread.h"

@implementation CustomUITableViewCell
@synthesize isOverlayShowing, overlayView, isIndexShowing, indexPath, isSearching, deleteToggleImage, isDelete;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) 
	{
        isIndexShowing = NO;
		isOverlayShowing = NO;
		overlayView = nil;
		indexPath = nil;
		isSearching = NO;
		isDelete = NO;
		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		[deleteToggleImage release];
		deleteToggleImage.hidden = YES;
    }
    return self;
}

- (void)dealloc
{
	[overlayView release]; overlayView = nil;
	[super dealloc];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	if ([ViewObjectsSingleton sharedInstance].isEditing)
		[super setEditing:editing animated:animated]; 
}

- (void)showOverlay
{
	if (!isOverlayShowing)
	{
		if (!overlayView)
		{
			self.overlayView = [CellOverlay cellOverlayWithTableCell:self];
			[self.contentView addSubview:overlayView];
		}
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		overlayView.alpha = 1.0;
		[UIView commitAnimations];		
		
		isOverlayShowing = YES;
	}
}

- (void)hideOverlay
{
	if (overlayView)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		overlayView.alpha = 0.0;
		[UIView commitAnimations];
		
		isOverlayShowing = NO;
	}
}

- (void)downloadAction
{
	return;
}

- (void)queueAction
{
	return;
}

- (void)blockerAction
{
	[self hideOverlay];
}

- (void)scrollLabels
{
	return;
}

- (void)toggleDelete
{
	if (isDelete)
	{
		[[ViewObjectsSingleton sharedInstance].multiDeleteList removeObject:[NSNumber numberWithInt:indexPath.row]];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
		deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
	else
	{
		[[ViewObjectsSingleton sharedInstance].multiDeleteList addObject:[NSNumber numberWithInt:indexPath.row]];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
		deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	isDelete = !isDelete;
}

@end
