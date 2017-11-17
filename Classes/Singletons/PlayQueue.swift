//
//  PlayQueue.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MediaPlayer
import Nuke

enum RepeatMode: Int {
    case normal    = 0
    case repeatOne = 1
    case repeatAll = 2
}

enum ShuffleMode: Int {
    case normal  = 0
    case shuffle = 1
}

final class PlayQueue {
    // MARK: - Notifications -
    
    struct Notifications {
        static let indexChanged = Notification.Name("PlayQueue_indexChanged")
        static let displayVideo = Notification.Name("PlayQueue_displayVideo")
        static let videoEnded = Notification.Name("PlayQueue_videoEnded")
        
        struct Keys {
            static let avPlayer = "avPlayer"
        }
    }
    
    func notifyPlayQueueIndexChanged() {
        NotificationCenter.postOnMainThread(name: PlayQueue.Notifications.indexChanged)
    }
    
    fileprivate func registerForNotifications() {
        // Watch for changes to the play queue playlist
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playlistChanged(_:)), name: Playlist.Notifications.playlistChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songStarted), name: GaplessPlayer.Notifications.songStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songPaused), name: GaplessPlayer.Notifications.songPaused)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songEnded), name: GaplessPlayer.Notifications.songEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(videoEnded(_:)), name: Notifications.videoEnded)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: Playlist.Notifications.playlistChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songStarted)
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songPaused)
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songEnded)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.videoEnded)
    }
    
    @objc fileprivate func playlistChanged(_ notification: Notification) {
        
    }
    
    @objc fileprivate func songStarted() {
        updateLockScreenInfo()
    }
    
    @objc fileprivate func songPaused() {
        updateLockScreenInfo()
    }
    
    @objc fileprivate func songEnded() {
        incrementIndex()
        updateLockScreenInfo()
        StreamQueue.si.start()
    }
    
    @objc fileprivate func videoEnded(_ notification: Notification) {
        songEnded()
        playSong(atIndex: currentIndex)
    }
    
    // MARK: - Properties -
    
    static let si = PlayQueue()
    
    var repeatMode = RepeatMode.normal
    var shuffleMode = ShuffleMode.normal { didSet { /* TODO: Do something */ } }
    
    fileprivate(set) var currentIndex = -1 {
        didSet {
            preheadArt()
            updateLockScreenInfo()
            
            // Prefetch the art
            if let coverArtId = currentSong?.coverArtId, let serverId = currentSong?.serverId {
                CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .player)
                CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .cell)
            }
            
            if currentIndex != oldValue {
                notifyPlayQueueIndexChanged()
            }
        }
    }
    var previousIndex: Int { return indexAtOffset(-1, fromIndex: currentIndex) }
    var nextIndex: Int { return indexAtOffset(1, fromIndex: currentIndex) }
    var currentDisplaySong: Song? { return currentSong ?? previousSong }
    var currentSong: Song? { return playlist.song(atIndex: currentIndex) }
    var previousSong: Song? { return playlist.song(atIndex: previousIndex) }
    var nextSong: Song? { return playlist.song(atIndex: nextIndex) }
    var songCount: Int { return playlist.songCount }
    var isPlaying: Bool { return player.isPlaying }
    var isStarted: Bool { return player.isStarted }
    var currentSongProgress: Double { return player.progress }
    var playlist: Playlist { return Playlist.playQueue }
    var songs: [Song] {
        // TODO: Figure out what to do about the way playlist models hold songs and how we regenerate the model in this class
        let playlist = self.playlist
        playlist.loadSubItems()
        return playlist.songs
    }
    
    fileprivate let player: GaplessPlayer = { return GaplessPlayer.si }()
    fileprivate var videoPlaybackManager: VideoPlaybackManager?
    
    init() {
        registerForNotifications()
    }
    
    deinit {
        unregisterForNotifications()
    }
    
    // MARK: - Play Queue -
    
    func incrementIndex() {
        currentIndex = nextIndex
    }
    
    func reset() {
        playlist.removeAllSongs()
        player.stop()
        currentIndex = -1
    }
    
    func removeSongs(atIndexes indexes: IndexSet) {
        // Stop the music if we're removing the current song
        let containsCurrentIndex = indexes.contains(currentIndex)
        if containsCurrentIndex {
            player.stop()
        }
        
        // Remove the songs
        playlist.remove(songsAtIndexes: indexes)
        
        // Adjust the current index if songs are removed below it
        if currentIndex >= 0 {
            let range = NSMakeRange(0, currentIndex)
            let countOfIndexesBelowCurrent = indexes.count(in: Range(range) ?? 0..<0)
            currentIndex = currentIndex - countOfIndexesBelowCurrent
        }
        
        // If we removed the current song, start the next one
        if containsCurrentIndex {
            playSong(atIndex: currentIndex)
        }
    }
    
    func removeSong(atIndex index: Int) {
        var indexSet = IndexSet()
        indexSet.insert(index)
        removeSongs(atIndexes: indexSet)
    }
    
    func insertSong(song: Song, index: Int, notify: Bool = false) {
        playlist.insert(song: song, index: index, notify: notify)
    }
    
    func insertSongNext(song: Song, notify: Bool = false) {
        let index = currentIndex < 0 ? songCount : currentIndex + 1
        playlist.insert(song: song, index: index, notify: notify)
    }
    
    func moveSong(fromIndex: Int, toIndex: Int, notify: Bool = false) {
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
        }
    }
    
    func songAtIndex(_ index: Int) -> Song? {
        return playlist.song(atIndex: index)
    }
    
    func indexAtOffset(_ offset: Int, fromIndex: Int) -> Int {
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
    
    func indexAtOffsetFromCurrentIndex(_ offset: Int) -> Int {
        return indexAtOffset(offset, fromIndex: self.currentIndex)
    }
    
    // MARK: - Player Control -
    
    func playSongs(_ songs: [Song], playIndex: Int) {
        reset()
        playlist.add(songs: songs)
        playSong(atIndex: playIndex)
    }
    
    func playSong(atIndex index: Int) {
        currentIndex = index
        if let currentSong = currentSong {
            if currentSong.contentType?.basicType == .audio || currentSong.contentType?.basicType == .video {
                startSong()
            }
        }
    }

    func playPreviousSong() {
        if player.progress > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            playSong(atIndex: self.currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            playSong(atIndex: self.previousIndex)
        }
    }
    
    func playNextSong() {
        playSong(atIndex: self.nextIndex)
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func playPause() {
        player.playPause()
    }
    
    func stop() {
        player.stop()
    }
    
    fileprivate var startSongDelayTimer: DispatchSourceTimer?
    func startSong(byteOffset: Int64 = 0) {
        if let startSongDelayTimer = startSongDelayTimer {
            startSongDelayTimer.cancel()
            self.startSongDelayTimer = nil
        }
        
        if currentSong != nil {
            // Only start the caching process if it's been a half second after the last request
            // Prevents crash when skipping through playlist fast
            startSongDelayTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            startSongDelayTimer!.schedule(deadline: .now() + .milliseconds(600))
            startSongDelayTimer!.setEventHandler {
                self.startSongDelayed(byteOffset: byteOffset)
            }
            startSongDelayTimer!.resume()
        } else {
            player.stop()
        }
    }
    
    fileprivate func startSongDelayed(byteOffset: Int64) {
        // Destroy the streamer to start a new song
        player.stop()
        videoPlaybackManager?.stop()
        videoPlaybackManager = nil
        
        // Start the stream manager
        StreamQueue.si.start()
        
        if let currentSong = currentSong {
            if currentSong.contentType?.basicType == .audio {
                // Check to see if the song is already cached
                if currentSong.isFullyCached {
                    // The song is fully cached, start streaming from the local copy
                    player.start(song: currentSong, byteOffset: byteOffset)
                } else {
                    if let currentCachingSong = DownloadQueue.si.currentSong, currentCachingSong == currentSong {
                        // If the Cache Queue is downloading it and it's ready for playback, start the player
                        if DownloadQueue.si.streamHandler?.isReadyForPlayback == true {
                            player.start(song: currentSong, byteOffset: byteOffset)
                        }
                    } else {
                        if StreamQueue.si.streamHandler?.isReadyForPlayback == true {
                            player.start(song: currentSong, byteOffset: byteOffset)
                        }
                    }
                }
            } else if currentSong.contentType?.basicType == .video, let urlRequest = URLRequest(subsonicAction: .hls, serverId: currentSong.serverId, parameters: ["id": currentSong.songId, "bitRate": ["2048", "1024", "512", "256"]]), let url = urlRequest.url {
                // Video, so use the video manager to handle playback and proxying
                videoPlaybackManager = VideoPlaybackManager(url: url)
                videoPlaybackManager?.start()
            } else {
                // Neither a song or video, so skip it
                playNextSong()
            }
        }
    }
    
    // MARK: - Lock Screen -
    
    fileprivate func preheadArt() {
        if let coverArtId = currentSong?.coverArtId, let serverId = currentSong?.serverId {
            CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .player)
            CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .cell)
        }
        
        if let coverArtId = nextSong?.coverArtId, let serverId = currentSong?.serverId {
            CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .player)
            CachedImage.preheat(coverArtId: coverArtId, serverId: serverId, size: .cell)
        }
    }
    
    fileprivate var defaultItemArtwork: MPMediaItemArtwork = {
        MPMediaItemArtwork(image: CachedImage.default(forSize: .player))
    }()
    
    fileprivate var lockScreenUpdateTimer: Timer?
    @objc func updateLockScreenInfo() {
        var trackInfo = [String: AnyObject]()
        if let song = self.currentSong {
            trackInfo[MPMediaItemPropertyTitle] = song.title as AnyObject?
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
                trackInfo[MPMediaItemPropertyPlaybackDuration] = duration as AnyObject?
            }
            trackInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex as AnyObject?
            trackInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = songCount as AnyObject?
            trackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.progress as AnyObject?
            trackInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0 as AnyObject?
            
            trackInfo[MPMediaItemPropertyArtwork] = defaultItemArtwork
            if let coverArtId = song.coverArtId, let image = CachedImage.cached(coverArtId: coverArtId, serverId: song.serverId, size: .player) {
                trackInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
            }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = trackInfo
        }
        
        // Run this every 15 seconds to update the progress and keep it in sync
        if let lockScreenUpdateTimer = self.lockScreenUpdateTimer {
            lockScreenUpdateTimer.invalidate()
        }
        lockScreenUpdateTimer = Timer(timeInterval: 15.0, target: self, selector: #selector(updateLockScreenInfo), userInfo: nil, repeats: false)
    }
}

fileprivate class VideoPlaybackManager: NSObject, HLSProxyServerDelegate {
    let url: URL
    let proxyServer: HLSProxyServer
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    
    var registeredForKVO = false
    
    init(url: URL) {
        self.url = url
        self.proxyServer = HLSProxyServer(playlistUrl: url, allowSelfSignedCerts: true)
        super.init()
    }
    
    deinit {
        stop()
    }
    
    func start() {
        proxyServer.delegate = self
        proxyServer.start()
    }
    
    func stop() {
        proxyServer.stop()
        if registeredForKVO {
            playerItem?.removeObserver(self, forKeyPath: "status")
            player?.removeObserver(self, forKeyPath: "status")
            registeredForKVO = false
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func hlsProxyServer(_ server: HLSProxyServer, streamIsReady url: URL) {
        print("stream ready")
        
        let urlString = "http://localhost:9999/stream.m3u8"
        let asset = AVURLAsset(url: URL(string: urlString)!)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(), context: nil)
        self.playerItem = playerItem
        
        let player = AVPlayer(playerItem: playerItem)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(), context: nil)
        self.player = player
        
        registeredForKVO = true
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(videoEnded(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
//        NotificationCenter.addObserverOnMainThread(self, selector: #selector(videoFailed(_:)), name: .AVPlayerItemNewErrorLogEntry, object: playerItem)
//        NotificationCenter.addObserverOnMainThread(self, selector: #selector(videoFailed(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
//        NotificationCenter.addObserverOnMainThread(self, selector: #selector(videoFailed(_:)), name: .AVPlayerItemPlaybackStalled, object: playerItem)
        
        let userInfo = [PlayQueue.Notifications.Keys.avPlayer: player]
        NotificationCenter.postOnMainThread(name: PlayQueue.Notifications.displayVideo, object: nil, userInfo: userInfo)
    }
    
    func hlsProxyServer(_ server: HLSProxyServer, streamDidFail error: HLSProxyError) {
        print("stream did fail")
    }
    
    func hlsProxyServer(_ server: HLSProxyServer, playlistDidEnd playlist: HLSPlaylist) {
        print("stream playlist did end")
    }
    
    @objc func videoEnded(_ notification: Notification) {
        let userInfo: [String: Any] = player == nil ? [String: Any]() : [PlayQueue.Notifications.Keys.avPlayer: player as Any]
        NotificationCenter.postOnMainThread(name: PlayQueue.Notifications.videoEnded, object: nil, userInfo: userInfo)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let player = object as? AVPlayer {
            if player.status == .readyToPlay {
                player.play()
            }
        } else if let playerItem = object as? AVPlayerItem {
            // NOTE: Add a breakpoint here to debug playback issues. Check playerItem.error and playerItem.errorLog()
            print("playerItem: \(playerItem) keyPath: \(String(describing: keyPath)) change: \(String(describing: change))")
            if let error = playerItem.error, let errorLog = playerItem.errorLog() {
                 log.error("video playback error: \(error)  errorLog(): \(errorLog)")
            }
        }
    }
}
