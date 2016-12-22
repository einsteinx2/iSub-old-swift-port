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
        
        reloadSongs(notifyDelegate: false)
        
        // Rather than loading the songs list all the time,
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewModel.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewModel.playQueueIndexChanged(_:)), name: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    @objc fileprivate func playlistChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo, let playlistId = userInfo[Playlist.Notifications.playlistIdKey] as? Int {
            if playlistId == Playlist.playQueuePlaylistId {
                reloadSongs(notifyDelegate: true)
            }
        }
    }
    
    @objc fileprivate func playQueueIndexChanged(_ notification: Notification) {
        reloadSongs(notifyDelegate: true)
    }
    
    fileprivate func reloadSongs(notifyDelegate: Bool) {
        let playQueue = PlayQueue.sharedInstance
        songs = playQueue.songs
        currentSong = playQueue.currentSong
        currentIndex = playQueue.currentIndex
        
        if notifyDelegate {
            delegate?.itemsChanged()
        }
    }
    
    func songAtIndex(_ index: Int) -> ISMSSong {
        return songs[index]
    }
    
    func playSongAtIndex(_ index: Int) {
        PlayQueue.sharedInstance.playSongAtIndex(index)
    }
    
    func insertSongAtIndex(_ index: Int, song: ISMSSong) {
        PlayQueue.sharedInstance.insertSong(song: song, index: index, notify: false)
        reloadSongs(notifyDelegate: false)
    }
    
    func moveSong(fromIndex: Int, toIndex: Int) {
        PlayQueue.sharedInstance.moveSong(fromIndex: fromIndex, toIndex: toIndex, notify: false)
        reloadSongs(notifyDelegate: false)
    }
}
