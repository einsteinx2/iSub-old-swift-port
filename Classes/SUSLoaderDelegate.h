//
//  LoaderDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

typedef enum
{
    SUSLoaderType_Generic = 0,
    SUSLoaderType_RootFolders,
    SUSLoaderType_SubFolders,
    SUSLoaderType_AllSongs,
    SUSLoaderType_Chat,
    SUSLoaderType_Lyrics,
    SUSLoaderType_CoverArt,
    SUSLoaderType_ServerPlaylist,
	SUSLoaderType_NowPlaying
} SUSLoaderType;

@class SUSLoader;
@protocol SUSLoaderDelegate <NSObject>

@required
- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

@end
