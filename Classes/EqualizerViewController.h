//
//  EqualizerViewController.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NWPickerField.h"

@class EqualizerView, EqualizerPointView, BassParamEqValue;
@interface EqualizerViewController : UIViewController <NWPickerFieldDelegate>

@property (nonatomic, retain) IBOutlet UIButton *toggleButton;
//@property (nonatomic, retain) IBOutlet UIImageView *drawImage;
@property (nonatomic, retain) IBOutlet EqualizerView *equalizerView;
@property (nonatomic, retain) NSMutableArray *equalizerPointViews;

//@property (nonatomic, retain) NSTimer *drawTimer;

@property (nonatomic, assign) EqualizerPointView *selectedView;

//- (BOOL)isTouchingEqView:(UITouch *)touch;

//- (CGPoint)centerForBassEqValue:(BassParamEqValue *)value;

- (IBAction)dismiss:(id)sender;
- (IBAction)type:(id)sender;
- (IBAction)toggle:(id)sender;
- (void)updateToggleButton;

- (void)createEqViews;
- (void)removeEqViews;
//- (void)setupPalette;
//- (void)createBitmapToDraw;

@end
