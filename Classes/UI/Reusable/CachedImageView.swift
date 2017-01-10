//
//  CachedImageView.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit
import Nuke

class CachedImageView: UIImageView {
    func setDefaultImage(forSize size: CachedImageSize) {
        self.image = CachedImage.default(forSize: size)
    }
    
    func loadImage(coverArtId: String, size: CachedImageSize) {
        setDefaultImage(forSize: size)
        
        let request = CachedImage.request(coverArtId: coverArtId, size: size)
        Nuke.loadImage(with: request, into: self)
    }
    
    func cancelLoading() {
        Nuke.cancelRequest(for: self)
    }
}
