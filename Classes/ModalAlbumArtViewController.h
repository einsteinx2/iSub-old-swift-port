//
//  ModalAlbumArtViewController.h
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class AsynchronousImageView, Album;

@interface ModalAlbumArtViewController : UIViewController 

@property (retain) IBOutlet AsynchronousImageView *albumArt;
@property (retain) IBOutlet UIImageView *albumArtReflection;
@property (retain) IBOutlet UIView *labelHolderView;
@property (retain) IBOutlet UILabel *artistLabel; 
@property (retain) IBOutlet UILabel *albumLabel;
@property (retain) IBOutlet UILabel *durationLabel;
@property (retain) IBOutlet UILabel *trackCountLabel;

@property (copy) Album *myAlbum;
@property NSUInteger numberOfTracks;
@property NSUInteger albumLength;

- (id)initWithAlbum:(Album *)theAlbum numberOfTracks:(NSUInteger)numTracks albumLength:(NSUInteger)length;
- (IBAction)dismiss:(id)sender;

@end
