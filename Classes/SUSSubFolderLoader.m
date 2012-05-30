//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderLoader.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueueAdditions.h"
#import "TBXML.h"
#import "DatabaseSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "Album.h"
#import "Song.h"
#import "Artist.h"
#import "NSString+md5.h"

@implementation SUSSubFolderLoader
@synthesize myId, myArtist, albumsCount, songsCount, folderLength;

#pragma mark - Lifecycle

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_SubFolders;
}

#pragma mark - Private DB Methods

- (BOOL)resetDb
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//Initialize the arrays.
		[db beginTransaction];
		[db executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", [myId md5]];
		[db executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", [myId md5]];
		[db executeUpdate:@"DELETE FROM albumsCacheCount WHERE folderId = ?", [myId md5]];
		[db executeUpdate:@"DELETE FROM songsCacheCount WHERE folderId = ?", [myId md5]];
		[db executeUpdate:@"DELETE FROM folderLength WHERE folderId = ?", [myId md5]];
		[db commit];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertAlbumIntoFolderCache:(Album *)anAlbum
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [myId md5], [anAlbum.title cleanString], anAlbum.albumId, anAlbum.coverArtId, [anAlbum.artistName cleanString], anAlbum.artistId];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertSongIntoFolderCache:(Song *)aSong
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//DLog(@"aSong.title: %@  clean: %@", aSong.title, [aSong.title cleanString]);
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [Song standardSongColumnNames], [Song standardSongColumnQMarks]], [myId md5], [aSong.title cleanString], aSong.songId, [aSong.artist cleanString], [aSong.album cleanString], [aSong.genre cleanString], aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size, aSong.parentId];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbumsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCacheCount (folderId, count) VALUES (?, ?)", [myId md5], [NSNumber numberWithInt:albumsCount]];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting album count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertSongsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO songsCacheCount (folderId, count) VALUES (?, ?)", [myId md5], [NSNumber numberWithInt:songsCount]];
		
		hadError = [db hadError];
		if (hadError)
			DLog(@"Err inserting song count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    	
	return !hadError;
}

- (BOOL)insertFolderLength
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO folderLength (folderId, length) VALUES (?, ?)", [myId md5], [NSNumber numberWithInt:folderLength]];
		
		hadError = [db hadError];
		if ([db hadError])
			DLog(@"Err inserting folder length %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
   
	return !hadError;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.myId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{   	
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	            
	//DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
    // Parse the data
	//
	NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		[self informDelegateLoadingFailed:error];
	}
	else
    {
		TBXMLElement *root = tbxml.rootXMLElement;

		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
		}
		else
		{
			TBXMLElement *directory = [TBXML childElementNamed:@"directory" parentElement:root];
			if (directory)
			{
                [self resetDb];
                albumsCount = 0;
                songsCount = 0;
                folderLength = 0;
                
                // Loop through the chat messages
				TBXMLElement *child = [TBXML childElementNamed:@"child" parentElement:directory];
				while (child != nil)
				{
					@autoreleasepool 
					{
						if ([[TBXML valueOfAttributeNamed:@"isDir" forElement:child] boolValue])
						{
							Album *anAlbum = [[Album alloc] initWithTBXMLElement:child artistId:myArtist.artistId artistName:myArtist.name];
							if (![anAlbum.title isEqualToString:@".AppleDouble"])
							{
								[self insertAlbumIntoFolderCache:anAlbum];
								albumsCount++;
							}
						}
						else
						{
							BOOL isVideo = [[TBXML valueOfAttributeNamed:@"isVideo" forElement:child] boolValue]; 
							if (!isVideo)
							{
								Song *aSong = [[Song alloc] initWithTBXMLElement:child];
								if (aSong.path)
								{
									[self insertSongIntoFolderCache:aSong];
									songsCount++;
									folderLength += [aSong.duration intValue];
								}
							}
						}
						
						// Get the next message
						child = [TBXML nextSiblingNamed:@"child" searchFromElement:child];
					}
				}
                
                [self insertAlbumsCount];
                [self insertSongsCount];
                [self insertFolderLength];
			}
            else
            {
                // TODO create error
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:nil];
            }
		}
	}
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}

@end
