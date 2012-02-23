//
//  UIView+Tools.h
//  iSub
//
//  Created by Ben Baron on 12/22/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface UIView (Tools) 

@property (nonatomic) CGFloat left;
@property (nonatomic) CGFloat top;
@property (nonatomic) CGFloat right;
@property (nonatomic) CGFloat bottom;

@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) CGPoint origin;

@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGSize size;

@property (nonatomic, readonly) UIViewController *viewController;

- (void)addLeftShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha;
- (void)addLeftShadow;
- (void)addRightShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha;
- (void)addRightShadow;
+ (CAGradientLayer *)verticalShadowWithAlpha:(CGFloat)shadowAlpha inverse:(BOOL)inverse;

- (void)addBottomShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha;
- (void)addBottomShadow;
- (void)addTopShadowWithWidth:(CGFloat)shadowWidth alpha:(CGFloat)shadowAlpha;
- (void)addTopShadow;
+ (CAGradientLayer *)horizontalShadowWithAlpha:(CGFloat)shadowAlpha inverse:(BOOL)inverse;

@end
