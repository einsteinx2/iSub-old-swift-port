//
//  AsynchronousImageView.swift
//  iSub
//
//  Created by Benjamin Baron on 6/16/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

@objc protocol AsynchronousImageViewDelegate {
    func asyncImageViewFinishedLoading(asyncImageView: AsynchronousImageView)
    func asyncImageViewLoadingFailed(asyncImageView: AsynchronousImageView, error: NSError)
}

class AsynchronousImageView: UIImageView, ISMSLoaderDelegate {
    weak var delegate: AsynchronousImageViewDelegate?
    
    var coverArtId: String? {
        didSet {
            reloadCoverArt()
        }
    }
    var coverArtDAO: SUSCoverArtDAO?
    var large = false
    
    private var activityIndicator: UIActivityIndicatorView?
    
    init() {
        super.init(frame: CGRectZero)
    }
    
    init(frame: CGRect, coverArtId: String, large: Bool, delegate: AsynchronousImageViewDelegate) {
        super.init(frame: frame)
        
        self.coverArtId = coverArtId
        self.large = large
        self.delegate = delegate
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadCoverArt() {
        // Make sure old activity indicator is gone
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil;
        
        if let coverArtDAO = coverArtDAO {
            coverArtDAO.cancelLoad()
            coverArtDAO.delegate = nil
        }
        coverArtDAO = nil
        
        self.image = SUSCoverArtDAO.defaultCoverArtImageForSize(large)
        
        if let coverArtId = coverArtId {
            coverArtDAO = SUSCoverArtDAO(delegate: self, coverArtId: coverArtId, isLarge: large)
            if coverArtDAO!.isCoverArtCached {
                self.image = coverArtDAO!.coverArtImage()
            } else if large {
                activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
                activityIndicator!.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleTopMargin, .FlexibleBottomMargin]
                activityIndicator!.center = CGPoint(x: self.width / 2.0, y: self.height / 2.0)
                self.addSubview(activityIndicator!)
                activityIndicator?.startAnimating()
            }
            coverArtDAO!.startLoad()
        }
    }
    
    //
    // MARK: - Loading Delegate -
    //
    
    func loadingFinished(theLoader: ISMSLoader!) {
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        image = coverArtDAO?.coverArtImage()
        coverArtDAO = nil
        
        if let delegate = delegate {
            delegate.asyncImageViewFinishedLoading(self)
        }
    }
    
    func loadingFailed(theLoader: ISMSLoader!, withError error: NSError!) {
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        coverArtDAO = nil
        if let delegate = delegate {
            delegate.asyncImageViewLoadingFailed(self, error: error)
        }
    }
    
    //
    // MARK: - Touch Handling -
    //
    
    @objc private func oneTap() {
        
    }
    
    @objc private func twoTaps() {
        
    }
    
    @objc private func threeTaps() {
        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            switch touch.tapCount {
            case 1:
                self.performSelector(#selector(AsynchronousImageView.oneTap), withObject: nil, afterDelay: 0.5)
            case 2:
                NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(AsynchronousImageView.oneTap), object: nil)
                self.performSelector(#selector(AsynchronousImageView.twoTaps), withObject: nil, afterDelay: 0.5)
            case 3:
                NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(AsynchronousImageView.twoTaps), object: nil)
                self.performSelector(#selector(AsynchronousImageView.threeTaps), withObject: nil, afterDelay: 0.5)
            default:
                break
            }
        }
    }
}
