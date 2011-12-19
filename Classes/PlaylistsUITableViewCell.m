//
//  PlaylistsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistsUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "CellOverlay.h"
#import "NSString+md5.h"
#import "NSMutableURLRequest+SUS.h"
#import "SUSServerPlaylist.h"
#import "NSMutableURLRequest+SUS.h"
#import "CustomUIAlertView.h"
#import "Song.h"
#import "TBXML.h"

@implementation PlaylistsUITableViewCell

@synthesize receivedData;
@synthesize indexPath, playlistNameScrollView, playlistNameLabel, isOverlayShowing, overlayView, deleteToggleImage, isDelete;
@synthesize serverPlaylist;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
        // Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		
		isOverlayShowing = NO;
		
		playlistNameScrollView = [[UIScrollView alloc] init];
		playlistNameScrollView.frame = CGRectMake(5, 10, 310, 44);
		playlistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		playlistNameScrollView.showsVerticalScrollIndicator = NO;
		playlistNameScrollView.showsHorizontalScrollIndicator = NO;
		playlistNameScrollView.userInteractionEnabled = NO;
		playlistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:playlistNameScrollView];
		[playlistNameScrollView release];
		
		playlistNameLabel = [[UILabel alloc] init];
		playlistNameLabel.backgroundColor = [UIColor clearColor];
		playlistNameLabel.textAlignment = UITextAlignmentLeft; // default
		playlistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[playlistNameScrollView addSubview:playlistNameLabel];
		[playlistNameLabel release];
		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		[deleteToggleImage release];
    }
    return self;
}


- (void)toggleDelete
{
	if (deleteToggleImage.image == [UIImage imageNamed:@"unselected.png"])
	{
		[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showDeleteButton" object:nil];
		deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	else
	{
		[viewObjects.multiDeleteList removeObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"hideDeleteButton" object:nil];
		deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
}

- (void)downloadAction
{
	[viewObjects showLoadingScreenOnMainWindow];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" andParameters:parameters];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
        isDownload = YES;
		self.receivedData = [NSMutableData dataWithCapacity:0];
	} 
	else 
	{
		// TODO: Handle error
	}
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}

- (void)queueAction
{
	[viewObjects showLoadingScreenOnMainWindow];
	
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" andParameters:parameters];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
        isDownload = NO;
		self.receivedData = [NSMutableData dataWithCapacity:0];
	} 
	else 
	{
		// TODO: Handle error
	}
    
	[self hideOverlay];
}



- (void)blockerAction
{
	//DLog(@"blockerAction");
	[self hideOverlay];
}


- (void)hideOverlay
{
	if (overlayView)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		overlayView.alpha = 0.0;
		[UIView commitAnimations];
		
		isOverlayShowing = NO;
		
		//[self.downloadButton removeFromSuperview];
		//[self.queueButton removeFromSuperview];
		//[self.overlayView removeFromSuperview];
	}
}


- (void)showOverlay
{
	if (!isOverlayShowing)
	{
		overlayView = [CellOverlay cellOverlayWithTableCell:self];
		[self.contentView addSubview:overlayView];
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		overlayView.alpha = 1.0;
		[UIView commitAnimations];		
		
		isOverlayShowing = YES;
	}
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);

	// Automatically set the width based on the width of the text
	playlistNameLabel.frame = CGRectMake(0, 0, 290, 44);
	CGSize expectedLabelSize = [playlistNameLabel.text sizeWithFont:playlistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:playlistNameLabel.lineBreakMode]; 
	CGRect newFrame = playlistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	playlistNameLabel.frame = newFrame;
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	self.receivedData = nil;
	[theConnection release];
	
	// Inform the delegate that loading failed
	[viewObjects hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    // Parse the data
    //
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
    {
        TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
        if (error)
        {
            // TODO: handle error
        }
        else
        {
            TBXMLElement *playlist = [TBXML childElementNamed:@"playlist" parentElement:root];
            if (playlist)
            {
                NSString *md5 = [serverPlaylist.playlistName md5];
                [databaseControls removeServerPlaylistTable:md5];
                [databaseControls createServerPlaylistTable:md5];
                
                TBXMLElement *entry = [TBXML childElementNamed:@"entry" parentElement:playlist];
                while (entry != nil)
                {
                    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                    
                    Song *aSong = [[Song alloc] initWithTBXMLElement:entry];
                    [aSong insertIntoServerPlaylistWithPlaylistId:md5];
                    if (isDownload)
                    {
                        [aSong addToCacheQueue];
                    }
                    else
                    {
                        [aSong addToPlaylistQueue];
                    }
                    [aSong release];
                    
                    // Get the next message
                    entry = [TBXML nextSiblingNamed:@"entry" searchFromElement:entry];
                    
                    [pool release];
                }
                
                if (isDownload && musicControls.isQueueListDownloading == NO)
                {
                    [musicControls downloadNextQueuedSong];
                }
            }
        }
    }
	[tbxml release];
	
	// Hide the loading screen
	[viewObjects hideLoadingScreen];
	
	self.receivedData = nil;
	[theConnection release];
}

#pragma mark Touch gestures for custom cell view

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	UITouch *touch = [touches anyObject];
    startTouchPosition = [touch locationInView:self];
	swiping = NO;
	hasSwiped = NO;
	fingerIsMovingLeftOrRight = NO;
	fingerMovingVertically = NO;
	[super touchesBegan:touches withEvent:event];
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if ([self isTouchGoingLeftOrRight:[touches anyObject]]) 
	{
		[self lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event];
	} 
	
	[super touchesMoved:touches withEvent:event];
}


// Determine what kind of gesture the finger event is generating
- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch 
{
    CGPoint currentTouchPosition = [touch locationInView:self];
	if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= 1.0) 
	{
		fingerIsMovingLeftOrRight = YES;
		return YES;
    } 
	else 
	{
		fingerIsMovingLeftOrRight = NO;
		return NO;
	}
	
	if (fabsf(startTouchPosition.y - currentTouchPosition.y) >= 2.0) 
	{
		fingerMovingVertically = YES;
	} 
	else 
	{
		fingerMovingVertically = NO;
	}
}


- (BOOL)fingerIsMoving {
	return fingerIsMovingLeftOrRight;
}

- (BOOL)fingerIsMovingVertically {
	return fingerMovingVertically;
}

// Check for swipe gestures
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self];
	
	[self setSelected:NO];
	swiping = YES;
	
	//ShoppingAppDelegate *appDelegate = (ShoppingAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if (hasSwiped == NO) 
	{
		// If the swipe tracks correctly.
		if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= viewObjects.kHorizSwipeDragMin &&
			fabsf(startTouchPosition.y - currentTouchPosition.y) <= viewObjects.kVertSwipeDragMax)
		{
			// It appears to be a swipe.
			if (startTouchPosition.x < currentTouchPosition.x) 
			{
				// Right swipe
				// Disable the cells so we don't get accidental selections
				viewObjects.isCellEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				[self showOverlay];
				
				// Re-enable cell touches in 1 second
				viewObjects.cellEnabledTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:viewObjects selector:@selector(enableCells) userInfo:nil repeats:NO];
			} 
			else 
			{
				// Left Swipe
				// Disable the cells so we don't get accidental selections
				viewObjects.isCellEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				if (playlistNameLabel.frame.size.width > playlistNameScrollView.frame.size.width)
				{
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:playlistNameLabel.frame.size.width/(float)150];
					playlistNameScrollView.contentOffset = CGPointMake(playlistNameLabel.frame.size.width - playlistNameScrollView.frame.size.width + 10, 0);
					[UIView commitAnimations];
				}
				
				// Re-enable cell touches in 1 second
				viewObjects.cellEnabledTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:viewObjects selector:@selector(enableCells) userInfo:nil repeats:NO];
			}
		} 
		else 
		{
			// Process a non-swipe event.
		}
		
	}
}


- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:playlistNameLabel.frame.size.width/(float)150];
	playlistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	swiping = NO;
	hasSwiped = NO;
	fingerMovingVertically = NO;
	[super touchesEnded:touches withEvent:event];
}


- (void)dealloc {
	[indexPath release];
	//[playlistNameLabel release];
	[super dealloc];
}


@end
