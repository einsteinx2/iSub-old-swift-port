//
//  ISMSScrobbleLoader.m
//  libSub
//
//  Created by Justin Hill on 2/8/13.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import "ISMSScrobbleLoader.h"
#import "LibSub.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@implementation ISMSScrobbleLoader

- (NSURLRequest *)createRequest
{
    NSString *isSubmissionString = [NSString stringWithFormat:@"%i", self.isSubmission];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(self.aSong.songId), @"id", n2N(isSubmissionString), @"submission", nil];
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"scrobble" parameters:parameters];
    ALog(@"%@", parameters);
    return request;
}

- (void)processResponse
{
    [self informDelegateLoadingFinished];
}

@end
