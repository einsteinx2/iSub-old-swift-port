//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, MusicSingleton, DatabaseSingleton, Song;

@interface AsynchronousImageView : UIImageView 
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
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
