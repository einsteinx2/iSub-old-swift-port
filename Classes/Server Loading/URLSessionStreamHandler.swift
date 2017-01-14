//
//  URLSessionStreamHandler.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import Async

// TODO: Audit all of the Int types to choose the correct ones, need to ensure we support >4GB files for large videos

class URLSessionStreamHandler: ISMSStreamHandler, URLSessionDataDelegate {
    fileprivate var selfRef: URLSessionStreamHandler?
    
    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    
    override func start(_ resume: Bool) {
        guard let songId = song.songId else {
            delegate?.ismsStreamHandlerConnectionFailed?(self, withError: nil)
            return
        }
        
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
                totalBytesTransferred = Int(fileHandle.seekToEndOfFile())
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
        if !SavedSettings.si().isBackupCacheEnabled {
            var fileUrl = URL(fileURLWithPath: filePath)
            fileUrl.isExcludedFromBackup = true
        }
        
        bitrate = song.estimatedBitrate
        if maxBitrateSetting < 0 {
            maxBitrateSetting = SavedSettings.si().currentMaxBitrate
        }
        
        var parameters = ["id": "\(songId)"]
        if maxBitrateSetting > 0 {
            parameters["maxBitRate"] = "\(maxBitrateSetting)"
        }
        let request = URLRequest(subsonicAction: .stream, parameters: parameters)
        
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session?.dataTask(with: request)
        task?.resume()
        
        if song.isEqual(to: PlayQueue.si.currentSong) {
            isCurrentSong = true
        }
        
        isDownloading = true
        
        EX2NetworkIndicator.usingNetwork()
    }
    
    override func cancel() {
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
        
        delegate?.ismsStreamHandlerStarted?(self)
        
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
        let bytesPerSec = Double(totalBytesTransferred) / Date().timeIntervalSince(startDate!)
        if !isDelegateNotifiedToStartPlayback && totalBytesTransferred >= ISMSStreamHandler.minBytesToStartPlayback(forKiloBitrate: Double(bitrate), speedInBytesPerSec: Int(bytesPerSec)) {
            isDelegateNotifiedToStartPlayback = true
            delegate?.ismsStreamHandlerStartPlayback?(self)
        }
        
        // Get the download speed, check every 6 seconds
        let speedInterval = Date().timeIntervalSince(speedLoggingDate!)
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
        
        if let _ = error {
            delegate?.ismsStreamHandlerConnectionFailed?(self, withError: nil)
        } else {
            if contentLength > 0 && song.localFileSize < UInt64(contentLength) && numberOfContentLengthFailures < Int(ISMSMaxContentLengthFailures) {
                print("[URLSessionStreamHandler] Connection Failed because not enough bytes were downloaed for \(song.title)")
                
                // This is a failed download, it didn't download enough
                numberOfContentLengthFailures += 1;
                
                delegate?.ismsStreamHandlerConnectionFailed?(self, withError: nil)
            } else {
                print("[URLSessionStreamHandler] Connection was successful because the file size matches the content length header for \(song.title)")
                
                if !isDelegateNotifiedToStartPlayback {
                    delegate?.ismsStreamHandlerStartPlayback?(self)
                }
                
                delegate?.ismsStreamHandlerConnectionFinished?(self)
            }
        }
    }
}
