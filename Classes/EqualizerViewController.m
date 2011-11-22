//
//  EqualizerViewController.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "EqualizerViewController.h"
#import "EqualizerView.h"
#import "BassWrapperSingleton.h"
#import "BassParamEqValue.h"
#import <QuartzCore/QuartzCore.h>

@implementation EqualizerViewController
@synthesize drawImage, equalizerViews, selectedView, drawTimer, toggleButton;

#define SPECWIDTH 320	// display width
#define SPECHEIGHT 320	// height (changing requires palette adjustments too)
CGContextRef specdc;
DWORD specbuf[SPECWIDTH*SPECHEIGHT];
DWORD palette[SPECHEIGHT+128];
int specpos = 0;

typedef struct 
{
	BYTE rgbRed, rgbGreen, rgbBlue, Aplha;
} RGBQUAD;

typedef enum
{
	ISMSBassVisualType_line,
	ISMSBassVisualType_skinnyBar,
	ISMSBassVisualType_fatBar,
	ISMSBassVisualType_aphexFace
} ISMSBassVisualType;

ISMSBassVisualType visualType = ISMSBassVisualType_fatBar;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self updateToggleButton];
	
	[self createEqViews];
	
	[self createBitmapToDraw];

	[self setupPalette];
		
	self.drawTimer = [NSTimer scheduledTimerWithTimeInterval:(1./20.) target:self selector:@selector(drawTheEq) userInfo:nil repeats:YES];
}

- (void)createBitmapToDraw
{
	// create the bitmap
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	specdc = CGBitmapContextCreate(specbuf, SPECWIDTH, SPECHEIGHT, 8, SPECWIDTH * 4, colorSpace, kCGImageAlphaNoneSkipLast);
	CGColorSpaceRelease(colorSpace);
}

- (void)setupPalette
{
	// setup palette
	RGBQUAD *pal = (RGBQUAD *)palette;
	int a;
	memset(palette, 0, sizeof(palette));
	for (a = 1; a < 65; a++) 
	{
		pal[a].rgbRed = 130 - 2 * a;
		pal[a].rgbBlue = 126 + 2 * a;
	}
    for (a = 1; a < 128; a++) 
	{
		pal[64+a].rgbBlue = 256 - 2 * a;
		pal[64+a].rgbGreen   = 2 * a;
	}
    for (a = 1; a < 128; a++) 
	{
		pal[191+a].rgbGreen = 256 - 2 * a;
		pal[191+a].rgbRed   = 2 * a;
	}
	
	for (a = 0; a < 32; a++) 
	{
		pal[SPECHEIGHT + a].rgbBlue       = 8 * a;
		pal[SPECHEIGHT + 32 + a].rgbBlue  = 255;
		pal[SPECHEIGHT + 32 + a].rgbRed   = 8 * a;
		pal[SPECHEIGHT + 64 + a].rgbRed   = 255;
		pal[SPECHEIGHT + 64 + a].rgbBlue  = 8 * (31 - a);
		pal[SPECHEIGHT + 64 + a].rgbGreen = 8 * a;
		pal[SPECHEIGHT + 96 + a].rgbRed   = 255;
		pal[SPECHEIGHT + 96 + a].rgbGreen = 255;
		pal[SPECHEIGHT + 96 + a].rgbBlue  = 8 * a;
	}

}

- (void)createEqViews
{
	equalizerViews = [[NSMutableArray alloc] initWithCapacity:0];
	for (BassParamEqValue *value in [BassWrapperSingleton sharedInstance].equalizerValues)
	{
		DLog(@"eq handle: %i", value.handle);
		EqualizerView *eqView = [[EqualizerView alloc] initWithEqValue:value parentSize:self.drawImage.bounds.size];
		[equalizerViews addObject:eqView];
		[self.view addSubview:eqView];
		[eqView release];
	}
	DLog(@"equalizerValues: %@", [BassWrapperSingleton sharedInstance].equalizerValues);
	DLog(@"equalizerViews: %@", equalizerViews);
}

- (void)removeEqViews
{
	for (EqualizerView *eqView in equalizerViews)
	{
		[eqView removeFromSuperview];
	}
	[equalizerViews release]; equalizerViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[drawImage release]; drawImage = nil;
	
	[self removeEqViews];
	
	[drawTimer invalidate]; drawTimer = nil;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)drawTheEq
{	
	BassWrapperSingleton *wrapper = [BassWrapperSingleton sharedInstance];
	
	switch(visualType)
	{
		int x, y, y1;
			
		case ISMSBassVisualType_line:
		{
			memset(specbuf,0,sizeof(specbuf));
			for (x = 0; x < SPECWIDTH; x++) 
			{
				int v=(32767 - [wrapper lineSpecData:x]) * SPECHEIGHT/65536; // invert and scale to fit display
				if (!x) 
					y = v;
				do 
				{ 
					// draw line from previous sample...
					if (y < v)
						y++;
					else if (y > v)
						y--;
					specbuf[y * SPECWIDTH + x] = palette[abs(y - SPECHEIGHT / 2) * 2 + 1];
				} while (y!=v);
			}
			break;
		}
		case ISMSBassVisualType_skinnyBar:
		{
			memset(specbuf,0,sizeof(specbuf));
			for (x=0;x<SPECWIDTH/2;x++) 
			{
#if 1
				y=sqrt([wrapper fftData:x+1]) * 3 * SPECHEIGHT - 4; // scale it (sqrt to make low values more visible)
#else
				y=[wrapper fftData:x+1] * 10 * SPECHEIGHT; // scale it (linearly)
#endif
				if (y>SPECHEIGHT) y=SPECHEIGHT; // cap it
				if (x && (y1=(y+y1)/2)) // interpolate from previous to make the display smoother
					while (--y1>=0) specbuf[(SPECHEIGHT-1-y1)*SPECWIDTH+x*2-1]=palette[y1+1];
				y1=y;
				while (--y>=0) specbuf[(SPECHEIGHT-1-y)*SPECWIDTH+x*2]=palette[y+1]; // draw level
			}
			break;
		}
		case ISMSBassVisualType_fatBar:
		{
			int b0 = 0;
			memset(specbuf,0,sizeof(specbuf));
			#define BANDS 28
			for (x=0; x < BANDS; x++) 
			{
				float peak = 0;
				int b1 = pow(2, x * 10.0 / (BANDS - 1));
				if (b1 > 1023)
					b1 = 1023;
				if (b1 <= b0)
					b1 = b0 + 1; // make sure it uses at least 1 FFT bin
				
				for (; b0 < b1; b0++)
				{
					if (peak < [wrapper fftData:1+b0])
						peak = [wrapper fftData:1+b0];
				}
				
				y = sqrt(peak) * 3 * SPECHEIGHT - 4; // scale it (sqrt to make low values more visible)
				
				if (y > SPECHEIGHT) 
					y = SPECHEIGHT; // cap it
				
				while (--y >= 0)
				{
					for (y1 = 0; y1 < SPECWIDTH / BANDS - 2; y1++)
					{	
						specbuf[(SPECHEIGHT - 1 - y) * SPECWIDTH + x * (SPECWIDTH / BANDS) + y1] = palette[y + 1]; // draw bar
					}
				}
			}
			break;
		}
		case ISMSBassVisualType_aphexFace:
		{
			for (x=0; x < SPECHEIGHT; x++) 
			{
				y = sqrt([wrapper fftData:x+1]) * 3 * 127; // scale it (sqrt to make low values more visible)
				if (y > 127)
					y = 127; // cap it
				specbuf[(SPECHEIGHT - 1 - x) * SPECWIDTH + specpos] = palette[SPECHEIGHT - 1 + y]; // plot it
			}
			// move marker onto next position
			specpos = (specpos + 1) % SPECWIDTH;
			for (x = 0; x < SPECHEIGHT; x++) 
				specbuf[x * SPECWIDTH + specpos] = palette[SPECHEIGHT+126];
			break;
		}
	}
	
	CGImageRef cgi = CGBitmapContextCreateImage(specdc);
	//drawImage.image = [UIImage imageWithCGImage:cgi];
	drawImage.layer.contents = (id)cgi;
	CGImageRelease(cgi);
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	DLog(@"touch began");
	
	DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if (touchedView != self.view)
	{
		if ([touchedView isKindOfClass:[EqualizerView class]])
		{
			self.selectedView = (EqualizerView *)touchedView;
			
			if ([touch tapCount] == 2)
			{
				// remove the point
				DLog(@"double tap, remove point");
				
				[[BassWrapperSingleton sharedInstance] removeEqualizerValue:self.selectedView.eqValue];
				[equalizerViews removeObject:self.selectedView];
				[self.selectedView removeFromSuperview];
				self.selectedView = nil;
			}
		}
	}
	else
	{
		if ([touch tapCount] == 2)
		{
			// add a point
			DLog(@"double tap, adding point");
			
			// Find the tap point
			CGPoint point = [touch locationInView:self.drawImage];
			
			// Create the eq view
			EqualizerView *eqView = [[EqualizerView alloc] initWithCGPoint:point parentSize:self.drawImage.bounds.size];
			BassParamEqValue *value = [[BassWrapperSingleton sharedInstance] addEqualizerValue:eqView.eqValue.parameters];
			eqView.eqValue = value;
			
			// Add the view
			[equalizerViews addObject:eqView];
			[self.view addSubview:eqView];
			[eqView release];
			
			return;
		}
	}

}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	
	CGPoint location = [touch locationInView:self.drawImage];
	if (CGRectContainsPoint(drawImage.frame, location))
	{
		self.selectedView.center = [touch locationInView:self.view];
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
	switch (visualType)
	{
		case ISMSBassVisualType_line:
			visualType = ISMSBassVisualType_skinnyBar; break;
		case ISMSBassVisualType_skinnyBar:
			visualType = ISMSBassVisualType_fatBar; break;
		case ISMSBassVisualType_fatBar:
            memset(specbuf, 0, sizeof(specbuf));
            specpos = 0;
			visualType = ISMSBassVisualType_aphexFace; break;
		case ISMSBassVisualType_aphexFace:
			visualType = ISMSBassVisualType_line; break;
	}
}

@end
