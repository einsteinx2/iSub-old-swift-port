//
//  KSLiveReceiver.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/13.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class KSLiveReceiver: KSStreamReciever {
    
    struct Config {
        /**
            Number of TS segments that we assume server will keep.
         */
        static let segmentAliveSize = 5
        /**
            Number of TS segments from last that we start downloading for a new playlist.
        */
        static let segmentCatchupSize = 2
    }
    
    weak var delegate: KSLiveReceiverDelegate?
    
    /**
        When downloading a TS segment that is already recycled on server, status code 404 will
        return. If this happens, we're falling behind too much. Should catchup by skipping some
        segments.
    */
    private var tsFallBehind = false
    
    
    public func start() {
        startPollingPlaylist()
    }
    
    public func stop() {
        stopPollingPlaylist()
    }
    
    override func playlistDidFail(response: NSHTTPURLResponse?, error: NSError?) {
        delegate?.receiver(self, playlistDidFailWithError: error, urlStatusCode: (response?.statusCode) ?? 0)
    }
    
    override func playlistDidNotChange() {
        delegate?.receiver(self, playlistDidNotChange: playlist)
    }
    
    override func playlistDidUpdate() {
        delegate?.receiver(self, didReceivePlaylist: playlist)
    }
    
    override func getSegments() {
        synced(segmentFence, closure: { [unowned self] in
            /* Add new segments */
            var hasNewSegments = false
            for ts in self.playlist.segments {
                if !self.segments.contains(ts) {
                    self.segments += [ts]
                    hasNewSegments = true
                }
            }
            if !hasNewSegments { return }
            
            /* Maintain segment window size */
            while self.segments.count > Config.segmentWindowSize {
                // Remove segments from oldest
                let ts = self.segments.removeFirst()
                self.tsDownloads.remove(ts.url)
                
                // Cancel segment downloading
                if let task = self.segmentTasks[ts.url] {
                    task.cancel()
                    self.segmentTasks[ts.url] = nil
                    self.delegate?.receiver(self, didDropSegment: ts)
                }
            }
            
            /* Keep segmet list up to date */
            let validSize = self.tsFallBehind ? Config.segmentCatchupSize : Config.segmentAliveSize
            if self.segments.count > validSize {
                for i in 0..<self.segments.count - validSize {
                    let ts = self.segments[i]
                    if let task = self.segmentTasks[ts.url] {
                        task.cancel()
                        self.segmentTasks[ts.url] = nil
                        self.delegate?.receiver(self, didDropSegment: ts)
                    }
                }
            }
            
            /* Download segment */
            if self.isSegmentConnectionFull() { return }
            /**
                If no segment has been downloaded, we're going to download the very first segment.
                To minimize live delay, start from `Config.segmentCatchupSize`.
            */
            if self.tsDownloads.count == 0 {
                for var i = 0; i < self.segments.count; i++ {
                    if i < 0 { continue }
                    if self.isSegmentConnectionFull() { break }
                    self.downloadSegment(self.segments[i])
                }
            }
            /**
                Find the oldest segment that is not downloaded yet. If it's still alive, download it.
                Otherwise, we're delayed too much. Catch up live view by jumping to `Config.segmentCatchupSize`
                segment from last.
            */
            else {
                var index = -1
                for var i = self.segments.count - 1; i >= 0; i-- {
                    if self.tsDownloads.contains(self.segments[i].url) {
                        break
                    }
                    index = i
                }
                if index >= self.segments.count - validSize {
                    for i in index..<self.segments.count {
                        if self.isSegmentConnectionFull() { break }
                        let ts = self.segments[i]
                        if !self.tsDownloads.contains(ts.url) {
                            self.downloadSegment(ts)
                        }
                    }
                } else if index >= 0 {
                    for var i = self.segments.count - Config.segmentCatchupSize; i < self.segments.count; i++ {
                        if self.isSegmentConnectionFull() { break }
                        let ts = self.segments[i]
                        if !self.tsDownloads.contains(ts.url) {
                            self.downloadSegment(ts)
                        }
                    }
                }
            }
            self.tsFallBehind = false
        })
    }
    
    override func segmentDidFail(ts: TSSegment, response: NSHTTPURLResponse?, error: NSError?) {
        if response?.statusCode == 404 {
            tsFallBehind = true
        }
        delegate?.receiver(self, didDropSegment: ts)
        super.segmentDidFail(ts, response: response, error: error)
    }
    
    override func willDownloadSegment(ts: TSSegment) {
        delegate?.receiver(self, didPushSegment: ts)
    }
    
    override func didDownloadSegment(ts: TSSegment, data: NSData) {
        delegate?.receiver(self, didReceiveSegment: ts, data: data)
    }
}

protocol KSLiveReceiverDelegate: KSStreamReceiverDelegate {
    
    func receiver(receiver: KSLiveReceiver, didPushSegment segment: TSSegment)
    
    func receiver(receiver: KSLiveReceiver, didDropSegment segment: TSSegment)
}