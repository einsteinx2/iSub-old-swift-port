//
//  UITableViewCell-overlay.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface UITableViewCell (overlay) 

- (BOOL)isOverlayShowing;
- (void)showOverlay;
- (void)hideOverlay;
- (void)blockerAction;
- (void)downloadAction;
- (void)queueAction;
- (BOOL)fingerIsMovingVertically;
- (void)toggleDelete;

@end
