//
//  StreamHandler.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

@objc protocol StreamHandlerDelegate {
    func streamHandlerStarted(_ handler: StreamHandler)
    func streamHandlerConnectionFinished(_ handler: StreamHandler)
    func streamHandlerConnectionFailed(_ handler: StreamHandler, withError error: Error?)
}

@objc class StreamHandler: NSObject, URLSessionDataDelegate {
    struct Notifications {
        static let readyForPlayback = Notification.Name("StreamHandler_readyForPlayback")
        static let downloaded       = Notification.Name("StreamHandler_downloaded")
        static let failed           = Notification.Name("StreamHandler_failed")
        
        struct Keys {
            static let song = "song"
        }
    }
    
    fileprivate var selfRef: StreamHandler?
    
    var delegate: StreamHandlerDelegate?
    
    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    
    var allowReconnects = false
    var numberOfReconnects = 0
    
    var byteOffset: Int64 = 0
    var totalBytesTransferred: Int64 = 0
    var bytesTransferred: Int64 = 0
    var speedLoggingDate = Date.distantPast
    var speedLoggingLastSize: Int64 = 0
    var recentDownloadSpeedInBytesPerSec: Int = 0
    var isTempCache: Bool = false
    var bitrate: Int = 0
    var isDownloading: Bool = false
    var isCanceled: Bool = false
    
    var contentLength: Int64 = -1
    var maxBitrateSetting: Int = -1
    var fileHandle: FileHandle?
    var startDate = Date.distantPast
    
    var isReadyForPlayback: Bool = false
    
    var totalDownloadSpeedInBytesPerSec: Int {
         return Int(Double(totalBytesTransferred) / NSDate().timeIntervalSince(startDate))
    }
    
    var filePath: String {
        return isTempCache ? song.localTempPath : song.localPath
    }
    
    var isCurrentSong: Bool {
        if let currentSong = PlayQueue.si.currentSong {
            return song == currentSong
        }
        return false
    }
    
    let song: Song
    
    init(song: Song, isTemp: Bool, byteOffset: Int64 = 0, delegate: StreamHandlerDelegate) {
        self.song = song
        self.isTempCache = isTemp
        self.byteOffset = byteOffset
        self.delegate = delegate
    }
    
    func start(_ resume: Bool = false) {
        if selfRef == nil {
            selfRef = self
        }
        
        speedLoggingDate = Date()
        contentLength = Int64.max
        totalBytesTransferred = 0
        bytesTransferred = 0
        
        fileHandle = FileHandle(forWritingAtPath: filePath)
        if let fileHandle = fileHandle {
            if resume {
                // File exists so seek to the end
                totalBytesTransferred = Int64(fileHandle.seekToEndOfFile())
                byteOffset += totalBytesTransferred
            } else {
                // File exists so remove it
                fileHandle.closeFile()
                self.fileHandle = nil
                try? FileManager.default.removeItem(atPath: filePath)
            }
        }
        
        if !resume {
            // Clear temp cache if this is a temp file
            if isTempCache {
                CacheSingleton.si().clearTempCache()
            }
            
            // Create the file
            totalBytesTransferred = 0
            FileManager.default.createFile(atPath: filePath, contents: Data(), attributes: nil)
            fileHandle = FileHandle(forWritingAtPath: filePath)
        }
        
        // Mark the new file as no backup
        if !SavedSettings.si.isBackupCacheEnabled {
            var fileUrl = URL(fileURLWithPath: filePath)
            fileUrl.isExcludedFromBackup = true
        }
        
        bitrate = song.estimatedBitrate
        if maxBitrateSetting < 0 {
            maxBitrateSetting = SavedSettings.si.currentMaxBitrate
        }
        
        var parameters = ["id": "\(song.songId)"]
        if maxBitrateSetting > 0 {
            parameters["maxBitRate"] = "\(maxBitrateSetting)"
        }
        let request = URLRequest(subsonicAction: .stream, parameters: parameters)
        
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session?.dataTask(with: request)
        task?.resume()
        
        isDownloading = true
        
        EX2NetworkIndicator.usingNetwork()
    }
    
    func cancel() {
        if isCanceled || !isDownloading {
            return
        }
        
        print("[URLSessionStreamHandler] Stream handler request canceled for %@", song)
        
        isCanceled = true
        
        task?.cancel()
        
        terminateDownload()
        
        try? FileManager.default.removeItem(atPath: filePath)
        
        selfRef = nil
    }
    
    fileprivate func terminateDownload() {
        if isDownloading {
            EX2NetworkIndicator.doneUsingNetwork()
        }
        
        isDownloading = false
        
        fileHandle?.closeFile()
        fileHandle = nil
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        startDate = Date()
        
        if !isTempCache {
            song.isPartiallyCached = true
        }
        
        contentLength = response.expectedContentLength
        
        delegate?.streamHandlerStarted(self)
        
        completionHandler(.allow)
    }
    
    // Allow self signed certs
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential())
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        fileHandle?.write(data)
        
        let bytesRead = data.count
        totalBytesTransferred += bytesRead
        bytesTransferred += bytesRead
        
        // Notify delegate if enough bytes received to start playback
        let bytesPerSec = Double(totalBytesTransferred) / Date().timeIntervalSince(startDate)
        if !isReadyForPlayback && totalBytesTransferred >= StreamHandler.minBytesToStartPlayback(forKiloBitrate: bitrate, speedInBytesPerSec: Int(bytesPerSec)) {
            isReadyForPlayback = true
            let userInfo = [Notifications.Keys.song: song]
            NotificationCenter.postOnMainThread(name: Notifications.readyForPlayback, userInfo: userInfo)
        }
        
        // Get the download speed, check every 6 seconds
        let speedInterval = Date().timeIntervalSince(speedLoggingDate)
        if speedInterval >= 6.0 {
            let transferredSinceLastCheck = totalBytesTransferred - speedLoggingLastSize
            let speedInBytes = Double(transferredSinceLastCheck) / speedInterval
            recentDownloadSpeedInBytesPerSec = Int(speedInBytes)
            
            speedLoggingLastSize = totalBytesTransferred
            speedLoggingDate = Date()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        terminateDownload()
        
        if let error = error {
            let userInfo = [Notifications.Keys.song: song]
            NotificationCenter.postOnMainThread(name: Notifications.failed, userInfo: userInfo)
            delegate?.streamHandlerConnectionFailed(self, withError: error)
        } else {
            if contentLength > 0 && song.localFileSize < contentLength {
                print("[URLSessionStreamHandler] Connection Failed because not enough bytes were download for \(song.title)")
                
                // This is a failed download, it didn't download enough
                let userInfo = [Notifications.Keys.song: song]
                NotificationCenter.postOnMainThread(name: Notifications.failed, userInfo: userInfo)
                delegate?.streamHandlerConnectionFailed(self, withError: nil)
            } else {
                print("[URLSessionStreamHandler] Connection was successful because the file size matches the content length header for \(song.title)")
                
                if !isReadyForPlayback {
                    isReadyForPlayback = true
                    let userInfo = [Notifications.Keys.song: song]
                    NotificationCenter.postOnMainThread(name: Notifications.readyForPlayback, userInfo: userInfo)
                }
                
                let userInfo = [Notifications.Keys.song: song]
                NotificationCenter.postOnMainThread(name: Notifications.downloaded, userInfo: userInfo)
                delegate?.streamHandlerConnectionFinished(self)
            }
        }
    }
    
    class func minBytesToStartPlayback(forKiloBitrate rate: Int, speedInBytesPerSec bytesPerSec: Int) -> Int64 {
        // If start date is nil somehow, or total bytes transferred is 0 somehow,
        if rate == 0 || bytesPerSec == 0 {
            return BytesForSecondsAtBitrate(seconds: 10, bitrate: rate)
        }
        
        // Get the download speed so far
        let kiloBytesPerSec = Double(bytesPerSec) / 1024.0
        
        // Find out out many bytes equals 1 second of audio
        let bytesForOneSecond = Double(BytesForSecondsAtBitrate(seconds: 1, bitrate: rate))
        let kiloBytesForOneSecond = bytesForOneSecond / 1024.0;
        
        // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
        let secondsPerSecondFactor = kiloBytesPerSec / kiloBytesForOneSecond
        
        var minSecondsToStartPlayback = 0
        if secondsPerSecondFactor < 1.0 {
            // Downloading slower than needed for playback, allow for a long buffer
            minSecondsToStartPlayback = 16
        } else if secondsPerSecondFactor >= 1.0 && secondsPerSecondFactor < 1.5 {
            // Downloading faster, but not much faster, allow for a long buffer period
            minSecondsToStartPlayback = 8;
        } else if secondsPerSecondFactor >= 1.5 && secondsPerSecondFactor < 1.8 {
            minSecondsToStartPlayback = 6;
        } else if secondsPerSecondFactor >= 1.8 && secondsPerSecondFactor < 2.0 {
            // Downloading fast enough for a smaller buffer
            minSecondsToStartPlayback = 4;
        } else {
            // Downloading multiple times playback speed, start quickly
            minSecondsToStartPlayback = 2;
        }
        
        // Convert from seconds to bytes
        let minBytesToStartPlayback = Int64(Double(minSecondsToStartPlayback) * bytesForOneSecond)
        return minBytesToStartPlayback

    }
    
    static func ==(lhs: StreamHandler, rhs: StreamHandler) -> Bool {
        return lhs.song == rhs.song
    }
}
