//
//  UIView-tools.h
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface UIView (tools) 

@property CGFloat x;
@property CGFloat y;
@property CGPoint origin;

@property CGFloat width;
@property CGFloat height;
@property CGSize size;

@property (readonly) UIViewController *viewController;

@end
