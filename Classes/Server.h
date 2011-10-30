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

@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *type;


@end
