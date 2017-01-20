//
//  AudioEngine.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import AVFoundation

@objc class AudioEngine: NSObject {
    static let si = AudioEngine()
    
    weak var delegate: BassGaplessPlayerDelegate?
    
    fileprivate(set) var player: BassGaplessPlayer?
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
            NotificationCenter.addObserver(onMainThread: self, selector: #selector(handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption.rawValue, object: audioSession)
            NotificationCenter.addObserver(onMainThread: self, selector: #selector(routeChanged(_:)), name: NSNotification.Name.AVAudioSessionRouteChange.rawValue, object: audioSession)
        } catch {
            printError(error)
        }
        
        delegate = PlayQueue.si
        startEmptyPlayer()
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
    
    func start(song: Song, index: Int, byteOffset: Int64 = 0) {
        player?.stop()
        player?.start(song, at: index, byteOffset: byteOffset)
        let effect = BassEffectDAO(type: .parametricEQ)!
        effect.selectPresetId(effect.selectedPresetId)
    }
    
    func startEmptyPlayer() {
        player?.stop()
        if player == nil {
            player = BassGaplessPlayer(delegate: delegate)
        }
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
        player?.seekToPosition(inBytes: UInt64(bytes), fadeVolume: fade)
    }
    
    func seek(seconds: Double, fade: Bool = true) {
        player?.seekToPosition(inSeconds: seconds, fadeVolume: fade)
    }
    
    func seek(percent: Double, fade: Bool = true) {
        player?.seekToPosition(inPercent: percent, fadeVolume: fade)
    }
}
