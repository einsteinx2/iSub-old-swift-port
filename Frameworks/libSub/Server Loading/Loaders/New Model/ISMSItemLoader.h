//
//  ISMSItemLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/2/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@protocol ISMSItem;
@class ISMSFolder, ISMSArtist, ISMSAlbum, ISMSSong;
@protocol ISMSItemLoader <NSObject>

@property (nullable, weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callbackBlock;

@property (nullable, readonly) id associatedObject;

// Transition to using this single array
@property (nullable, readonly) NSArray<id<ISMSItem>> *items;

@property (readonly) ISMSLoaderState loaderState;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

- (void)startLoad;
- (void)cancelLoad;

@end
