//
//  PlayQueueViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/18/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

protocol PlayQueueViewModelDelegate {
    func itemsChanged()
    func currentIndexChanged()
    func currentSongChanged()
}

class PlayQueueViewModel: NSObject {
    
    var delegate: PlayQueueViewModelDelegate?
    
    var numberOfRows: Int {
        return songs.count
    }
    
    fileprivate var songs = [ISMSSong]()
    
    fileprivate(set) var currentIndex: Int = -1
    
    fileprivate(set) var currentSong: ISMSSong?
    
    override init() {
        super.init()
        
        reloadSongs()
        
        // Rather than loading the songs list all the time,
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(playQueueIndexChanged(_:)), name: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    @objc fileprivate func playlistChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo, let playlistId = userInfo[Playlist.Notifications.playlistIdKey] as? Int {
            if playlistId == Playlist.playQueuePlaylistId {
                self.reloadSongs()
                self.delegate?.itemsChanged()
            }
        }
    }
    
    @objc fileprivate func playQueueIndexChanged(_ notification: Notification) {
        reloadSongs()
        self.delegate?.itemsChanged()
    }
    
    fileprivate func reloadSongs() {
        songs = PlayQueue.si.songs
        let oldIndex = currentIndex
        currentIndex = PlayQueue.si.currentIndex
        let oldSong = currentSong
        currentSong = PlayQueue.si.currentSong
        
        if currentIndex != oldIndex {
            delegate?.currentIndexChanged()
        }
        
        if let oldSong = oldSong, let currentSong = currentSong, !oldSong.isEqual(to: currentSong) {
            delegate?.currentSongChanged()
        } else if (oldSong == nil && currentSong != nil) || (oldSong != nil && currentSong == nil) {
            delegate?.currentSongChanged()
        }
    }
    
    func song(atIndex index: Int) -> ISMSSong {
        return songs[index]
    }
    
    func playSong(atIndex index: Int) {
        PlayQueue.si.playSong(atIndex: index)
    }
    
    func insertSong(_ song: ISMSSong, atIndex index: Int) {
        PlayQueue.si.insertSong(song: song, index: index, notify: false)
        reloadSongs()
    }
    
    func moveSong(fromIndex: Int, toIndex: Int) {
        PlayQueue.si.moveSong(fromIndex: fromIndex, toIndex: toIndex, notify: false)
        reloadSongs()
    }
    
    func removeSong(atIndex index: Int) {
        PlayQueue.si.removeSong(atIndex: index)
        reloadSongs()
    }
    
    func clearPlayQueue() {
        PlayQueue.si.reset()
        reloadSongs()
        self.delegate?.itemsChanged()
    }
}
