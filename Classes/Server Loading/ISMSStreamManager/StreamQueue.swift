//
//  StreamQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class StreamQueue: StreamHandlerDelegate {
    open static let si = StreamQueue()
    
    fileprivate let maxReconnects = 5
    
    fileprivate(set) var isDownloading = false
    fileprivate(set) var song: Song?
    var streamHandler: StreamHandler?
    
    func start() {
        guard let currentSong = PlayQueue.si.currentSong, song != currentSong, !SavedSettings.si.isOfflineMode else {
            return
        }
        
        stop()
        
        if currentSong.basicType == .audio && !currentSong.isFullyCached && CacheQueue.si.currentSong != currentSong {
            song = currentSong
        } else if let nextSong = PlayQueue.si.nextSong, nextSong.basicType == .audio && !nextSong.isFullyCached &&  CacheQueue.si.currentSong != nextSong {
            song = nextSong
        } else {
            return
        }
        
        isDownloading = true

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
    
    fileprivate func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songEnded), name: BassGaplessPlayer.Notifications.songEnded)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: BassGaplessPlayer.Notifications.songEnded)
    }
    
    @objc fileprivate func songEnded() {
        start()
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
                AppDelegate.si.sidePanelController.present(alert, animated: true, completion: nil)
                
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
