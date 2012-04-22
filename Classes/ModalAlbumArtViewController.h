//
//  ModalAlbumArtViewController.h
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AsynchronousImageViewDelegate.h"

@class AsynchronousImageView, Album;

@interface ModalAlbumArtViewController : UIViewController <AsynchronousImageViewDelegate>

@property (strong) IBOutlet AsynchronousImageView *albumArt;
@property (strong) IBOutlet UIImageView *albumArtReflection;
@property (strong) IBOutlet UIView *labelHolderView;
@property (strong) IBOutlet UILabel *artistLabel; 
@property (strong) IBOutlet UILabel *albumLabel;
@property (strong) IBOutlet UILabel *durationLabel;
@property (strong) IBOutlet UILabel *trackCountLabel;

@property (copy) Album *myAlbum;
@property NSUInteger numberOfTracks;
@property NSUInteger albumLength;

- (id)initWithAlbum:(Album *)theAlbum numberOfTracks:(NSUInteger)numTracks albumLength:(NSUInteger)length;
- (IBAction)dismiss:(id)sender;

@end
