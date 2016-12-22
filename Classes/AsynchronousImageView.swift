//
//  AsynchronousImageView.swift
//  iSub
//
//  Created by Benjamin Baron on 6/16/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

@objc protocol AsynchronousImageViewDelegate {
    func asyncImageViewFinishedLoading(_ asyncImageView: AsynchronousImageView)
    func asyncImageViewLoadingFailed(_ asyncImageView: AsynchronousImageView, error: Error)
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
    
    fileprivate var activityIndicator: UIActivityIndicatorView?
    
    init() {
        super.init(frame: CGRect.zero)
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
    
    fileprivate func reloadCoverArt() {
        // Make sure old activity indicator is gone
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil;
        
        if let coverArtDAO = coverArtDAO {
            coverArtDAO.cancelLoad()
            coverArtDAO.delegate = nil
        }
        coverArtDAO = nil
        
        self.image = SUSCoverArtDAO.defaultCoverArtImage(forSize: large)
        
        if let coverArtId = coverArtId {
            coverArtDAO = SUSCoverArtDAO(delegate: self, coverArtId: coverArtId, isLarge: large)
            if coverArtDAO!.isCoverArtCached {
                self.image = coverArtDAO!.coverArtImage()
            } else if large {
                activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
                activityIndicator!.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
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
    
    func loadingFinished(_ theLoader: ISMSLoader) {
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        image = coverArtDAO?.coverArtImage()
        coverArtDAO = nil
        
        if let delegate = delegate {
            delegate.asyncImageViewFinishedLoading(self)
        }
    }
    
    public func loadingFailed(_ theLoader: ISMSLoader, withError error: Error) {
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
    
    @objc fileprivate func oneTap() {
        
    }
    
    @objc fileprivate func twoTaps() {
        
    }
    
    @objc fileprivate func threeTaps() {
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            switch touch.tapCount {
            case 1:
                self.perform(#selector(AsynchronousImageView.oneTap), with: nil, afterDelay: 0.5)
            case 2:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(AsynchronousImageView.oneTap), object: nil)
                self.perform(#selector(AsynchronousImageView.twoTaps), with: nil, afterDelay: 0.5)
            case 3:
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(AsynchronousImageView.twoTaps), object: nil)
                self.perform(#selector(AsynchronousImageView.threeTaps), with: nil, afterDelay: 0.5)
            default:
                break
            }
        }
    }
}
