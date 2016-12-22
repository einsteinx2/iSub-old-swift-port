//
//  ISMSMediaFoldersLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@class ISMSMediaFolder;
@interface ISMSMediaFoldersLoader : ISMSLoader

@property (nullable, strong) NSArray<ISMSMediaFolder*> *mediaFolders;

- (void)persistModels;

@end
