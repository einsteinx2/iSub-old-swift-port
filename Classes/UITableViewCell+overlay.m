//
//  UITableViewCell-overlay.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UITableViewCell+overlay.h"
#import "CellOverlay.h"

@implementation UITableViewCell (overlay)

- (BOOL)isOverlayShowing
{
	return NO;
}

- (void)showOverlay
{
	return;
}

- (void)hideOverlay
{
	return;
}

- (void)blockerAction
{
	return;
}

- (void)downloadAction
{
	return;
}

- (void)queueAction
{
	return;
}

- (BOOL)fingerIsMovingVertically
{
	return YES;
}

- (void)toggleDelete
{
	return;
}

- (void)scrollLabels
{
	return;
}

- (CellOverlay *)overlayView
{
	return nil;
}

@end
