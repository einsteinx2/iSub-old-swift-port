//
//  Server.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

#define SUBSONIC @"Subsonic"
#define UBUNTU_ONE @"Ubuntu One"

/*typedef enum {
	ServerTypeSubsonic,
	ServerTypeUbuntu
} ServerType;*/


@interface Server : NSObject <NSCoding>
{
	NSString *url;
	NSString *username;
	NSString *password;
	NSString *type;
}

@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *type;


@end
