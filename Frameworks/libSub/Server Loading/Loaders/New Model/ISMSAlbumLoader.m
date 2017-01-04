//
//  ISMSAlbumLoader.m
//  libSub
//
//  Created by Benjamin Baron on 5/16/16.
//
//

#import "ISMSAlbumLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "LibSub.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"

@interface ISMSAlbumLoader()
@property (nonatomic, readwrite) NSArray<id<ISMSItem>> *items;
@end

@implementation ISMSAlbumLoader
{
    ISMSAlbum *_associatedObject;
}
@synthesize items=_items;

#pragma mark - Loader Methods -

- (NSURLRequest *)createRequest
{
    if (!self.albumId)
        return nil;
    
    NSDictionary *parameters = @{ @"id": self.albumId.stringValue };
    return [NSMutableURLRequest requestWithSUSAction:@"getAlbum" parameters:parameters];
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
            NSMutableArray *songs = [[NSMutableArray alloc] initWithCapacity:0];
            
            [root iterate:@"album.song" usingBlock: ^(RXMLElement *e) {
                ISMSSong *song = [[ISMSSong alloc] initWithRXMLElement:e serverId:settingsS.currentServerId];
                [song replaceModel];
                if (song.contentType.extension)
                {
                    [songs addObject:song];
                }
            }];
            
            _items = songs;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark - ISMSItemLoader Methods -

- (void)persistModels
{
    [self.items makeObjectsPerformSelector:@selector(replaceModel)];
}

- (BOOL)loadModelsFromCache
{
    ISMSAlbum *album = [self associatedObject];
    _items = album.songs;
    
    return _items.count > 0;
}

- (id)associatedObject
{
    @synchronized(self)
    {
        if (!_associatedObject)
        {
            _associatedObject = [[ISMSAlbum alloc] initWithAlbumId:self.albumId.integerValue serverId:settingsS.currentServerId loadSubmodels:NO];
        }
        
        return _associatedObject;
    }
}

@end
