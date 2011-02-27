//
//  CoverArtImageView.m
//  iSub
//
//  Created by bbaron on 8/4/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CoverArtImageView.h"
#import "AsynchronousImageView.h"
#import "PageControlViewController.h"

@implementation CoverArtImageView

-(void)oneTap
{
	NSLog(@"Single tap");
	PageControlViewController *pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
	[self addSubview:pageControlViewController.view];
	[pageControlViewController showSongInfo];
}

-(void)twoTaps
{
	NSLog(@"Double tap");
}

-(void)threeTaps
{
	NSLog(@"Triple tap");
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	
	switch ([touch tapCount]) 
	{
		case 1:
			[self performSelector:@selector(oneTap) withObject:nil afterDelay:0];
			break;
			
		case 2:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(oneTap) object:nil];
			[self performSelector:@selector(twoTaps) withObject:nil afterDelay:.5];
			break;
			
		case 3:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(twoTaps) object:nil];
			[self performSelector:@selector(threeTaps) withObject:nil afterDelay:.5];
			break;
			
		default:
			break;
	}
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/


- (void)dealloc {
    [super dealloc];
}


@end
