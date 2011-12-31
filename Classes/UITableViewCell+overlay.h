//
//  UITableViewCell-overlay.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CellOverlay;

@interface UITableViewCell (overlay) 

- (BOOL)isOverlayShowing;
- (void)showOverlay;
- (void)hideOverlay;
- (void)blockerAction;
- (void)downloadAction;
- (void)queueAction;
- (BOOL)fingerIsMovingVertically;
- (void)toggleDelete;
- (void)scrollLabels;
- (CellOverlay *)overlayView;

@end
