//
//  ISMSRecursiveSongLoader.h
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//
#import "ISMSAbstractItemLoader.h"

typedef NS_ENUM(NSInteger, ISMSRecursiveItemLoaderMode)
{
    ISMSRecursiveItemLoaderModeFolder = 1,
    ISMSRecursiveItemLoaderModeAlbum = 2
};

@interface ISMSRecursiveItemLoader : ISMSAbstractItemLoader

@property ISMSRecursiveItemLoaderMode mode;
@property (strong) NSNumber *rootCollectionId;

@property (readonly) BOOL isActive;
@property (readonly) BOOL isCancelled;

@end
