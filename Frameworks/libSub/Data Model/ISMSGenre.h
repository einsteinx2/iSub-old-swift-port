//
//  ISMSGenre.h
//  libSub
//
//  Created by Benjamin Baron on 2/2/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

#import "ISMSItem.h"

@interface ISMSGenre : NSObject <ISMSItem, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *genreId;
@property (nullable, copy) NSString *name;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithGenreId:(NSInteger)genreId;

// Returns an instance if it exists in the db, otherwise inserts a new record
// and returns a genre object containing a genre id. Never returns nil.
- (nonnull instancetype)initWithName:(nonnull NSString *)name;

@end
