//
//  DonationParser.h
//  iSub
//
//  Created by bbaron on 10/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface DonationParser : NSObject <NSXMLParserDelegate>
{
	BOOL donationRequired;
}

@property BOOL donationRequired;

@end
