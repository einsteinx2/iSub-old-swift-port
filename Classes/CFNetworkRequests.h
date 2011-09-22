//
//  CFNetworkRequests.h
//  iSub
//
//  Created by Ben Baron on 7/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
#import "Song.h"


@interface CFNetworkRequests : NSObject 
{

}

+ (BOOL) downloadA;
+ (BOOL) downloadB;

+ (void) cancelCFNetA;
+ (void) cancelCFNetB;

+ (void) downloadCFNetA:(NSURL *)url;
+ (void) downloadCFNetTemp:(NSURL *)url;
+ (void) downloadCFNetB:(NSURL *)url;

+ (void) resumeCFNetA:(UInt32)byteOffset;
+ (void) resumeCFNetB:(UInt32)byteOffset;

+ (BOOL) insertSong:(Song *)aSong intoGenreTable:(NSString *)table;

@end
