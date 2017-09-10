//
//  KSEventServer.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/23.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class KSEventServer: KSStreamServer, KSEventReceiverDelegate {
    
    struct Config {
        static let tsCacheUpperLine = 25
        
        static let tsCacheLowerLine = 20
    }
    
    private var receiver: KSEventReceiver!
    
    private var provider: KSEventProvider!
    
    public let eventId: String
    
    private var idleTimerPaused = false
    
    public init(source: String, eventId: String) {
        self.eventId = eventId
        super.init(source: source)
    }
    
    // override
    public override func startService() -> Bool {
        if !super.startService() { return false }
        
        /* Prepare http server */
        do {
            try prepareHttpServer()
        } catch {
            print("Establish http server failed.")
            return false
        }
        
        /* Prepare provider */
        let service = "http://localhost:\(Config.defaultPort)"
        provider = KSEventProvider(serviceUrl: service, eventId: eventId)
        
        /* Prepare receiver */
        receiver = KSEventReceiver(url: sourceUrl)
        receiver.delegate = self
        if !provider.completePreload {
            receiver.start()
        }
        /* Start service if buffer is enough */
        if provider.isBufferEnough() {
            serviceDidReady()
        }
        
        return true
    }
    
    // override
    public override func stopService() {
        super.stopService()
        receiver?.stop()
        receiver = nil
        provider?.cleanUp()
        provider = nil
    }
    
    // override
    public override func outputPlaylist() -> String? {
        stopIdleTimer()
        if !idleTimerPaused {
            resetIdleTimer()
        }
        return provider?.outputPlaylist
    }
    
    // override
    public override func outputSegmentData(filename: String) -> NSData? {
        let data = provider?.consume(filename)
        if let r = receiver, p = provider where r.paused && p.cachedSegmentSize() <= Config.tsCacheLowerLine {
            receiver.resume()
        }
        return data
    }
    
    public func pauseIdleTimer() {
        idleTimerPaused = true
        stopIdleTimer()
    }
    
    public func resumeIdleTimer() {
        idleTimerPaused = false
        resetIdleTimer()
    }
    
    // MARK: - KSEventReceiverDelegate
    
    func receiver(receiver: KSStreamReciever, didReceivePlaylist playlist: HLSPlaylist) {
        if playlistUnchangeTimes > 0 {
            playlistUnchangeTimes = 0
        }
        if playlistFailureTimes > 0 {
            playlistFailureTimes = 0
        }
        if let p = provider where p.targetDuration() == nil && playlist.targetDuration != nil {
            p.setTargetDuration(playlist.targetDuration!)
        }
    }
    
    func receiver(receiver: KSStreamReciever, playlistDidNotChange playlist: HLSPlaylist) {
        if playlistFailureTimes > 0 {
            playlistFailureTimes = 0
        }
        playlistUnchangeTimes++
        if playlistUnchangeTimes > Config.playlistUnchangeMax {
            executeDelegateFunc({ _self in
                _self.delegate?.streamServer(_self, streamDidFail: KSError(code: .PlaylistUnchanged))
            })
            stopService()
        }
    }
    
    func receiver(receiver: KSStreamReciever, playlistDidFailWithError error: NSError?, urlStatusCode code: Int) {
        if code == 404 {
            executeDelegateFunc({ _self in
                _self.delegate?.streamServer(_self, streamDidFail: KSError(code: .PlaylistNotFound))
            })
            stopService()
        } else if code == 403 {
            executeDelegateFunc({ _self in
                _self.delegate?.streamServer(_self, streamDidFail: KSError(code: .AccessDenied))
            })
            stopService()
        } else {
            playlistFailureTimes++
            if playlistFailureTimes > Config.playlistFailureMax {
                executeDelegateFunc({ _self in
                    _self.delegate?.streamServer(_self, streamDidFail: KSError(code: .PlaylistUnavailable))
                })
                stopService()
            }
        }
    }
    
    func receiver(receiver: KSStreamReciever, didReceiveSegment segment: TSSegment, data: NSData) {
        provider?.fill(segment, data: data)
        
        /* Pause downloading if cache is near to full */
        if let r = self.receiver, p = provider where !r.paused && p.cachedSegmentSize() >= Config.tsCacheUpperLine {
            r.pause()
        }
        if let p = provider where p.isBufferEnough() {
            serviceDidReady()
        }
    }
    
    func receiver(receiver: KSEventReceiver, segmentDidFail segment: TSSegment, withError error: NSError?) {
        provider?.drop(segment)
    }
    
    func receiver(receiver: KSEventReceiver, playlistDidEnd playlist: HLSPlaylist) {
        // end playlist
        provider?.endPlaylist()
        
        executeDelegateFunc({ _self in
            _self.delegate?.streamServer(_self, playlistDidEnd: playlist)
        })
    }
    
    func receiver(receiver: KSEventReceiver, didPushSegments segments: [TSSegment]) {
        for ts in segments {
            provider?.push(ts)
        }
    }
    
    func receiver(receiver: KSEventReceiver, shouldDownloadSegment segment: TSSegment) -> Bool {
        return provider != nil && !(provider!.hasSegmentData(segment.filename()))
    }
}