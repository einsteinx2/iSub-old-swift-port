//
//  LoaderDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

typedef enum
{
    ISMSLoaderType_Generic = 0,
    ISMSLoaderType_RootFolders,
    ISMSLoaderType_SubFolders,
    ISMSLoaderType_AllSongs,
    ISMSLoaderType_Chat,
    ISMSLoaderType_Lyrics,
    ISMSLoaderType_CoverArt,
    ISMSLoaderType_ServerPlaylist,
	ISMSLoaderType_NowPlaying
} ISMSLoaderType;

@class ISMSLoader;
@protocol ISMSLoaderDelegate <NSObject>

@required
- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(ISMSLoader*)theLoader;

@end
