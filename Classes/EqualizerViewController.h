//
//  EqualizerViewController.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NWPickerField.h"
#import "DDSocialDialog.h"

@class EqualizerView, EqualizerPointView, BassParamEqValue, BassEffectDAO, NWPickerField;
@interface EqualizerViewController : UIViewController <NWPickerFieldDelegate, DDSocialDialogDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, retain) IBOutlet NWPickerField *presetPicker;

@property (nonatomic, retain) IBOutlet UIButton *toggleButton;
//@property (nonatomic, retain) IBOutlet UIImageView *drawImage;
@property (nonatomic, retain) IBOutlet EqualizerView *equalizerView;
@property (nonatomic, retain) NSMutableArray *equalizerPointViews;

@property (nonatomic, retain) IBOutlet UISlider *gainSlider;

@property (nonatomic, retain) BassEffectDAO *effectDAO;

//@property (nonatomic, retain) NSTimer *drawTimer;

@property (nonatomic, assign) EqualizerPointView *selectedView;

@property (nonatomic, retain) UIButton *deletePresetButton;
@property (nonatomic, retain) UIButton *savePresetButton;
@property BOOL isSavePresetButtonShowing;
@property BOOL isDeletePresetButtonShowing;
@property (nonatomic, retain) UITextField *presetNameTextField;

@property (nonatomic, retain) DDSocialDialog *saveDialog;


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
