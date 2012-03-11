//
//  EqualizerViewController.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NWPickerField.h"
#import "DDSocialDialog.h"

@class EqualizerView, EqualizerPointView, EqualizerPathView, BassParamEqValue, BassEffectDAO, NWPickerField, SnappySlider;
@interface EqualizerViewController : UIViewController <NWPickerFieldDelegate, DDSocialDialogDelegate, UITableViewDelegate, UITableViewDataSource>
{
	UIView *overlay;
	UIButton *dismissButton;
}
@property (retain) IBOutlet UIView *controlsContainer;

@property BOOL isPresetPickerShowing;
@property (retain) IBOutlet NWPickerField *presetPicker;

@property (retain) IBOutlet UIButton *toggleButton;
//@property (retain) IBOutlet UIImageView *drawImage;
@property (retain) IBOutlet EqualizerPathView *equalizerPath;
@property (retain) IBOutlet EqualizerView *equalizerView;
@property (retain) NSMutableArray *equalizerPointViews;

@property (retain) IBOutlet SnappySlider *gainSlider;
@property (retain) IBOutlet UILabel *gainBoostAmountLabel;
@property (retain) IBOutlet UILabel *gainBoostLabel;
@property CGFloat lastGainValue;

@property (retain) BassEffectDAO *effectDAO;

//@property (retain) NSTimer *drawTimer;

@property (assign) EqualizerPointView *selectedView;

@property (retain) UIButton *deletePresetButton;
@property (retain) UIButton *savePresetButton;
@property BOOL isSavePresetButtonShowing;
@property BOOL isDeletePresetButtonShowing;
@property (retain) UITextField *presetNameTextField;

@property (retain) DDSocialDialog *saveDialog;


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

- (void)promptForSavePresetName;
- (void)hideSavePresetButton:(BOOL)animated;
- (void)showSavePresetButton:(BOOL)animated;
- (void)hideDeletePresetButton:(BOOL)animated;
- (void)showDeletePresetButton:(BOOL)animated;
- (void)saveTempCustomPreset;

- (IBAction)movedGainSlider:(id)sender;

@end
