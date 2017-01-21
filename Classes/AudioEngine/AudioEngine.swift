//
//  AudioEngine.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import AVFoundation
import Async

@objc class AudioEngine: NSObject {
    static let si = AudioEngine()
        
    fileprivate(set) var player: BassGaplessPlayer!
    var equalizer: BassEqualizer? { return player?.equalizer }
    var visualizer: BassVisualizer? { return player?.visualizer }
    var isStarted: Bool { return player?.isStarted ?? false }
    var isPlaying: Bool { return player?.isPlaying ?? false }
    var progress: Double { return player?.progress ?? 0.0 }
    var progressPercent: Double { return player?.progressPercent ?? 0.0 }
    
    var startByteOffset: Int64 = 0
    
    fileprivate var shouldResumeFromInterruption = false
    
    func setup() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: audioSession)
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(routeChanged(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: audioSession)
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(bassSongEnded), name: BassGaplessPlayer.Notifications.songEnded)
        } catch {
            printError(error)
        }
        
        player = BassGaplessPlayer(delegate: self)
    }
    
    @objc fileprivate func handleInterruption(_ notification: Notification) {
        if notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSessionInterruptionType.began.rawValue {
            if let player = player, player.isPlaying {
                shouldResumeFromInterruption = true
                player.pause()
            } else {
                shouldResumeFromInterruption = false
            }
        } else {
            let shouldResume = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt == AVAudioSessionInterruptionOptions.shouldResume.rawValue
            if shouldResumeFromInterruption && shouldResume {
                player?.playPause()
            }
            
            shouldResumeFromInterruption = false
        }
    }
    
    @objc fileprivate func routeChanged(_ notification: Notification) {
        if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue {
            if let player = player, player.isPlaying {
                player.playPause()
            }
        }
    }
    
    @objc fileprivate func bassSongEnded() {
        // Increment current playlist index
        PlayQueue.si.currentIndex = PlayQueue.si.nextIndex
        
        // Start preloading the next song
        StreamManager.si.start()
        
        // TODO: Is this the best place for this?
        //SocialSingleton.si().playerClearSocial()
    }
    
    func start(song: Song, index: Int, byteOffset: Int64 = 0) {
        player?.stop()
        player?.start(song: song, index: index, byteOffset: byteOffset)
        let effect = BassEffectDAO(type: .parametricEQ)!
        effect.selectPresetId(effect.selectedPresetId)
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func playPause() {
        player?.playPause()
    }
    
    func stop() {
        player?.stop()
    }
    
    func seek(bytes: Int64, fade: Bool = true) {
        player?.seek(bytes: Int64(bytes), fade: fade)
    }
    
    func seek(seconds: Double, fade: Bool = true) {
        player?.seek(seconds: seconds, fade: fade)
    }
    
    func seek(percent: Double, fade: Bool = true) {
        player?.seek(percent: percent, fade: fade)
    }
}

extension AudioEngine: BassGaplessPlayerDelegate {
    
    func bassIndex(atOffset offset: Int, from index: Int, player: BassGaplessPlayer) -> Int {
        return PlayQueue.si.indexAtOffset(offset, fromIndex: index)
    }
    
    func bassSong(for index: Int, player: BassGaplessPlayer) -> Song? {
        return PlayQueue.si.songAtIndex(index)
    }
    
    func bassCurrentPlaylistIndex(_ player: BassGaplessPlayer) -> Int {
        return PlayQueue.si.currentIndex
    }
    
    func bassRetrySong(at index: Int, player: BassGaplessPlayer) {
        Async.main {
            PlayQueue.si.playSong(atIndex: index)
        }
    }
    
    func bassUpdateLockScreenInfo(_ player: BassGaplessPlayer) {
        PlayQueue.si.updateLockScreenInfo()
    }
    
    func bassRetrySongAtOffset(inBytes bytes: Int64, player: BassGaplessPlayer) {
        PlayQueue.si.startSong(byteOffset: bytes)
    }
    
    func bassFailedToCreateNextStream(for index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        if let song = PlayQueue.si.songAtIndex(index) {
            if let handler = StreamManager.si.streamHandler, song == StreamManager.si.song {
                if handler.isReadyForPlayback {
                    // If the song is downloading and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                    Async.main {
                        PlayQueue.si.playSong(atIndex: index)
                    }
                }
            } else if song.isFullyCached {
                Async.main {
                    PlayQueue.si.playSong(atIndex: index)
                }
            } else {
                StreamManager.si.start()
            }
        }
    }
}
