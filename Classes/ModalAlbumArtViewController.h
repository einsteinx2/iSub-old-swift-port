//
//  ModalAlbumArtViewController.h
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class AsynchronousImageView, Album;

@interface ModalAlbumArtViewController : UIViewController 

@property (nonatomic, retain) IBOutlet AsynchronousImageView *albumArt;
@property (nonatomic, retain) IBOutlet UIView *labelHolderView;
@property (nonatomic, retain) IBOutlet UILabel *artistLabel; 
@property (nonatomic, retain) IBOutlet UILabel *albumLabel;
@property (nonatomic, retain) IBOutlet UILabel *durationLabel;
@property (nonatomic, retain) IBOutlet UILabel *trackCountLabel;

@property (nonatomic, copy) Album *myAlbum;
@property NSUInteger numberOfTracks;
@property NSUInteger albumLength;

- (id)initWithAlbum:(Album *)theAlbum numberOfTracks:(NSUInteger)numTracks albumLength:(NSUInteger)length;
- (IBAction)dismiss:(id)sender;

@end
