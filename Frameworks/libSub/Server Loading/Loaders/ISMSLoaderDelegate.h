//
//  LoaderDelegate.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

typedef NS_ENUM(NSInteger, ISMSLoaderType)
{
    ISMSLoaderType_Generic = 0,
    ISMSLoaderType_RootFolders,
    ISMSLoaderType_SubFolders,
    ISMSLoaderType_AllSongs,
    ISMSLoaderType_Chat,
    ISMSLoaderType_Lyrics,
    ISMSLoaderType_CoverArt,
    ISMSLoaderType_ServerPlaylist,
	ISMSLoaderType_NowPlaying,
    ISMSLoaderType_Status,
    ISMSLoaderType_Login,
    ISMSLoaderType_HLS,
    ISMSLoaderType_QuickAlbums
};

@class ISMSLoader;
@protocol ISMSLoaderDelegate <NSObject>

@optional
- (void)loadingRedirected:(nonnull ISMSLoader *)theLoader redirectUrl:(nonnull NSURL *)url;

@required
- (void)loadingFailed:(nonnull ISMSLoader*)theLoader withError:(nonnull NSError *)error;
- (void)loadingFinished:(nonnull ISMSLoader*)theLoader;

@end
