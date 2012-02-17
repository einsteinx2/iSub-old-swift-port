//
//  SUSCoverArtLargeDAO.m
//  iSub
//
//  Created by Benjamin Baron on 11/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSCoverArtLargeDAO.h"
#import "FMDatabaseAdditions.h"

#import "DatabaseSingleton.h"
#import "NSString+md5.h"

@implementation SUSCoverArtLargeDAO

+ (SUSCoverArtLargeDAO *)dataModel
{
    return [[[SUSCoverArtLargeDAO alloc] init] autorelease];
}

#pragma mark - Private DB Methods

- (FMDatabase *)db
{
    if (IS_IPAD())
        return [DatabaseSingleton sharedInstance].coverArtCacheDb540;
    else
        return [DatabaseSingleton sharedInstance].coverArtCacheDb320;
}

#pragma mark - Public DAO methods

- (UIImage *)coverArtImageForId:(NSString *)coverArtId
{
    NSData *imageData = [self.db dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [coverArtId md5]];
    if (imageData)
    {
        /*if (SCREEN_SCALE() == 2.0)
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(320.0,320.0), NO, 2.0);
            [[UIImage imageWithData:imageData] drawInRect:CGRectMake(0,0,320,320)];
            coverArtImageView.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            //coverArtImageView.image = [[UIImage imageWithData:imageData] drawInRect:CGRectMake(0,0,320,320)];
        }
        else
        {
            coverArtImageView.image = [UIImage imageWithData:imageData];
        }*/
        
        //DLog(@"Cover Art Found!!");
        return [UIImage imageWithData:imageData];
    }
    
    //DLog(@"No Cover Art Found, returning nil");
    return nil;
}

- (UIImage *)defaultCoverArt
{
    if (IS_IPAD())
        return [UIImage imageNamed:@"default-album-art-ipad.png"];
    else
        return [UIImage imageNamed:@"default-album-art.png"];
}

- (BOOL)coverArtExistsForId:(NSString *)coverArtId
{
    return [self.db boolForQuery:@"SELECT count(*) FROM coverArtCache WHERE id = ?", [coverArtId md5]];
}

@end
