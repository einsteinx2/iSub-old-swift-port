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
    SUSLoaderType_PlayerCoverArt,
    SUSLoaderType_TableCellCoverArt,
    SUSLoaderType_ServerPlaylist
} SUSLoaderType;

/*#define SUSLoaderType_RootFolders       0
#define SUSLoaderType_SubFolders        1
#define SUSLoaderType_AllSongs          2
#define SUSLoaderType_Chat              3
#define SUSLoaderType_Lyrics            4
#define SUSLoaderType_PlayerCoverArt    5
#define SUSLoaderType_TableCellCoverArt 6
#define SUSLoaderType_ServerPlaylist    7*/

@class SUSLoader;
@protocol SUSLoaderDelegate <NSObject>

@required
- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

@end
