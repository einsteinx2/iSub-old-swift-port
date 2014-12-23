//
//  ModalAlbumArtViewController.swift
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class ModalAlbumArtViewController: UIViewController, AsynchronousImageViewDelegate {
    
    private let _settings = SavedSettings.sharedInstance()
    
    @IBOutlet public var albumArt: AsynchronousImageView?
    @IBOutlet public var albumArtReflection: UIImageView?
    @IBOutlet public var labelHolderView: UIView?
    @IBOutlet public var artistLabel: UILabel?
    @IBOutlet public var albumLabel: UILabel?
    @IBOutlet public var durationLabel: UILabel?
    @IBOutlet public var trackCountLabel: UILabel?
    public var myAlbum: ISMSAlbum?
    private var _numberOfTracks: Int?
    private var _albumLength: Int?
    
    // MARK: - Rotation -
    
    public override func shouldAutorotate() -> Bool {
        if _settings.isRotationLockEnabled && UIDevice.currentDevice().orientation != UIDeviceOrientation.Portrait {
            return false
        }
        
        return true
    }
    
    public override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        if !IS_IPAD() {
            
            UIView.animateWithDuration(duration, animations: {
                var frame = self.albumArt!.frame
                if UIInterfaceOrientationIsLandscape(toInterfaceOrientation) {
                    frame.size.width = 480.0
                    frame.size.height = 320.0
                    self.labelHolderView?.alpha = 0.0
                } else {
                    frame.size.width = 320.0
                    frame.size.height = 320.0
                    self.labelHolderView?.alpha = 1.0;
                }
                self.albumArt!.frame = frame
            })
            
            UIApplication.sharedApplication().setStatusBarHidden(UIInterfaceOrientationIsLandscape(toInterfaceOrientation), withAnimation: UIStatusBarAnimation.Slide)
        }
    }
    
    // MARK: - Life Cycle -
    
    public override init() {
        super.init(nibName: "ModalAlbumArtViewController", bundle: nil)
        self.modalPresentationStyle = UIModalPresentationStyle.FormSheet;
    }
    
    public init(album: ISMSAlbum, numberOfTracks: Int, albumLength: Int) {
        myAlbum = album
        _numberOfTracks = numberOfTracks
        _albumLength = albumLength
        
        super.init(nibName: "ModalAlbumArtViewController", bundle: nil)
        
        self.modalPresentationStyle = UIModalPresentationStyle.FormSheet;
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.modalPresentationStyle = UIModalPresentationStyle.FormSheet;
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.modalPresentationStyle = UIModalPresentationStyle.FormSheet;
    }
    
    public override func viewDidLoad() {
        if IS_IPAD() {
            // Fix album art size for iPad
            albumArt!.width = 540.0
            albumArt!.height = 540.0
            albumArtReflection!.y = 540.0
            albumArtReflection!.width = 540.0
            labelHolderView!.height = 125.0
            labelHolderView!.y = 500.0
        }
    
        albumArt!.isLarge = true
        albumArt!.delegate = self
        
        artistLabel!.text = myAlbum?.artistName
        albumLabel!.text = myAlbum?.title
        durationLabel!.text = NSString.formatTime(Double(_albumLength!))
        trackCountLabel!.text = "\(_numberOfTracks) Tracks"
        if _numberOfTracks == 1 {
            trackCountLabel!.text = "\(_numberOfTracks) Track"
        }
        
        albumArt!.coverArtId = myAlbum!.coverArtId;
    
        albumArtReflection!.image = albumArt!.reflectedImageWithHeight(albumArtReflection!.height)
    
        if (!IS_IPAD()) {
            if UIInterfaceOrientationIsLandscape(self.interfaceOrientation) {
                UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: UIStatusBarAnimation.Slide)
                albumArt!.width = 480.0
            } else {
                UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: UIStatusBarAnimation.Slide)
            }
        }
    }
    
    // MARK: - Actions -
    
    @IBAction public func dismiss(sender: UIButton) {
        if !IS_IPAD() {
            UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: UIStatusBarAnimation.Slide)
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK - AsynchronousImageView Delegate -
    
    public func asyncImageViewFinishedLoading(asyncImageView: AsynchronousImageView!) {
        albumArtReflection!.image = albumArt!.reflectedImageWithHeight(albumArtReflection!.height)
    }
}
