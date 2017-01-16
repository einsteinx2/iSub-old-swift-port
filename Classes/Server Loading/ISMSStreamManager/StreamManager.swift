//
//  StreamManager.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

import Foundation
import Async

class StreamManager: NSObject, StreamHandlerDelegate {
    open static let si = StreamManager()
    
    fileprivate let maxReconnects = 5
    
    fileprivate(set) var isDownloading = false
    fileprivate(set) var song: Song?
    var streamHandler: StreamHandler?
    
    func start() {
        //print("Stream manager starting")
        guard let currentSong = PlayQueue.si.currentSong, song != currentSong, !SavedSettings.si().isOfflineMode else {
            //print("Stream manager song: \(song) currentSong: \(PlayQueue.si.currentSong) isOfflineMode: \(SavedSettings.si().isOfflineMode)")
            return
        }
        
        stop()
        
        if currentSong.basicType == .audio && !currentSong.isFullyCached && CacheQueueManager.si.currentSong != currentSong {
            //print("Stream manager using current song")
            song = currentSong
        } else if let nextSong = PlayQueue.si.nextSong, nextSong.basicType == .audio && !nextSong.isFullyCached &&  CacheQueueManager.si.currentSong != nextSong {
            //print("Stream manager using next song")
            song = nextSong
        } else {
            //print("Stream manager no song to stream so stopping")
            return
        }
        
        isDownloading = true
        
        // Prefetch the art
        if let coverArtId = song!.coverArtId {
            CachedImage.preheat(coverArtId: coverArtId, size: .player)
            CachedImage.preheat(coverArtId: coverArtId, size: .cell)
        }
        
        // Create the stream handler
        streamHandler = StreamHandler(song: song!, isTemp: false, delegate: self)
        streamHandler!.allowReconnects = true
        streamHandler!.start()
    }
    
    func stop() {
        isDownloading = false
        
        streamHandler?.cancel()
        streamHandler = nil
        song = nil
    }
    
    // MARK: - Stream Handler Delegate -
    
    fileprivate func removeFile(forHandler handler: StreamHandler) {
        // TODO: Error handling
        try? FileManager.default.removeItem(atPath: handler.filePath)
    }
    
    func streamHandlerStarted(_ handler: StreamHandler) {
        
    }
    
    func streamHandlerConnectionFinished(_ handler: StreamHandler) {
        var isSuccess = true
        if handler.totalBytesTransferred == 0 {
            // TODO: Display message to user that we couldn't stream
            removeFile(forHandler: handler)
            isSuccess = false
        } else if handler.totalBytesTransferred < 2000 {
            var isLicenceIssue = false
            if let receivedData = try? Data(contentsOf: URL(fileURLWithPath: handler.filePath)) {
                if let root = RXMLElement(fromXMLData: receivedData), root.isValid {
                    if let error = root.child("error"), error.isValid {
                        if let code = error.attribute("code"), code == "60" {
                            isLicenceIssue = true
                        }
                    }
                }
            } else {
                isSuccess = false
            }
            
            if isLicenceIssue {
                // TODO: Update this error message to better explain and to point to free alternatives
                let alert = UIAlertController(title: "Subsonic API Trial Expired",
                                              message: "You can purchase a license for Subsonic by logging in to the web interface and clicking the red Donate link on the top right.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.\n\nIf you didn't know about the Subsonic license requirement, and do not wish to purchase it, please tap the Support button on the Home tab and contact iSub support for a refund.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                AppDelegate.si().sidePanelController.present(alert, animated: true, completion: nil)
                
                // TODO: Error handling
                removeFile(forHandler: handler)
                isSuccess = false
            }
        }
        
        if isSuccess {
            if streamHandler?.numberOfReconnects == 0 {
                // Only mark song as cached if it didn't reconnect to avoid files with glitches
                song?.isFullyCached = true
            }
            song = nil
            streamHandler = nil
            
            // Start streaming the next song
            start()
        }
    }
    
    func streamHandlerConnectionFailed(_ handler: StreamHandler, withError error: Error?) {
        if handler.allowReconnects && handler.numberOfReconnects < maxReconnects {
            // Less than max number of reconnections, so try again
            handler.numberOfReconnects += 1
            handler.start(true)
        } else {
            // TODO: Display message to user in app
            streamHandler = nil
            start()
        }
    }
}
