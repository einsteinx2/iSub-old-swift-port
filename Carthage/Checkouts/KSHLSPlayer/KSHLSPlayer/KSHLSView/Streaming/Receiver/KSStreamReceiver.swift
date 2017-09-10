//
//  KSStreamReceiver.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/12.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation
import QuartzCore

public class KSStreamReciever {
    
    struct Config {
        /**
            Max number of concurrent TS segments download tasks.
         */
        static let concurrentDownloadMax = 3
        /**
            Number of segments that we keep in hand to maintain downloading list.
         */
        static let segmentWindowSize = 10
        /**
            The timeout for response of request in seconds.
         */
        static let requestTimeout = 3.0
        /**
            The timeout for receiving data of request in seconds.
        */
        static let resourceTimeout = 10.0
    }
        
    let playlistUrl: String
    
    /**
        Authentication info.
     */
    var username: String?
    var password: String?
    /**
        URL query string.
    */
    var m3u8Query: String?
    var tsQuery: String?
    
    /**
        HLS components.
    */
    internal var playlist: HLSPlaylist!
    internal var segments: [TSSegment] = []
    /**
        Be sure to lock `segments` when operatiing on it.
    */
    internal let segmentFence: AnyObject = NSObject()
    
    internal var session: NSURLSession?
    internal var playlistTask: NSURLSessionTask?
    
    /**
        ts url path -> task
    */
    internal var segmentTasks: [String : NSURLSessionTask] = [:]
    
    internal var tsDownloads: Set<String> = Set()
    
    internal var pollingPlaylist = false
    
    /**
        Cached data for lastest playlist.
    */
    private var playlistData: NSData!
    
    required public init(url: String) {
        playlistUrl = url
    }
    
    func startPollingPlaylist() {
        if pollingPlaylist { return }
        pollingPlaylist = true
        
        let conf = NSURLSessionConfiguration.defaultSessionConfiguration()
        conf.timeoutIntervalForRequest = Config.requestTimeout
        conf.timeoutIntervalForResource = Config.resourceTimeout
        session = NSURLSession.init()
        
        getPlaylist()
    }
    
    func stopPollingPlaylist() {
        playlistTask?.cancel()
        playlistTask = nil
        pollingPlaylist = false
    }
    
    func getPlaylist() {
        let url = m3u8Query != nil ? "\(playlistUrl)?\(m3u8Query)" : playlistUrl
        var time: NSTimeInterval?
        
        playlistTask = session?.dataTaskWithURL(NSURL.init(string: url)!, completionHandler: { [weak self] data, response, error in
            self?.handlePlaylistResponse(data, response: response, error: error, startTime: time!)
        })
        if let task = playlistTask {
            time = CACurrentMediaTime()
            task.resume()
        }
    }
    
    private func handlePlaylistResponse(data: NSData?, response: NSURLResponse?, error: NSError?, startTime: NSTimeInterval) {
        // success
        if (response as? NSHTTPURLResponse)?.statusCode == 200 && data?.length > 0 {
            var interval: NSTimeInterval!
            // playlist is unchanged
            if playlistData != nil && playlistData.isEqualToData(data!) {
                playlistDidNotChange()
                interval = (playlist?.targetDuration ?? 1.0) / 2
            } else {
                playlistData = data
                playlist = HLSPlaylist(data: playlistData)
                playlistDidUpdate()
                getSegments()
                interval = playlist.targetDuration ?? 1.0
            }
            // polling playlist
            if pollingPlaylist && prepareForPlaylist() {
                // interval should minus past time for connection
                let delay = interval - (CACurrentMediaTime() - startTime)
                if delay <= 0 {
                    getPlaylist()
                } else {
                    let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
                    dispatch_after(popTime, dispatch_get_main_queue(), { [weak self] in
                        self?.getPlaylist()
                    })
                }
            }
        }
        // failure
        else {
            playlistDidFail(response as? NSHTTPURLResponse, error: error)
        }
    }
    
    // override
    func playlistDidFail(response: NSHTTPURLResponse?, error: NSError?) {
        
    }
    
    // override
    func playlistDidNotChange() {
        
    }
    // override
    func playlistDidUpdate() {
        
    }
    // override
    func prepareForPlaylist() -> Bool {
        return true
    }
    // override
    func getSegments() {
        
    }
    
    func isSegmentConnectionFull() -> Bool {
        return segmentTasks.count >= Config.concurrentDownloadMax
    }
    
    func downloadSegment(ts: TSSegment) {
        if isSegmentConnectionFull() { return }
        
        willDownloadSegment(ts)
        
        tsDownloads.insert(ts.url)
        let url = tsQuery != nil ? "\(ts.url)?\(tsQuery)" : ts.url
        let task = session?.dataTaskWithURL(NSURL.init(string: url)!, completionHandler: { [weak self] data, response, error in
            self?.handleSegmentResponse(ts, data: data, response: response, error: error)
        })
        if task != nil {
            segmentTasks[ts.url] = task
            task!.resume()
        }
    }
    
    private func handleSegmentResponse(ts: TSSegment, data: NSData?, response: NSURLResponse?, error: NSError?) {
        // success
        if (response as? NSHTTPURLResponse)?.statusCode == 200 && data?.length > 0 {
            didDownloadSegment(ts, data: data!)
        }
        // failure
        else {
            segmentDidFail(ts, response: response as? NSHTTPURLResponse, error: error)
        }
    }
    
    func finishSegment(ts: TSSegment) {
        segmentTasks[ts.url] = nil
        if !isSegmentConnectionFull() {
            getSegments()
        }
    }
    
    // override
    func segmentDidFail(ts: TSSegment, response: NSHTTPURLResponse?, error: NSError?) {
        // this must be called to finish task
        finishSegment(ts)
    }
    
    // override
    func willDownloadSegment(ts: TSSegment) {
        
    }
    
    // override
    func didDownloadSegment(ts: TSSegment, data: NSData) {
        // this must be called to finish task
        finishSegment(ts)
    }
}

protocol KSStreamReceiverDelegate: class {
    
    func receiver(receiver: KSStreamReciever, didReceivePlaylist playlist: HLSPlaylist)
    
    func receiver(receiver: KSStreamReciever, playlistDidNotChange playlist: HLSPlaylist)
    
    func receiver(receiver: KSStreamReciever, playlistDidFailWithError error: NSError?, urlStatusCode code: Int)
    
    func receiver(receiver: KSStreamReciever, didReceiveSegment segment: TSSegment, data: NSData)
    
    func receiver(receiver: KSEventReceiver, segmentDidFail segment: TSSegment, withError error: NSError?)
}