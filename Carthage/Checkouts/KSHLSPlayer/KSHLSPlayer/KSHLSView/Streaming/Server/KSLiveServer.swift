//
//  KSLiveServer.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/23.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class KSLiveServer: KSStreamServer, KSLiveReceiverDelegate {
    
    private var receiver: KSLiveReceiver!
    
    private var provider: KSLiveProvider!
    
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
        provider = KSLiveProvider(serviceUrl: service)
        
        /* Prepare receiver */
        receiver = KSLiveReceiver(url: sourceUrl)
        receiver.delegate = self
        
        receiver.start()
        
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
        resetIdleTimer()
        return provider?.providePlaylist()
    }
    // override
    public override func outputSegmentData(filename: String) -> NSData? {
        return provider?.provideSegment(filename)
    }
    
    public func startRecording(folderPath: String) {
        provider?.startSaving(folderPath)
    }
    
    public func stopRecording() {
        provider?.stopSaving()
    }
    
    // MARK: - KSLiveReceiverDelegate
    
    func receiver(receiver: KSStreamReciever, didReceivePlaylist playlist: HLSPlaylist) {
        if playlistUnchangeTimes > 0 {
            playlistUnchangeTimes = 0
        }
        if playlistFailureTimes > 0 {
            playlistFailureTimes = 0
        }
        provider.targetDuration = playlist.targetDuration
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
        if let p = provider where p.isBufferEnough() {
            serviceDidReady()
        }
    }
    
    func receiver(receiver: KSEventReceiver, segmentDidFail segment: TSSegment, withError error: NSError?) {
        print("Download ts failed - \(segment.url)")
        provider?.drop(segment)
    }
    
    func receiver(receiver: KSLiveReceiver, didPushSegment segment: TSSegment) {
        provider?.push(segment)
    }
    
    func receiver(receiver: KSLiveReceiver, didDropSegment segment: TSSegment) {
        provider?.drop(segment)
    }
}