//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongSmallUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"

@implementation CurrentPlaylistSongSmallUITableViewCell

@synthesize indexPath, deleteToggleImage, isDelete, numberLabel, songNameLabel, artistNameLabel, durationLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		
		self.backgroundView.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		[deleteToggleImage release];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = UITextAlignmentCenter;
		numberLabel.textColor = [UIColor whiteColor];
		numberLabel.font = [UIFont boldSystemFontOfSize:24];
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumFontSize = 12;
		[self.contentView addSubview:numberLabel];
		[numberLabel release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.frame = CGRectMake(45, 0, 235, 30);
		songNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.textColor = [UIColor whiteColor];
		songNameLabel.font = [UIFont boldSystemFontOfSize:18];
		[self.contentView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.frame = CGRectMake(45, 27, 235, 15);
		artistNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.textColor = [UIColor whiteColor];
		artistNameLabel.font = [UIFont systemFontOfSize:12];
		[self.contentView addSubview:artistNameLabel];
		[artistNameLabel release];
		
		durationLabel = [[UILabel alloc] init];
		durationLabel.frame = CGRectMake(270, 0, 45, 41);
		durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		durationLabel.backgroundColor = [UIColor clearColor];
		durationLabel.textAlignment = UITextAlignmentRight; // default
		durationLabel.textColor = [UIColor whiteColor];
		durationLabel.font = [UIFont systemFontOfSize:16];
		durationLabel.adjustsFontSizeToFitWidth = YES;
		durationLabel.minimumFontSize = 12;
		[self.contentView addSubview:durationLabel];
		[durationLabel release];
	}
	
	return self;
}


- (void)toggleDelete
{
	if (deleteToggleImage.image == [UIImage imageNamed:@"unselected.png"])
	{
		[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showDeleteButton" object:nil];
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	else
	{
		[viewObjects.multiDeleteList removeObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"hideDeleteButton" object:nil];
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	deleteToggleImage.frame = CGRectMake(4, 11, 23, 23);
	numberLabel.frame = CGRectMake(2, 0, 40, 45);
	/*if (viewObjects.isEditing)
	{
		//NSLog(@"isEditing");
		self.songNameLabel.frame = CGRectMake(45, 0, 210, 30);
		self.artistNameLabel.frame = CGRectMake(45, 27, 210, 15);
	}
	else
	{
		//NSLog(@"!isEditing");
		self.songNameLabel.frame = CGRectMake(45, 0, 235, 30);
		self.artistNameLabel.frame = CGRectMake(45, 27, 235, 15);
	}
	self.durationLabel.frame = CGRectMake(270, 0, 45, 41);*/
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	if (viewObjects.isEditing)
		[super setEditing:editing animated:animated];
}


- (void)dealloc {
	[indexPath release];
	
	/*[numberLabel release];
	[songNameLabel release];
	[artistNameLabel release];*/
    [super dealloc];
}


@end
