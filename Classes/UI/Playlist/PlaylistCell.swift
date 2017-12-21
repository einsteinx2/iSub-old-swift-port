//
//  PlaylistCell.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/20/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit

class PlaylistCell: UICollectionViewCell {

    @IBOutlet private weak var playlistImage: CachedImageView!
    @IBOutlet private weak var playlistName: UILabel!
    
    func setup(playlistName: String, coverArtId: String?, serverId: Int64?) {
        self.playlistName.text = playlistName
        if let coverArtId = coverArtId, let serverId = serverId {
            playlistImage.loadImage(coverArtId: coverArtId, serverId: serverId, size: .cell)
        } else {
            playlistImage.setDefaultImage(forSize: .cell)
        }
    }

}
