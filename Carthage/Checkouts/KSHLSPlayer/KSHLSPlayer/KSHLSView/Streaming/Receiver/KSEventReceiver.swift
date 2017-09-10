//
//  KSEventReceiver.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/13.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class KSEventReceiver: KSStreamReciever {
    
    struct Config {
        /**
            Number of TS segments that we allow to pend for downloading.
         */
        static let pendingSegmentMax = 5
    }
    
    weak var delegate: KSEventReceiverDelegate?
    
    private var pendingSegments: [TSSegment] = []
    
    private(set) public var paused = false
    
    private(set) public var pending = false

    public func start() {
        startPollingPlaylist()
    }
    
    public func stop() {
        stopPollingPlaylist()
    }
    
    public func pause() {
        if paused { return }
        paused = true
        stopPollingPlaylist()
    }
    
    public func resume() {
        if !paused { return }
        paused = false
        startPollingPlaylist()
        if pendingSegments.count > 0 {
            getSegments()
        }
    }
    
    private func resumeFromPending() {
        if pollingPlaylist && pending && pendingSegments.count < Config.pendingSegmentMax {
            pending = false
            getPlaylist()
        }
    }
    
    override func getPlaylist() {
        // check if playlis is end
        if playlist != nil && playlist!.isEnd() { return }
        
        // check if pending segment is full
        if pendingSegments.count >= Config.pendingSegmentMax { return }
        
        // check if paused
        if paused { return }
        
        super.getPlaylist()
    }
    
    override func playlistDidFail(response: NSHTTPURLResponse?, error: NSError?) {
        delegate?.receiver(self, playlistDidFailWithError: error, urlStatusCode: (response?.statusCode) ?? 0)
    }
    
    override func playlistDidNotChange() {
        delegate?.receiver(self, playlistDidNotChange: playlist)
    }
    
    override func playlistDidUpdate() {
        delegate?.receiver(self, didReceivePlaylist: playlist)
        
        var newSegments: [TSSegment] = []
        
        synced(segmentFence, closure: { [unowned self] in
            /* Fetch new segments */
            for ts in self.playlist.segments {
                if !self.segments.contains(ts) {
                    self.segments += [ts]
                    newSegments += [ts]
                }
            }
            self.pendingSegments += newSegments
            
            /* We don't keep segment list too long */
            if self.segments.count > Config.segmentWindowSize {
                let overflow = self.segments.count - Config.segmentWindowSize
                self.segments.removeRange(Range(start: 0, end: overflow))
            }
        })
        
        delegate?.receiver(self, didPushSegments: newSegments)
    }
    
    override func prepareForPlaylist() -> Bool {
        /* Check if playlist is end */
        if playlist.isEnd() {
            delegate?.receiver(self, playlistDidEnd: playlist)
        }
        /* Check if pending segments is full */
        if pendingSegments.count >= Config.pendingSegmentMax {
            pending = true
        }
        
        return !pending
    }
    
    override func getSegments() {
        if paused { return }
        
        synced(segmentFence, closure: { [unowned self] in
            var ignoreSegments: [TSSegment] = []
            /* Download pending segments */
            for ts in self.pendingSegments {
                if self.isSegmentConnectionFull() { break }
                if self.tsDownloads.contains(ts.url) { continue }
                
                if self.delegate?.receiver(self, shouldDownloadSegment: ts) == false {
                    ignoreSegments += [ts]
                } else {
                    self.downloadSegment(ts)
                }
            }
            /* Remove ignored segments */
            if ignoreSegments.count > 0 {
                for ignore in ignoreSegments {
                    if let index = self.pendingSegments.indexOf(ignore) {
                        self.pendingSegments.removeAtIndex(index)
                    }
                }
                
                // try to resume from pending
                self.resumeFromPending()
                
                // continue to download segments
                dispatch_async(dispatch_get_main_queue(), {
                    self.getSegments()
                })
            }
        })
    }
    
    override func didDownloadSegment(ts: TSSegment, data: NSData) {
        /* Remove from pending list */
        synced(segmentFence, closure: { [unowned self] in
            if let index = self.pendingSegments.indexOf(ts) {
                self.pendingSegments.removeAtIndex(index)
            }
        })
        delegate?.receiver(self, didReceiveSegment: ts, data: data)
    }
    
    override func finishSegment(ts: TSSegment) {
        /* Try to resume from pending */
        resumeFromPending()
        super.finishSegment(ts)
    }
}

protocol KSEventReceiverDelegate: KSStreamReceiverDelegate {
    
    func receiver(receiver: KSEventReceiver, playlistDidEnd playlist: HLSPlaylist)
    
    func receiver(receiver: KSEventReceiver, didPushSegments segments: [TSSegment])
    
    func receiver(receiver: KSEventReceiver, shouldDownloadSegment segment: TSSegment) -> Bool
}