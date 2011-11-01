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
    NSMutableData *receivedData;
}

@property (nonatomic, retain) NSString *coverArtId;

- (void)loadImageFromCoverArtId:(NSString *)artId;

@end