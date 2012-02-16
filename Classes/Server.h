//
//  Server.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



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

@property (retain) NSString *url;
@property (retain) NSString *username;
@property (retain) NSString *password;
@property (retain) NSString *type;


@end
