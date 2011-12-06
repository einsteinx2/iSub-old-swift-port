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
#import "BassWrapperSingleton.h"
#import "BassParamEqValue.h"
#import "BassEffectDAO.h"

@implementation EqualizerViewController
@synthesize equalizerView, equalizerPointViews, selectedView, toggleButton, effectDAO; //drawTimer;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
		
	[self updateToggleButton];
	
	[self createEqViews];
	
	[self.equalizerView startEqDisplay];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createEqViews) name:ISMSNotification_BassEffectPresetLoaded object:nil];
}

- (void)createEqViews
{
	[self removeEqViews];
	
	equalizerPointViews = [[NSMutableArray alloc] initWithCapacity:0];
	for (BassParamEqValue *value in [BassWrapperSingleton sharedInstance].equalizerValues)
	{
		DLog(@"eq handle: %i", value.handle);
		EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithEqValue:value parentSize:self.equalizerView.bounds.size];
		[equalizerPointViews addObject:eqView];
		[self.view addSubview:eqView];
		[eqView release];
	}
	DLog(@"equalizerValues: %@", [BassWrapperSingleton sharedInstance].equalizerValues);
	DLog(@"equalizerViews: %@", equalizerPointViews);
}

- (void)removeEqViews
{
	for (EqualizerPointView *eqView in equalizerPointViews)
	{
		[eqView removeFromSuperview];
	}
	[equalizerPointViews release]; equalizerPointViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassEffectPresetLoaded object:nil];
	
	[self removeEqViews];
	
	[self.equalizerView stopEqDisplay];
	
	[equalizerView removeFromSuperview];
	[equalizerView release]; equalizerView = nil;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	DLog(@"touch began");
	
	DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if ([touchedView isKindOfClass:[EqualizerPointView class]])
	{
		self.selectedView = (EqualizerPointView *)touchedView;
		
		if ([touch tapCount] == 2)
		{
			// remove the point
			DLog(@"double tap, remove point");
			
			[[BassWrapperSingleton sharedInstance] removeEqualizerValue:self.selectedView.eqValue];
			[equalizerPointViews removeObject:self.selectedView];
			[self.selectedView removeFromSuperview];
			self.selectedView = nil;
		}
	}
	else if ([touchedView isKindOfClass:[EqualizerView class]])
	{
		if ([touch tapCount] == 1)
		{
			[self performSelector:@selector(type:) withObject:nil afterDelay:0.25];
		}
		if ([touch tapCount] == 2)
		{
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(type:) object:nil];
			
			// add a point
			DLog(@"double tap, adding point");
			
			// Find the tap point
			CGPoint point = [touch locationInView:self.equalizerView];
			
			// Create the eq view
			EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithCGPoint:point parentSize:self.equalizerView.bounds.size];
			BassParamEqValue *value = [[BassWrapperSingleton sharedInstance] addEqualizerValue:eqView.eqValue.parameters];
			eqView.eqValue = value;
			
			// Add the view
			[equalizerPointViews addObject:eqView];
			[self.view addSubview:eqView];
			[eqView release];
			
			return;
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
			[[BassWrapperSingleton sharedInstance] updateEqParameter:self.selectedView.eqValue];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Apply the EQ
	if (self.selectedView != nil)
	{
		[[BassWrapperSingleton sharedInstance] updateEqParameter:self.selectedView.eqValue];
		self.selectedView = nil;
	}
}

- (IBAction)dismiss:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)toggle:(id)sender
{
	if ([[BassWrapperSingleton sharedInstance] toggleEqualizer])
	{
		[self removeEqViews];
		[self createEqViews];
	}
	[self updateToggleButton];
}

- (void)updateToggleButton
{
	if([BassWrapperSingleton sharedInstance].isEqualizerOn)
	{
		[toggleButton setTitle:@"Disable" forState:UIControlStateNormal];
	}
	else
	{
		[toggleButton setTitle:@"Enable" forState:UIControlStateNormal];
	}
}

- (IBAction)type:(id)sender
{
	[equalizerView changeType];
}

#pragma mark -
#pragma mark NWPickerField
#pragma mark -

-(NSInteger) numberOfComponentsInPickerField:(NWPickerField*)pickerField
{
	return 1;
}


-(NSInteger) pickerField:(NWPickerField*)pickerField numberOfRowsInComponent:(NSInteger)component
{
	return [effectDAO.presets count];	
}

-(NSString *) pickerField:(NWPickerField *)pickerField titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [[effectDAO.presets objectAtIndex:row] objectForKey:@"name"];
}

-(void) pickerField:(NWPickerField *)pickerField selectedRow:(NSInteger)row inComponent:(NSInteger)component
{
	[pickerField resignFirstResponder];
	
	DLog(@"row: %i", row);
	[effectDAO selectPresetAtIndex:row];
}

@end
