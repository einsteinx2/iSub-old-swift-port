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

@synthesize downloadButton, queueButton;

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
		ViewObjectsSingleton *viewObjects = [ViewObjectsSingleton sharedInstance];
		
		self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.7];
		self.alpha = 0.1;
		self.userInteractionEnabled = YES;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		UIButton *inputBlocker = [UIButton buttonWithType:UIButtonTypeCustom];
		inputBlocker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[inputBlocker addTarget:cell action:@selector(blockerAction) forControlEvents:UIControlEventTouchUpInside];
		inputBlocker.frame = self.frame;
		inputBlocker.enabled = YES;
		[self addSubview:inputBlocker];
		
		downloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
		downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		downloadButton.alpha = .8;
		[downloadButton addTarget:cell action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
		downloadButton.enabled = YES;
		[downloadButton setImage:viewObjects.cacheButtonImage forState:UIControlStateNormal];
		downloadButton.frame = CGRectMake(30, 5, 120, 40);
		//self.downloadButton.center = CGPointMake(self.frame.size.width / 3, self.frame.size.height / 2);
		float width;
		if (self.frame.size.width == 320)
		{
			width = 90.0;
		}
		else 
		{
			width = (self.frame.size.width / 3.0) - 50.0;
		}
		downloadButton.center = CGPointMake(width, self.frame.size.height / 2);
		[inputBlocker addSubview:downloadButton];
		
		queueButton = [UIButton buttonWithType:UIButtonTypeCustom];
		queueButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		queueButton.alpha = .8;
		[queueButton addTarget:cell action:@selector(queueAction) forControlEvents:UIControlEventTouchUpInside];
		queueButton.enabled = YES;
		[queueButton setImage:viewObjects.queueButtonImage forState:UIControlStateNormal];
		queueButton.frame = CGRectMake(170, 5, 120, 40);
		if (self.frame.size.width == 320)
		{
			width = 230.0;
		}
		else 
		{
			width = ((self.frame.size.width / 3.0) * 2.0) + 40.0;
		}
		//self.queueButton.center = CGPointMake((self.frame.size.width / 3) * 2, self.frame.size.height / 2);
		queueButton.center = CGPointMake(width, self.frame.size.height / 2);
		[inputBlocker addSubview:queueButton];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code.
}
*/

- (void)dealloc {
    [super dealloc];
}


@end

