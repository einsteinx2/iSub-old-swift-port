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
    var numberOfRows: Int {
        return songs.count
    }
    
    private var songs = [ISMSSong]()
    private(set) var currentIndex: Int = -1
    private(set) var currentSong: ISMSSong?
    
    override init() {
        super.init()
        
        reloadSongs(notifyDelegate: false)
        
        // Rather than loading the songs list all the time,
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewModel.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewModel.playQueueIndexChanged(_:)), name: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    @objc private func playlistChanged(notification: NSNotification) {
        if let userInfo = notification.userInfo, playlistId = userInfo[Playlist.Notifications.playlistIdKey] as? Int {
            if playlistId == Playlist.playQueuePlaylistId {
                reloadSongs(notifyDelegate: true)
            }
        }
    }
    
    @objc private func playQueueIndexChanged(notification: NSNotification) {
        reloadSongs(notifyDelegate: true)
    }
    
    private func reloadSongs(notifyDelegate notifyDelegate: Bool) {
        let playQueue = PlayQueue.sharedInstance
        songs = playQueue.songs
        currentSong = playQueue.currentSong
        currentIndex = playQueue.currentIndex
        
        if notifyDelegate {
            delegate?.itemsChanged()
        }
    }
    
    func songAtIndex(index: Int) -> ISMSSong {
        return songs[index]
    }
    
    func playSongAtIndex(index: Int) {
        PlayQueue.sharedInstance.playSongAtIndex(index)
    }
    
    func insertSongAtIndex(index: Int, song: ISMSSong) {
        PlayQueue.sharedInstance.playlist.insertSong(song: song, index: index)
    }
    
    func moveSong(fromIndex fromIndex: Int, toIndex: Int) {
        PlayQueue.sharedInstance.moveSong(fromIndex: fromIndex, toIndex: toIndex)
        reloadSongs(notifyDelegate: false)
    }
}