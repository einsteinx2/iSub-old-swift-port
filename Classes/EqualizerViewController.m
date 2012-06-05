//
//  EqualizerViewController.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "EqualizerViewController.h"
#import "EqualizerView.h"
#import "EqualizerPointView.h"
#import "AudioEngine.h"
#import "BassParamEqValue.h"
#import "BassEffectDAO.h"
#import "SavedSettings.h"
#import "EqualizerPathView.h"
#import "NSArray+FirstObject.h"
#import "UIApplication+StatusBar.h"
#import "SnappySlider.h"
#import "NWPickerView.h"
#import "NSNotificationCenter+MainThread.h"
#import "GCDWrapper.h"

@implementation EqualizerViewController
@synthesize equalizerView, equalizerPointViews, selectedView, toggleButton, effectDAO, presetPicker, deletePresetButton, savePresetButton, isSavePresetButtonShowing, isDeletePresetButtonShowing, presetNameTextField, saveDialog, gainSlider, equalizerPath, gainBoostLabel, isPresetPickerShowing, controlsContainer, gainBoostAmountLabel, lastGainValue, wasVisualizerOffBeforeRotation, swipeDetectorLeft, swipeDetectorRight, landscapeButtonsHolder, overlay, dismissButton;//, hidePickerTimer; //drawTimer;

#define hidePickerTimer @"EqualizerViewController hide picker timer"

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if (settingsS.isRotationLockEnabled && interfaceOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
	return !self.isPresetPickerShowing;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[UIView beginAnimations:@"rotate" context:nil];
	[UIView setAnimationDuration:duration];
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		[UIApplication setStatusBarHidden:NO withAnimation:YES];
		equalizerPath.alpha = 1.0;
		for (EqualizerPointView *view in equalizerPointViews)
		{
			view.alpha = 1.0;
		}
		
		UIDevice *device = [UIDevice currentDevice];
		if (device.batteryState != UIDeviceBatteryStateCharging && device.batteryState != UIDeviceBatteryStateFull) 
		{
			if (settingsS.isScreenSleepEnabled)
				[UIApplication sharedApplication].idleTimerDisabled = NO;
		}
		
		if (!IS_IPAD())
		{
			self.controlsContainer.alpha = 1.0;
			self.controlsContainer.userInteractionEnabled = YES;
			
			if (self.wasVisualizerOffBeforeRotation)
			{
				[equalizerView changeType:ISMSBassVisualType_none];
			}
			
			/*if (self.landscapeButtonsHolder.superview)
				[self hideLandscapeVisualizerButtons];*/
		}
	}
	else
	{
		[UIApplication setStatusBarHidden:YES withAnimation:YES];
		equalizerPath.alpha = 0.0;
		for (EqualizerPointView *view in equalizerPointViews)
		{
			view.alpha = 0.0;
		}
		
		[UIApplication sharedApplication].idleTimerDisabled = YES;
		
		if (!IS_IPAD())
		{
			self.controlsContainer.alpha = 0.0;
			self.controlsContainer.userInteractionEnabled = NO;
			
			self.wasVisualizerOffBeforeRotation = (equalizerView.visualType == ISMSBassVisualType_none);
			if (self.wasVisualizerOffBeforeRotation)
			{
				[equalizerView nextType];
			}
		}
	}
	[UIView commitAnimations];
	
	NSUInteger count = [self.navigationController.viewControllers count];
	UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
	[backViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	/*if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
	{
		[self removeEqViews];
	}
	else
	{
		[self createEqViews];
	}*/
	
	NSUInteger count = [self.navigationController.viewControllers count];
	UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
	[backViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)dismissPicker
{
	[presetPicker resignFirstResponder];
	//self.hidePickerTimer = nil;
	[GCDWrapper cancelTimerBlockWithName:hidePickerTimer];
}

- (void)createOverlay
{
	overlay = [[UIView alloc] init];
	//searchOverlay.frame = CGRectMake(0, 74, 480, 480);
	overlay.frame = self.view.frame;
	overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	overlay.alpha = 0.0;
	[self.view insertSubview:overlay belowSubview:self.controlsContainer];
	
	dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[dismissButton addTarget:self action:@selector(dismissPicker) forControlEvents:UIControlEventTouchUpInside];
	dismissButton.frame = self.view.bounds;
	dismissButton.enabled = NO;
	[overlay addSubview:dismissButton];

	// Animate the search overlay on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	overlay.alpha = 1;
	dismissButton.enabled = YES;
	[UIView commitAnimations];
}

- (void)hideOverlay
{
	if (overlay)
	{
		// Animate the search overlay off screen
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.3];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(removeOverlay)];
		overlay.alpha = 0;
		dismissButton.enabled = NO;
		[UIView commitAnimations];
	}
}

- (void)removeOverlay
{
	[overlay removeFromSuperview];
	overlay = nil;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:presetPicker];
	[GCDWrapper cancelTimerBlockWithName:hidePickerTimer];
	//[hidePickerTimer release]; hidePickerTimer = nil;
	
	
}

#pragma mark - View lifecycle

/*- (void)showLandscapeVisualizerButtons
{
	if (self.landscapeButtonsHolder.superview)
		return;
	
	self.landscapeButtonsHolder.alpha = 0.0;
	[self.view addSubview:self.landscapeButtonsHolder];
	[UIView animateWithDuration:0.3 animations:^{
		self.landscapeButtonsHolder.alpha = 1.0;
	}completion: ^(BOOL finished){
		[self performSelector:@selector(hideLandscapeVisualizerButtons) withObject:nil afterDelay:5.0];
	}];
}

- (void)hideLandscapeVisualizerButtons
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideLandscapeVisualizerButtons) object:nil];
	
	[UIView animateWithDuration:0.3  
	animations: ^{
		self.landscapeButtonsHolder.alpha = 0.0;
	}				 
	completion: ^(BOOL finished){
		[self.landscapeButtonsHolder removeFromSuperview];
	}];
}*/

- (void)pickerWillShown
{
	controlsContainer.y -= 60;
	controlsContainer.height += 60;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	for (UIView *subview in controlsContainer.subviews)
	{
		if (![subview isKindOfClass:[NWPickerView class]])
			subview.hidden = YES;
	}
	[UIView commitAnimations];
	
	[self createOverlay];
	self.isPresetPickerShowing = YES;
	
	/*// Dismiss the picker view after a few seconds
	[NSObject gcdCancelTimerBlockWithName:hidePickerTimer];
	[self gcdTimerPerformBlockInMainQueue:^{
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hidePresetPicker"];
	} afterDelay:5.0 withName:hidePickerTimer];*/
}

- (void)pickerWillHide
{
	[GCDWrapper cancelTimerBlockWithName:hidePickerTimer];
	
	controlsContainer.y += 60;
	controlsContainer.height -= 60;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	for (UIView *subview in controlsContainer.subviews)
	{
		subview.hidden = NO;
	}
	[UIView commitAnimations];
	
	[self hideOverlay];
	self.isPresetPickerShowing = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	/*CGRect frame;
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && !IS_IPAD())
	{
		frame = CGRectMake(0, 0, 480, 320);
	}
	else
	{
		frame = CGRectMake(0, 0, 320, 320);
	}
	equalizerView = [[EqualizerView alloc] initWithFrame:frame];
	equalizerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:equalizerView];*/
		
	effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];

	//DLog(@"effectDAO.selectedPresetIndex: %i", effectDAO.selectedPresetIndex);
	[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:NO];
	
	[self updateToggleButton];
	
	[self.equalizerView startEqDisplay];
	
	isSavePresetButtonShowing = NO;
	self.savePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	CGRect f = presetPicker.frame;
	savePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 60., f.origin.y, 60., 30.);
	[savePresetButton setTitle:@"Save" forState:UIControlStateNormal];
	[savePresetButton addTarget:self action:@selector(promptToSaveCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	savePresetButton.alpha = 0.;
	savePresetButton.enabled = NO;
	[self.controlsContainer addSubview:savePresetButton];
	
	self.deletePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	deletePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 60., f.origin.y, 60., 30.);
	[deletePresetButton setTitle:@"Delete" forState:UIControlStateNormal];
	[deletePresetButton addTarget:self action:@selector(promptToDeleteCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	deletePresetButton.alpha = 0.;
	deletePresetButton.enabled = NO;
	[self.controlsContainer addSubview:deletePresetButton];
	
	if (effectDAO.selectedPresetId == BassEffectTempCustomPresetId)
	{
		[self showSavePresetButton:NO];
	}
	else if (![[effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue])
	{
		[self showDeletePresetButton:NO];
	}
	
	NSArray *detents = [NSArray arrayWithObjects:[NSNumber numberWithFloat:1.], [NSNumber numberWithFloat:2.], [NSNumber numberWithFloat:3.], nil];
	self.gainSlider.snapDistance = .13;
	self.gainSlider.detents = detents;
	self.gainSlider.value = settingsS.gainMultiplier;
	self.lastGainValue = self.gainSlider.value;
	self.gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", self.gainSlider.value];
	
	if (IS_IPAD())
	{
		self.gainSlider.y += 7;
		self.gainBoostLabel.y += 7;
		self.gainBoostAmountLabel.y += 7;
		self.savePresetButton.y -= 10;
		self.deletePresetButton.y -= 10;
	}
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && !IS_IPAD())
	{
		self.controlsContainer.alpha = 0.0;
		self.controlsContainer.userInteractionEnabled = NO;
		
		self.wasVisualizerOffBeforeRotation = (equalizerView.visualType == ISMSBassVisualType_none);
		if (self.wasVisualizerOffBeforeRotation)
		{
			[equalizerView nextType];
		}
	}
	
	overlay = nil;
	
	swipeDetectorLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft)];
	swipeDetectorLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	[equalizerView addGestureRecognizer:swipeDetectorLeft];

	swipeDetectorRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight)];
	swipeDetectorRight.direction = UISwipeGestureRecognizerDirectionRight;
	[equalizerView addGestureRecognizer:swipeDetectorRight];
	
	[FlurryAnalytics logEvent:@"Equalizer"];
}

- (void)swipeLeft
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		[equalizerView nextType];
}

- (void)swipeRight
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		[equalizerView prevType];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
	[self createEqViews];
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		[UIApplication setStatusBarHidden:YES withAnimation:NO];
		equalizerPath.alpha = 0.0;
		
		for (EqualizerPointView *view in equalizerPointViews)
		{
			view.alpha = 0.0;
		}
	}

	self.navigationController.navigationBar.hidden = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createEqViews) name:ISMSNotification_BassEffectPresetLoaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pickerWillShown) name:UIPickerViewWillShownNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pickerWillHide) name:UIPickerViewWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:presetPicker selector:@selector(resignFirstResponder) name:@"hidePresetPicker" object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
	if (settingsS.isShouldShowEQViewInstructions)
	{
		NSString *title = [NSString stringWithFormat:@"Instructions"];
		UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:title message:@"Double tap to create a new EQ point and double tap any existing EQ points to remove them." delegate:self cancelButtonTitle:@"Don't Show Again" otherButtonTitles:@"OK", nil];
		myAlertView.tag = 3;
		[myAlertView show];
	}
}

- (void)createAndDrawEqualizerPath
{	
	// Sort the points
	NSUInteger length = [equalizerPointViews count];
	CGPoint *points = malloc(sizeof(CGPoint) * [equalizerPointViews count]);
	//for (EqualizerPointView *eqView in equalizerPointViews)
	for (int i = 0; i < length; i++)
	{
		EqualizerPointView *eqView = [equalizerPointViews objectAtIndex:i];
		points[i] = eqView.center;
	}
	//equalizerPath.points = points;
	//equalizerPath.length = length;
	
	[equalizerPath setPoints:points length:length];
	
	/*NSMutableArray *points = [NSMutableArray arrayWithCapacity:[equalizerPointViews count]];
	for (EqualizerPointView *eqView in equalizerPointViews)
	{
		[points addObject:[NSValue valueWithCGPoint:eqView.center]];
	}
	equalizerPath.points = points;*/

	// Draw the curve
	//[equalizerPath setNeedsDisplay];
}

- (void)createEqViews
{
	[self removeEqViews];
		
	equalizerPointViews = [[NSMutableArray alloc] initWithCapacity:[[audioEngineS equalizerValues] count]];
	for (BassParamEqValue *value in audioEngineS.equalizerValues)
	{
		//DLog(@"eq handle: %i", value.handle);
		EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithEqValue:value parentSize:self.equalizerView.frame.size];
		[equalizerPointViews addObject:eqView];
		
		[self.view insertSubview:eqView aboveSubview:equalizerPath];
		//if (overlay)
		//	[self.view insertSubview:eqView belowSubview:overlay];
		//else
		//	[self.view insertSubview:eqView belowSubview:self.controlsContainer];
	}
	//DLog(@"equalizerValues: %@", audioEngineS.equalizerValues);
	//DLog(@"equalizerViews: %@", equalizerPointViews);

	//Draw the path
	[self createAndDrawEqualizerPath];
}

- (void)removeEqViews
{
	for (EqualizerPointView *eqView in equalizerPointViews)
	{
		[eqView removeFromSuperview];
	}
	 equalizerPointViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[GCDWrapper cancelTimerBlockWithName:hidePickerTimer];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassEffectPresetLoaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIPickerViewWillShownNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIPickerViewWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hidePresetPicker" object:nil];
	
	[self removeEqViews];
	
	[self.equalizerView stopEqDisplay];
	
	[equalizerView removeFromSuperview];
	 equalizerView = nil;
	
	[audioEngineS stopReadingEqData];
	
	self.navigationController.navigationBar.hidden = NO;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)hideSavePresetButton:(BOOL)animated
{	
	isSavePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	presetPicker.width += 65.;
	savePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	savePresetButton.enabled = NO;
}

- (void)showSavePresetButton:(BOOL)animated
{
	isSavePresetButtonShowing = YES;
	
	savePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	presetPicker.width -= 65.;
	savePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (void)hideDeletePresetButton:(BOOL)animated
{	
	isDeletePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	presetPicker.width += 65.;
	deletePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	deletePresetButton.enabled = NO;
}

- (void)showDeletePresetButton:(BOOL)animated
{
	isDeletePresetButtonShowing = YES;
	
	deletePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	presetPicker.width -= 65.;
	deletePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (NSArray *)serializedEqPoints
{
	NSMutableArray *points = [NSMutableArray arrayWithCapacity:0];
	for (EqualizerPointView *pointView in equalizerPointViews)
	{
		[points addObject:NSStringFromCGPoint(pointView.position)];
	}
	return [NSArray arrayWithArray:points];
}

- (void)saveTempCustomPreset
{
	[effectDAO saveTempCustomPreset:[self serializedEqPoints]];
	
	[presetPicker reloadAllComponents];
	[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:NO];
}

- (void)promptToDeleteCustomPreset
{
	NSString *title = [NSString stringWithFormat:@"\"%@\"", [effectDAO.selectedPreset objectForKey:@"name"]];
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:title message:@"Are you sure you want to delete this preset?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
	myAlertView.tag = 1;
	[myAlertView show];
}

- (void)promptToSaveCustomPreset
{
	NSUInteger count = [effectDAO.userPresets count];
	if ([effectDAO.userPresets objectForKey:[[NSNumber numberWithInt:BassEffectTempCustomPresetId] stringValue]])
		count--;
	
	if (count > 0)
	{
		self.saveDialog = [[DDSocialDialog alloc] initWithFrame:CGRectMake(0., 0., 300., 300.) theme:DDSocialDialogThemeISub];
		saveDialog.dialogDelegate = self;
		saveDialog.titleLabel.text = @"Choose Preset To Save";
		UITableView *saveTable = [[UITableView alloc] initWithFrame:saveDialog.contentView.frame style:UITableViewStylePlain];
		saveTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		saveTable.dataSource = self;
		saveTable.delegate = self;
		[saveDialog.contentView addSubview:saveTable];
		[saveDialog show];
	}
	else
	{
		[self promptForSavePresetName];
	}
}

- (void)promptForSavePresetName
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"New Preset Name:" message:@"      \n      " delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
	self.presetNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 24.0)];
	self.presetNameTextField.layer.cornerRadius = 3.;
	[self.presetNameTextField setBackgroundColor:[UIColor whiteColor]];
	[myAlertView addSubview:self.presetNameTextField];
	if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndexSafe:0] isEqualToString:@"3"])
	{
		CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
		[myAlertView setTransform:myTransform];
	}
	myAlertView.tag = 2;
	[myAlertView show];
	[self.presetNameTextField becomeFirstResponder];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		// Delete the preset
		if (buttonIndex)
		{
			[effectDAO deleteCustomPresetForId:effectDAO.selectedPresetId];
			[presetPicker reloadAllComponents];
			[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
		}
	}
	else if (alertView.tag == 2)
	{
		// Save the preset
		if (buttonIndex)
		{
			//DLog(@"Preset name: %@", presetNameTextField.text);
			[effectDAO saveCustomPreset:[self serializedEqPoints] name:presetNameTextField.text];
			[effectDAO deleteTempCustomPreset];
			[presetPicker reloadAllComponents];
			[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
		}
	}
	else if (alertView.tag == 3)
	{
		if (buttonIndex == 0)
		{
			settingsS.isShouldShowEQViewInstructions = NO;
		}
	}
}

- (IBAction)movedGainSlider:(id)sender
{
	CGFloat gainValue = self.gainSlider.value;
	CGFloat minValue = self.gainSlider.minimumValue;
	CGFloat maxValue = self.gainSlider.maximumValue;
	
	settingsS.gainMultiplier = gainValue;
	[audioEngineS bassSetGainLevel:gainValue];
	
	CGFloat difference = fabsf(gainValue - self.lastGainValue);
	if (difference >= .1 || gainValue == minValue || gainValue == maxValue)
	{
		gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", gainValue];
		lastGainValue = gainValue;
	}
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	//DLog(@"touch began");
	
	//DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if ([touchedView isKindOfClass:[EqualizerPointView class]])
	{
		self.selectedView = (EqualizerPointView *)touchedView;
		
		if ([touch tapCount] == 2)
		{
			// remove the point
			//DLog(@"double tap, remove point");
			
			[audioEngineS removeEqualizerValue:self.selectedView.eqValue];
			[equalizerPointViews removeObject:self.selectedView];
			[self.selectedView removeFromSuperview];
			self.selectedView = nil;
			
			[self createAndDrawEqualizerPath];
		}
	}
	/*else if (touchedView == self.landscapeButtonsHolder)
	{
		[self hideLandscapeVisualizerButtons];
	}*/
	else if ([touchedView isKindOfClass:[EqualizerView class]])
	{
		/*if ([touch tapCount] == 1)
		{
			if (!IS_IPAD() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				[self showLandscapeVisualizerButtons];
			}
			
			// Only change visualizers in lanscape mode, when visualier is full screen
			//if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			//	[self performSelector:@selector(type:) withObject:nil afterDelay:0.25];
		}*/
		if ([touch tapCount] == 2)
		{
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(type:) object:nil];
			
			// Only create EQ points in portrait mode when EQ is visible
			if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
			{
				// add a point
				//DLog(@"double tap, adding point");
				
				// Find the tap point
				CGPoint point = [touch locationInView:self.equalizerView];
				
				// Create the eq view
				EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithCGPoint:point parentSize:self.equalizerView.bounds.size];
				BassParamEqValue *value = [audioEngineS addEqualizerValue:eqView.eqValue.parameters];
				eqView.eqValue = value;
				
				// Add the view
				[equalizerPointViews addObject:eqView];
				[self.view addSubview:eqView];
				
				[self saveTempCustomPreset];
			}
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.selectedView != nil)
	{
		UITouch *touch = [touches anyObject];
		
		CGPoint location = [touch locationInView:self.equalizerView];
		if (CGRectContainsPoint(equalizerView.frame, location))
		{
			self.selectedView.center = [touch locationInView:self.view];
			[audioEngineS updateEqParameter:self.selectedView.eqValue];
			
			[self createAndDrawEqualizerPath];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Apply the EQ
	if (self.selectedView != nil)
	{
		[audioEngineS updateEqParameter:self.selectedView.eqValue];
		self.selectedView = nil;
		
		[self saveTempCustomPreset];
	}
}

- (IBAction)dismiss:(id)sender
{
	//[UIApplication setStatusBarHidden:NO withAnimation:NO];
	[self.navigationController popViewControllerAnimated:YES];
	//[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)toggle:(id)sender
{
	if ([audioEngineS toggleEqualizer])
	{
		[self removeEqViews];
		[self createEqViews];
	}
	[self updateToggleButton];
	
	[equalizerPath setNeedsDisplay];
}

- (void)updateToggleButton
{
	if(settingsS.isEqualizerOn)
	{
		[toggleButton setTitle:@"EQ is ON" forState:UIControlStateNormal];
		UIColor *blue = [UIColor colorWithRed:98./255. green:180./255. blue:223./255. alpha:1.];
		[toggleButton setTitleColor:blue forState:UIControlStateNormal];
		toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
	}
	else
	{
		[toggleButton setTitle:@"EQ is OFF" forState:UIControlStateNormal];
		UIColor *grey = [UIColor colorWithWhite:.75 alpha:1.];
		[toggleButton setTitleColor:grey forState:UIControlStateNormal];
		toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
	}
}

- (IBAction)type:(id)sender
{
	[equalizerView nextType];
}

#pragma mark -
#pragma mark NWPickerField
#pragma mark -

- (NSInteger)numberOfComponentsInPickerField:(NWPickerField*)pickerField
{
	return 1;
}

- (NSInteger)pickerField:(NWPickerField*)pickerField numberOfRowsInComponent:(NSInteger)component
{
	return [effectDAO.presets count];	
}

- (NSString *)pickerField:(NWPickerField *)pickerField titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [[effectDAO.presetsArray objectAtIndexSafe:row] objectForKey:@"name"];
}

- (void)pickerField:(NWPickerField *)pickerField selectedRow:(NSInteger)row inComponent:(NSInteger)component
{
	//[pickerField resignFirstResponder];
	
	[effectDAO selectPresetAtIndex:row];
	
	BOOL isDefault = [[effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue];
	
	if (effectDAO.selectedPresetId == BassEffectTempCustomPresetId && !isSavePresetButtonShowing)
	{
		[self showSavePresetButton:YES];
	}
	else if (effectDAO.selectedPresetId != BassEffectTempCustomPresetId && isSavePresetButtonShowing)
	{
		[self hideSavePresetButton:YES];
	}
	
	if (effectDAO.selectedPresetId != BassEffectTempCustomPresetId && !isDeletePresetButtonShowing && !isDefault)
	{
		[self showDeletePresetButton:YES];
	}
	else if ((effectDAO.selectedPresetId == BassEffectTempCustomPresetId || isDefault) && isDeletePresetButtonShowing)
	{
		[self hideDeletePresetButton:YES];
	}
	
	/*self.hidePickerTimer = [GCDTimer gcdTimerInMainQueueAfterDelay:5.0 performBlock:^{
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hidePresetPicker"];
	}];*/
	
	/*// Dismiss the picker view after a few seconds
	[NSObject gcdCancelTimerBlockWithName:hidePickerTimer];
	[self gcdTimerPerformBlockInMainQueue:^{
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hidePresetPicker"];
	} afterDelay:5.0 withName:hidePickerTimer];*/
}

#pragma mark - TableView delegate for save dialog -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return 1;
		case 1:
			return [effectDAO.userPresetsArrayMinusCustom count];
		default:
			return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"NoResuse";
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
	NSDictionary *preset = nil;
	switch (indexPath.section) 
	{
		case 0:
			cell.textLabel.text = @"New Preset";
			break;
		case 1:
			preset = [effectDAO.userPresetsArrayMinusCustom objectAtIndexSafe:indexPath.row];
			cell.tag = [[preset objectForKey:@"presetId"] intValue];
			cell.textLabel.text = [preset objectForKey:@"name"];
			break;
		default:
			break;
	}
		
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return @"";
		case 1:
			return @"Saved Presets";
		default:
			return @"";
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section == 0)
	{
		// Save a new preset
		[self promptForSavePresetName];
	}
	else
	{
		// Save over an existing preset
		UITableViewCell *currentTableCell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
		[effectDAO saveCustomPreset:[self serializedEqPoints] name:currentTableCell.textLabel.text presetId:currentTableCell.tag];
		[effectDAO deleteTempCustomPreset];
		[presetPicker reloadAllComponents];
		[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
	}
	[saveDialog dismiss:YES];
}


@end
