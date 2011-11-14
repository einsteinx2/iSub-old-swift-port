//
//  Song+DAO.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "Song.h"

@interface Song (DAO)

@property (readonly) BOOL isFullyCached;
@property (readonly) BOOL fileExists;

@end
