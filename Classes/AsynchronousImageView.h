//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, MusicControlsSingleton, DatabaseControlsSingleton, Song;

@interface AsynchronousImageView : UIImageView 
{
	iSubAppDelegate *appDelegate;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	NSString *coverArtId;
	NSURLConnection *connection;
	NSMutableData *data;
	Song *songAtTimeOfLoad;
	
	BOOL isForPlayer;
}

@property (nonatomic, retain) NSString *coverArtId;
@property BOOL isForPlayer;

//- (void)loadImageFromURLString:(NSString *)theUrlString;
- (void)loadImageFromCoverArtId:(NSString *)artId isForPlayer:(BOOL)isPlayer;

@end
