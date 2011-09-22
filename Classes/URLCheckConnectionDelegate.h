//
//  URLCheckConnectionDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface URLCheckConnectionDelegate : NSObject 
{
	NSString *redirectUrl;
	BOOL connectionFinished;
}

@property (nonatomic, retain) NSString *redirectUrl;
@property BOOL connectionFinished;

@end
