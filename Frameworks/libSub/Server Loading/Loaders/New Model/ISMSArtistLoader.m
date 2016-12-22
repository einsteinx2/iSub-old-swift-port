//
//  ISMSArtistLoader.m
//  libSub
//
//  Created by Benjamin Baron on 5/16/16.
//
//

#import "ISMSArtistLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "LibSub.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"

@interface ISMSArtistLoader()
@property (nonatomic, readwrite) NSArray<id<ISMSItem>> *items;
@end

@implementation ISMSArtistLoader
{
    ISMSArtist *_associatedObject;
}
@synthesize items=_items;

#pragma mark - Loader Methods -

- (NSURLRequest *)createRequest
{
    if (!self.artistId)
        return nil;
    
    NSDictionary *parameters = @{ @"id": self.artistId.stringValue };
    return [NSMutableURLRequest requestWithSUSAction:@"getArtist" parameters:parameters];
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
            NSMutableArray *albums = [[NSMutableArray alloc] initWithCapacity:0];
            
            [root iterate:@"artist.album" usingBlock: ^(RXMLElement *e) {
                ISMSAlbum *album = [[ISMSAlbum alloc] initWithRXMLElement:e serverId:settingsS.currentServerId];
                [albums addObject:album];
            }];

            _items = albums;
            
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
    ISMSArtist *artist = [self associatedObject];
    _items = artist.albums;

    return _items.count > 0;
}

- (id)associatedObject
{
    @synchronized(self)
    {
        if (!_associatedObject)
        {
            _associatedObject = [[ISMSArtist alloc] initWithArtistId:self.artistId.integerValue serverId:settingsS.currentServerId];
        }
        
        return _associatedObject;
    }
}

@end
