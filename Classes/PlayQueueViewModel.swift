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
    private var songs = ArraySlice<ISMSSong>()
    
    private(set) var currentSong: ISMSSong?
    var numberOfTableViewRows: Int {
        return songs.count
    }
    
    override init() {
        super.init()
        
        reloadSongs()
        
        // Rather than loading the songs list all the time,
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewModel.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewModel.playQueueIndexChanged(_:)), name: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    @objc private func playlistChanged(notification: NSNotification) {
        if let userInfo = notification.userInfo, playlistId = userInfo[Playlist.Notifications.playlistIdKey] as? Int {
            if playlistId == playlist.playlistId {
                reloadSongs()
            }
        }
    }
    
    @objc private func playQueueIndexChanged(notification: NSNotification) {
        reloadSongs()
    }
    
    private func reloadSongs() {
        var allSongs = self.playlist.songs
        let allSongsCount = allSongs.count
        let currentIndex = PlayQueue.sharedInstance.currentIndex
        if allSongsCount > currentIndex {
            currentSong = allSongs[currentIndex]
            if allSongsCount > currentIndex + 1 {
                songs = allSongs[currentIndex + 1...allSongsCount - 1]
            } else {
                songs = ArraySlice<ISMSSong>()
            }
        }
        
        delegate?.itemsChanged()
    }
    
    func songForTableViewIndex(index: Int) -> ISMSSong {
        let startIndex = songs.startIndex
        let song = songs[startIndex + index]
        return song
    }
    
    func playSongAtTableViewIndex(index: Int) {
        let startIndex = songs.startIndex
        PlayQueue.sharedInstance.playSongAtIndex(startIndex + index)
    }
}