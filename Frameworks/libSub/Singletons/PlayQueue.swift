//
//  PlayQueue.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MediaPlayer
import Async

@objc public enum RepeatMode: Int {
    case normal
    case repeatOne
    case repeatAll
}

@objc public enum ShuffleMode: Int {
    case normal
    case shuffle
}

@objc open class PlayQueue: NSObject {
    
    //
    // MARK: - Notifications -
    //
    
    // TODO: Make these available in Obj-C
    public struct Notifications {
        public static let playQueueIndexChanged = ISMSNotification_CurrentPlaylistIndexChanged
    }
    
    fileprivate func notifyPlayQueueIndexChanged() {
        NotificationCenter.postNotificationToMainThread(withName: PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    fileprivate func registerForNotifications() {
        // Watch for changes to the play queue playlist
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueue.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserver(onMainThread: self, name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    @objc fileprivate func playlistChanged(_ notification: Notification) {
        
    }
    
    //
    // MARK: - Properties -
    //
    
    open static let sharedInstance = PlayQueue()
    
    open var repeatMode = RepeatMode.normal
    open var shuffleMode = ShuffleMode.normal { didSet { /* TODO: Do something */ } }
    
    open fileprivate(set) var currentIndex = 0 { didSet { updateLockScreenInfo(); notifyPlayQueueIndexChanged() } }
    open var previousIndex: Int { return indexAtOffset(-1, fromIndex: currentIndex) }
    open var nextIndex: Int { return indexAtOffset(1, fromIndex: currentIndex) }
    open var currentDisplaySong: ISMSSong? { return currentSong ?? previousSong }
    open var currentSong: ISMSSong? { return playlist.songAtIndex(currentIndex) }
    open var previousSong: ISMSSong? { return playlist.songAtIndex(previousIndex) }
    open var nextSong: ISMSSong? { return playlist.songAtIndex(nextIndex) }
    open var songCount: Int { return playlist.songCount }
    open var isPlaying: Bool { return audioEngine.isPlaying() }
    open var isStarted: Bool { return audioEngine.isStarted() }
    open var currentSongProgress: Double { return audioEngine.progress() }
    open var songs: [ISMSSong] { return playlist.songs }
    open var playlist: Playlist { return Playlist.playQueue }
    
    fileprivate var audioEngine: AudioEngine { return AudioEngine.sharedInstance() }
    
    //
    // MARK: - Play Queue -
    //
    
    open func reset() {
        playlist.removeAllSongs()
        audioEngine.stop()
    }
    
    open func removeSongsAtIndexes(_ indexes: IndexSet) {
        // Stop the music if we're removing the current song
        let containsCurrentIndex = indexes.contains(currentIndex)
        if containsCurrentIndex {
            audioEngine.stop()
        }
        
        // Remove the songs
        playlist.removeSongsAtIndexes(indexes)
        
        // Adjust the current index if songs are removed below it
        let range = NSMakeRange(0, currentIndex)
        let countOfIndexesBelowCurrent = indexes.count(in: range.toRange() ?? 0..<0)
        currentIndex = currentIndex - countOfIndexesBelowCurrent
        
        // If we removed the current song, start the next one
        if containsCurrentIndex {
            playSongAtIndex(currentIndex)
        }
    }
    
    open func insertSong(song: ISMSSong, index: Int, notify: Bool = false) {
        playlist.insertSong(song: song, index: index, notify: notify)
        ISMSStreamManager.sharedInstance().fillStreamQueue(self.audioEngine.isStarted())
    }
    
    open func moveSong(fromIndex: Int, toIndex: Int, notify: Bool = false) {
        if playlist.moveSong(fromIndex: fromIndex, toIndex: toIndex, notify: notify) {
            if fromIndex == currentIndex && toIndex < currentIndex {
                // Moved the current song to a lower index
                currentIndex = toIndex
            } else if fromIndex == currentIndex && toIndex > currentIndex {
                // Moved the current song to a higher index
                currentIndex = toIndex - 1
            } else if fromIndex > currentIndex && toIndex <= currentIndex {
                // Moved a song from after the current song to before
                currentIndex += 1
            } else if fromIndex < currentIndex && toIndex >= currentIndex {
                // Moved a song from before the current song to after
                currentIndex -= 1
            }
            
            ISMSStreamManager.sharedInstance().fillStreamQueue(self.audioEngine.isStarted())
        }
    }
    
    open func songAtIndex(_ index: Int) -> ISMSSong? {
        return playlist.songAtIndex(index)
    }
    
    open func indexAtOffset(_ offset: Int, fromIndex: Int) -> Int {
        switch repeatMode {
        case .normal:
            if offset >= 0 {
                if fromIndex + offset > songCount {
                    // If we're past the end of the play queue, always return the last index + 1
                    return songCount
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : 0;
            }
        case .repeatAll:
            if offset >= 0 {
                if fromIndex + offset >= songCount {
                    let remainder = offset - (songCount - fromIndex)
                    return indexAtOffset(remainder, fromIndex: 0)
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : songCount + fromIndex + offset;
            }
        case .repeatOne:
            return fromIndex
        }
    }
    
    open func indexAtOffsetFromCurrentIndex(_ offset: Int) -> Int {
        return indexAtOffset(offset, fromIndex: self.currentIndex)
    }
    
    //
    // MARK: - Player Control -
    //
    
    open func playSongs(_ songs: [ISMSSong], playIndex: Int) {
        reset()
        playlist.addSongs(songs: songs)
        playSongAtIndex(playIndex)
    }
    
    open func playSongAtIndex(_ index: Int) {
        currentIndex = index
        if let currentSong = currentSong {
            if currentSong.contentType?.basicType != .video {
                // Remove the video player if this is not a video
                NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_RemoveMoviePlayer)
            }
            
            if SavedSettings.sharedInstance().isJukeboxEnabled {
                if currentSong.contentType?.basicType == .video {
                    EX2SlidingNotification.slidingNotificationOnMainWindow(withMessage: "Cannot play videos in Jukebox mode.", image: nil)
                } else {
                    JukeboxSingleton.sharedInstance().jukeboxPlaySong(atPosition: index as NSNumber!)
                }
            } else {
                ISMSStreamManager.sharedInstance().removeAllStreamsExcept(for: currentSong)
                
                if currentSong.contentType?.basicType == .video {
                    NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_PlayVideo, userInfo: ["song": currentSong])
                } else {
                    startSong()
                }
            }
        }
    }

    open func playPreviousSong() {
        if audioEngine.progress() > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            playSongAtIndex(self.currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            playSongAtIndex(self.previousIndex)
        }
    }
    
    open func playNextSong() {
        playSongAtIndex(self.nextIndex)
    }
    
    open func play() {
        audioEngine.play()
    }
    
    open func pause() {
        audioEngine.pause()
    }
    
    open func playPause() {
        audioEngine.playPause()
    }
    
    open func stop() {
        audioEngine.stop()
    }
    
    open func startSong() {
        startSong(offsetBytes: 0, offsetSeconds: 0)
    }
    
    fileprivate var startSongDelayTimer: Timer?
    open func startSong(offsetBytes: Int, offsetSeconds: Int) {
        let work = {
            if let startSongDelayTimer = self.startSongDelayTimer {
                startSongDelayTimer.invalidate()
                self.startSongDelayTimer = nil
            }
            
            // Destroy the streamer to start a new song
            self.audioEngine.stop()
            
            if self.currentSong != nil {
                // Only start the caching process if it's been a half second after the last request
                // Prevents crash when skipping through playlist fast
                self.startSongDelayTimer = Timer.scheduledTimer(timeInterval: 0.6, target: self, selector: #selector(PlayQueue.startSongWithByteAndSecondsOffset(_:)), userInfo: ["bytes": offsetBytes, "seconds": offsetSeconds], repeats: false)
            }
        }
        
        // Only allowed to manipulate BASS from the main thread
        if Thread.isMainThread {
            work()
        } else {
            EX2Dispatch.run(inMainThreadAsync: work)
        }
    }
    
    open func startSongWithByteAndSecondsOffset(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: AnyObject] else {
            return
        }
        
        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_RemoveMoviePlayer)
        
        if let currentSong = currentSong {
            let settings = SavedSettings.sharedInstance()
            let streamManager = ISMSStreamManager.sharedInstance()
            let cacheQueueManager = ISMSCacheQueueManager.sharedInstance()
            let offsetBytes = userInfo["bytes"] as? NSNumber
            let offsetSeconds = userInfo["seconds"] as? NSNumber
            let audioEngineStartSong = {
                if let bytes = offsetBytes?.intValue {
                    self.audioEngine.start(currentSong, index: self.currentIndex, offsetInBytes: bytes)
                } else if let seconds = offsetSeconds?.intValue {
                    self.audioEngine.start(currentSong, index: self.currentIndex, offsetInSeconds: seconds)
                }
            }
            
            // Check to see if the song is already cached
            if currentSong.isFullyCached {
                // The song is fully cached, start streaming from the local copy
                audioEngineStartSong()
            } else {
                // Fill the stream queue
                if !settings.isOfflineMode {
                    streamManager.fillStreamQueue(true)
                } else if !currentSong.isFullyCached && settings.isOfflineMode {
                    // TODO: Prevent this running forever in RepeatAll mode with no songs available
                    self.playSongAtIndex(nextIndex)
                } else {
                    if (cacheQueueManager?.currentQueuedSong.isEqual(to: currentSong))! {
                        // The cache queue is downloading this song, remove it before continuing
                        cacheQueueManager?.removeCurrentSong()
                    }
                    
                    if streamManager.isSongDownloading(currentSong) {
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handler(for: currentSong) {
                            if !audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else if streamManager.isSongFirst(inQueue: currentSong) && !streamManager.isQueueDownloading {
                        // The song is first in queue, but the queue is not downloading. Probably the song was downloading
                        // when the app quit. Resume the download and start the player
                        streamManager.resumeQueue()
                        
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handler(for: currentSong) {
                            if !self.audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else {
                        // Clear the stream manager
                        streamManager.removeAllStreams()
                        
                        var isTempCache = false
                        if let offsetBytes = offsetBytes {
                            if offsetBytes.intValue > 0 || !settings.isSongCachingEnabled {
                                isTempCache = true
                            }
                        }
                        
                        let bytes = offsetBytes?.uint64Value ?? 0
                        let seconds = offsetSeconds?.doubleValue ?? 0
                        
                        // Start downloading the current song from the correct offset
                        streamManager.queueStream(for: currentSong, byteOffset: bytes, secondsOffset: seconds, at: 0, isTempCache: isTempCache, isStartDownload: true)
                        
                        // Fill the stream queue
                        if settings.isSongCachingEnabled {
                            streamManager.fillStreamQueue(self.audioEngine.isStarted())
                        }
                    }
                }
            }
        }
    }
    
    //
    // MARK: - Lock Screen -
    //
    
    fileprivate var lockScreenUpdateTimer: Timer?
    open func updateLockScreenInfo() {
        #if os(iOS)
            var trackInfo = [String: AnyObject]()
            if let song = self.currentSong {
                if let title = song.title {
                    trackInfo[MPMediaItemPropertyTitle] = title as AnyObject?
                }
                if let albumName = song.album?.name {
                    trackInfo[MPMediaItemPropertyAlbumTitle] = albumName as AnyObject?
                }
                if let artistName = song.artistDisplayName {
                    trackInfo[MPMediaItemPropertyArtist] = artistName as AnyObject?
                }
                if let genre = song.genre?.name {
                    trackInfo[MPMediaItemPropertyGenre] = genre as AnyObject?
                }
                if let duration = song.duration {
                    trackInfo[MPMediaItemPropertyPlaybackDuration] = duration
                }
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = songCount as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.progress() as AnyObject?
                trackInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0 as AnyObject?
                
                if SavedSettings.sharedInstance().isLockScreenArtEnabled {
                    if let coverArtId = song.coverArtId {
                        let artDataModel = SUSCoverArtDAO(delegate: nil, coverArtId: coverArtId, isLarge: true)
                        trackInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: (artDataModel?.coverArtImage())!)
                    }
                }
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = trackInfo
            }
            
            // Run this every 30 seconds to update the progress and keep it in sync
            if let lockScreenUpdateTimer = self.lockScreenUpdateTimer {
                lockScreenUpdateTimer.invalidate()
            }
            lockScreenUpdateTimer = Timer(timeInterval: 30.0, target: self, selector: #selector(PlayQueue.updateLockScreenInfo), userInfo: nil, repeats: false)
        #endif
    }
}

extension PlayQueue: BassGaplessPlayerDelegate {
    
    public func bassFirstStreamStarted(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassSongEndedCalled(_ player: BassGaplessPlayer) {
        // Increment current playlist index
        currentIndex = nextIndex
        
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassFreed(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }

    public func bassIndex(atOffset offset: Int, from index: Int, player: BassGaplessPlayer) -> Int {
        return indexAtOffset(offset, fromIndex: index)
    }
    
    public func bassSong(for index: Int, player: BassGaplessPlayer) -> ISMSSong? {
        return songAtIndex(index)
    }
    
    public func bassCurrentPlaylistIndex(_ player: BassGaplessPlayer) -> Int {
        return currentIndex
    }
    
    public func bassRetrySong(at index: Int, player: BassGaplessPlayer) {
        Async.main {
            self.playSongAtIndex(index)
        }
    }
    
    public func bassUpdateLockScreenInfo(_ player: BassGaplessPlayer) {
        updateLockScreenInfo()
    }
    
    public func bassRetrySongAtOffset(inBytes bytes: Int, andSeconds seconds: Int, player: BassGaplessPlayer) {
        startSong(offsetBytes: bytes, offsetSeconds: seconds)
    }
    
    public func bassFailedToCreateNextStream(for index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        if let song = self.songAtIndex(index), let handler = ISMSStreamManager.sharedInstance().handler(for: song) {
            if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
                // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                Async.main {
                    self.playSongAtIndex(index)
                }
            }
        }
    }
    
    public func bassRetrievingOutputData(_ player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerHandleSocial()
    }
}
