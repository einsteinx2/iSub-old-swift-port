//
//  ISMSMediaFoldersLoader.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSMediaFoldersLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "LibSub.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"

@implementation ISMSMediaFoldersLoader

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicFolders" parameters:nil];
}

- (void)processResponse
{
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
        }
        else
        {
            NSMutableArray *mediaFolders = [[NSMutableArray alloc] init];
            [root iterate:@"musicFolders" usingBlock:^(RXMLElement *e) {
                
                for (RXMLElement *musicFolder in [e children:@"musicFolder"])
                {
                    ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] init];
                    mediaFolder.mediaFolderId = @([[musicFolder attribute:@"id"] intValue]);
                    mediaFolder.name = [musicFolder attribute:@"name"];
                    
                    [mediaFolders addObject:mediaFolder];
                }
            }];
            self.mediaFolders = mediaFolders;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

- (void)persistModels
{
    [ISMSMediaFolder deleteAllMediaFoldersWithServerId:@(settingsS.currentServerId)];
    [self.mediaFolders makeObjectsPerformSelector:@selector(replaceModel)];
}

@end
