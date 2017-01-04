//
//  ISMSRecursiveSongLoader.m
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

/*
#import "ISMSRecursiveItemLoader.h"
#import "LibSub.h"
#import "ISMSStreamManager.h"
#import "NSMutableURLRequest+SUS.h"

@interface ISMSRecursiveItemLoader () <ISMSLoaderDelegate>
@property (nonatomic, strong) ISMSRecursiveItemLoader *selfRef;
@property (nullable, strong, readwrite) NSArray<ISMSFolder*> *folders;
@property (nullable, strong, readwrite) NSArray<ISMSSong*> *songs;
@property (readwrite) BOOL isActive;
@property (readwrite) BOOL isCancelled;
@end

@implementation ISMSRecursiveItemLoader
{
    NSMutableArray *_tempFolderIds;
    NSMutableArray *_tempFolders;
    NSMutableArray *_tempSongs;
    
    ISMSLoader *_activeLoader;
}

- (void)startLoad
{
    if (!_isActive && _rootCollectionId)
    {
        if (self.mode == ISMSRecursiveItemLoaderModeFolder)
        {
            if (!self.selfRef)
                self.selfRef = self;
            
            _tempFolderIds = [NSMutableArray arrayWithCapacity:0];
            _tempFolders = [NSMutableArray arrayWithCapacity:0];
            _tempSongs = [NSMutableArray arrayWithCapacity:0];
            
            self.isCancelled = NO;
            self.isActive = YES;
            
            [_tempFolderIds addObject:_rootCollectionId];
            
            [self loadFolder];
        }
    }
}

- (void)loadFolder
{
    if (self.isCancelled)
        return;
    
    NSNumber *folderId = [_tempFolderIds firstObject];
    
    ISMSFolderLoader *loader = [[ISMSFolderLoader alloc] initWithDelegate:self];
    loader.folderId = folderId;
    [loader startLoad];
    
    _activeLoader = loader;
}

- (void)cancelLoad
{
    [_activeLoader cancelLoad];
    _activeLoader = nil;
    
	self.isCancelled = YES;
    self.selfRef = nil;
}

- (void)continueLoading
{	
	if (self.isCancelled)
		return;
	
	if (_tempFolderIds.count > 0)
	{
        // Continue to the next iteration
		[self loadFolder];
	}
	else 
	{
		// We're done!
        [self informDelegateLoadingFinished];
	}
}

#pragma mark Connection Delegate

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    if (_mode == ISMSRecursiveItemLoaderModeFolder)
    {
        // Remove the processed folder from array
        [_tempFolderIds removeObjectAtIndexSafe:0];
        
        // Continue to the next iteration
        [self continueLoading];
    }
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    if (_mode == ISMSRecursiveItemLoaderModeFolder)
    {
        ISMSFolderLoader *folderLoader = (id)theLoader;
        [_tempFolders addObjectsFromArraySafe:folderLoader.folders];
        [_tempSongs addObjectsFromArraySafe:folderLoader.songs];
        
        // Remove the processed folder from array
        [_tempFolderIds removeObjectAtIndexSafe:0];
        
        for (ISMSFolder *folder in folderLoader.folders)
        {
            [_tempFolderIds addObjectSafe:folder.folderId];
        }

        // Continue to the next iteration
        [self continueLoading];
    }
}

@end
*/
