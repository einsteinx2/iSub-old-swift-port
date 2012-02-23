//
//  CellOverlay.m
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CellOverlay.h"
#import "ViewObjectsSingleton.h"

@implementation CellOverlay

@synthesize downloadButton, queueButton, inputBlocker;

+ (CellOverlay*)cellOverlayWithTableCell:(UITableViewCell*)cell
{
	return [[[CellOverlay alloc] initWithTableCell:cell] autorelease];
}

- (id)initWithTableCell:(UITableViewCell*)cell
{
	CGRect newFrame = cell.frame;
	newFrame.origin.x = 0;
	newFrame.origin.y = 0;
	if ((self = [super initWithFrame:newFrame]))
	{
			
		self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.7];
		self.alpha = 0.1;
		self.userInteractionEnabled = YES;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		inputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		inputBlocker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[inputBlocker addTarget:cell action:@selector(blockerAction) forControlEvents:UIControlEventTouchUpInside];
		inputBlocker.frame = self.frame;
		inputBlocker.userInteractionEnabled = NO;
		[self addSubview:inputBlocker];
		
		downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
		downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		downloadButton.alpha = .8;
		[downloadButton addTarget:cell action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
		downloadButton.userInteractionEnabled = NO;
		[downloadButton setImage:viewObjectsS.cacheButtonImage forState:UIControlStateNormal];
		downloadButton.frame = CGRectMake(30, 5, 120, 40);
		float width = self.frame.size.width == 320 ? 90.0 : (self.frame.size.width / 3.0) - 50.0;
		downloadButton.center = CGPointMake(width, self.frame.size.height / 2);
		[inputBlocker addSubview:downloadButton];
		
		queueButton = [UIButton buttonWithType:UIButtonTypeCustom];
		queueButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		queueButton.alpha = .8;
		[queueButton addTarget:cell action:@selector(queueAction) forControlEvents:UIControlEventTouchUpInside];
		queueButton.userInteractionEnabled = NO;
		[queueButton setImage:viewObjectsS.queueButtonImage forState:UIControlStateNormal];
		queueButton.frame = CGRectMake(170, 5, 120, 40);
		width = self.frame.size.width == 320 ? 230.0 : ((self.frame.size.width / 3.0) * 2.0) + 40.0;
		queueButton.center = CGPointMake(width, self.frame.size.height / 2);
		[inputBlocker addSubview:queueButton];
	}
	return self;
}

- (void)enableButtons
{
	inputBlocker.userInteractionEnabled = YES;
	downloadButton.userInteractionEnabled = YES;
	queueButton.userInteractionEnabled = YES;
	NSLog(@"enabling buttons - download: %@   queue: %@", NSStringFromBOOL(downloadButton.userInteractionEnabled), NSStringFromBOOL(queueButton.userInteractionEnabled));
}

@end

