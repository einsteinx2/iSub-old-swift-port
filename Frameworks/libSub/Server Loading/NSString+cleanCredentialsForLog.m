//
//  NSString+cleanCredentialsForLog.m
//  libSub
//
//  Created by Benjamin Baron on 2/27/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "NSString+cleanCredentialsForLog.h"

@implementation NSString (cleanCredentialsForLog)

- (NSString *)cleanCredentialsForLog
{
    /*NSMutableString *cleanString = [self mutableCopy];
    
    // Replace username
    NSString *usernameString = [NSString stringWithFormat:@"u=%@", SavedSettings.si.username];
    [cleanString replaceOccurrencesOfString:usernameString withString:@"u=XXXX" options:0 range:NSMakeRange(0, cleanString.length)];
    
    // Replace password
    NSString *passwordString = [NSString stringWithFormat:@"p=%@", SavedSettings.si.password];
    [cleanString replaceOccurrencesOfString:passwordString withString:@"p=XXXX" options:0 range:NSMakeRange(0, cleanString.length)];
    
    // Replace basic auth header string
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", SavedSettings.si.username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64Encoded]];*/
    return self;
}

@end
