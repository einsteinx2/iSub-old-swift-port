//
//  AsynchronousImageView.h
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface AsynchronousImageViewCached : UIImageView 
{
    NSURLConnection *connection;
    NSMutableData *data;
	NSString *coverArtId;
}

- (void)loadImageFromURLString:(NSString *)theUrlString coverArtId:(NSString *)artId;

@end