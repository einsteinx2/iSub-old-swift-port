//
//  NSString-rfcEncode.h
//  iSub
//
//  Created by Ben Baron on 12/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface NSString (RFC3875)

- (NSString *)stringByAddingRFC3875PercentEscapesUsingEncoding:(NSStringEncoding)encoding;

@end
