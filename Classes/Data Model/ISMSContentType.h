//
//  ISMSContentType.h
//  libSub
//
//  Created by Benjamin Baron on 2/2/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ISMSBasicContentType)
{
    ISMSBasicContentTypeAudio = 1,
    ISMSBasicContentTypeVideo = 2,
    ISMSBasicContentTypeImage = 3
};

@interface ISMSContentType : NSObject

@property (nullable, strong) NSNumber *contentTypeId;
@property (nullable, copy) NSString *mimeType;
@property (nullable, copy) NSString *extension;
@property ISMSBasicContentType basicType;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithContentTypeId:(NSInteger)contentTypeId;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithMimeType:(nonnull NSString *)mimeType;

@end
