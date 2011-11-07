//
//  SUSServerPlaylist.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSServerPlaylist.h"

@implementation SUSServerPlaylist
@synthesize playlistId, playlistName;

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		playlistId = nil;
		playlistName = nil;
		
		if ([TBXML valueOfAttributeNamed:@"id" forElement:element])
			self.playlistId = [TBXML valueOfAttributeNamed:@"id" forElement:element];
		
		if ([TBXML valueOfAttributeNamed:@"name" forElement:element])
			self.playlistName = [TBXML valueOfAttributeNamed:@"name" forElement:element];
	}
	
	return self;
}

-(id)copyWithZone: (NSZone *) zone
{
    SUSServerPlaylist *playlist = [[SUSServerPlaylist alloc] init];
    playlist.playlistName = self.playlistName;
    playlist.playlistId = self.playlistId;
    return playlist;
}

- (NSComparisonResult)compare:(SUSServerPlaylist *)otherObject 
{
    return [self.playlistName caseInsensitiveCompare:otherObject.playlistName];
}

- (void)dealloc 
{
	[playlistId release]; playlistId = nil;
	[playlistName release]; playlistName = nil;
	[super dealloc];
}

@end
