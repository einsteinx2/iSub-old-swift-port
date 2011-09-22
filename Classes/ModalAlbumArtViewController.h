//
//  ModalAlbumArtViewController.h
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class AsynchronousImageView, Album;

@interface ModalAlbumArtViewController : UIViewController 
{
	AsynchronousImageView *albumArt;
}

@property (nonatomic, retain) AsynchronousImageView *albumArt;

- (id)initWithAlbum:(Album*)theAlbum;

@end
