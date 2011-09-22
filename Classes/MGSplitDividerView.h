//
//  MGSplitDividerView.h
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class MGSplitViewController;
@interface MGSplitDividerView : UIView {
	MGSplitViewController *splitViewController;
	BOOL allowsDragging;
}

@property (nonatomic, assign) MGSplitViewController *splitViewController; // weak ref.
@property (nonatomic, assign) BOOL allowsDragging;

- (void)drawGripThumbInRect:(CGRect)rect;

@end
