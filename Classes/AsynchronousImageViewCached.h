//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//



@interface AsynchronousImageViewCached : UIImageView 
{
    NSURLConnection *connection;
    NSMutableData *data;
	NSString *coverArtId;
}

- (void)loadImageFromURLString:(NSString *)theUrlString coverArtId:(NSString *)artId;

@end