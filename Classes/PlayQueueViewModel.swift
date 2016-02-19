//
//  PlayQueueViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/18/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import libSub
import Foundation

protocol PlayQueueViewModelDelegate {
    func itemsChanged()
}

class PlayQueueViewModel: NSObject {
    
    var delegate: PlayQueueViewModelDelegate?
    
    private let playlist = Playlist.playQueue
    
    var songs = [ISMSSong]()
    
    override init() {
        super.init()
        
        self.songs = playlist.songs
        
        // Rather than loading the songs list all the time,
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playQueueChanged:", name: Playlist.playlistChangedNotificationName, object: nil)
    }
    
    func playQueueChanged(notification: NSNotification) {
        // Reload the songs
        self.songs = self.playlist.songs
        
        // Inform the delegate
        self.delegate?.itemsChanged()
    }
}