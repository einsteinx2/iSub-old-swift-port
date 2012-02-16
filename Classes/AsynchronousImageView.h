//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//


@class iSubAppDelegate, MusicSingleton, DatabaseSingleton;

@interface AsynchronousImageView : UIImageView 
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSString *coverArtId;
	NSURLConnection *connection;
	NSMutableData *data;
	
	BOOL isForPlayer;
}

@property (retain) NSString *coverArtId;
@property BOOL isForPlayer;

- (void)loadImageFromCoverArtId:(NSString *)artId isForPlayer:(BOOL)isPlayer;

@end
