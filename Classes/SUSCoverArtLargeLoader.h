//
//  SUSCoverArtLargeLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@interface SUSCoverArtLargeLoader : SUSLoader

@property (retain) NSString *coverArtId;

- (void)loadCoverArtId:(NSString *)artId;

@end
