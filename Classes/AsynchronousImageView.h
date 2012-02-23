//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

@interface AsynchronousImageView : UIImageView 
{
	
	NSString *coverArtId;
	NSURLConnection *connection;
	NSMutableData *data;
	
	BOOL isForPlayer;
}

@property (retain) NSString *coverArtId;
@property BOOL isForPlayer;

- (void)loadImageFromCoverArtId:(NSString *)artId isForPlayer:(BOOL)isPlayer;

@end
