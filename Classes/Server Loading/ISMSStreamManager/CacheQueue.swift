//
//  CacheQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate let maxReconnects = 5

final class CacheQueue: StreamHandlerDelegate {
    struct Notifications {
        static let started        = Notification.Name("CacheQueue_started")
        static let stopped        = Notification.Name("CacheQueue_stopped")
        static let songFailed     = Notification.Name("CacheQueue_songFailed")
    }
    
    open static let si = CacheQueue()
    
    fileprivate(set) var isDownloading = false
    fileprivate(set) var currentSong: Song?
    fileprivate(set) var streamHandler: StreamHandler?
    
    func add(song: Song) {
        Playlist.downloadQueue.add(song: song)
        start()
    }
    
    func remove(song: Song) {
        Playlist.downloadQueue.remove(song: song)
        if song == currentSong {
            stop()
            start()
        }
    }
    
    func contains(song: Song) -> Bool {
        return Playlist.downloadQueue.contains(song: song)
    }
    
    func start() {
        guard !isDownloading else {
            return
        }
        
        currentSong = Playlist.downloadQueue.song(atIndex: 0)
        log.debug("currentSong: \(self.currentSong)")
        
        guard let currentSong = currentSong, (AppDelegate.si.networkStatus.isReachableWifi || SavedSettings.si.isManualCachingOnWWANEnabled), !SavedSettings.si.isOfflineMode else {
            return
        }
        
        // TODO: Better logic
        // For simplicity sake, just make sure we never go under 25 MB and let the cache check process take care of the rest
        guard CacheManager.si.freeSpace > 25 * 1024 * 1024 else {
            /*[EX2Dispatch runInMainThread:^
             {
             [cacheS showNoFreeSpaceMessage:NSLocalizedString(@"Your device has run out of space and cannot download any more music. Please free some space and try again", @"Download manager, device out of space message")];
             }];*/
            
            return
        }
        
        // Make sure it's a song
        guard currentSong.basicType == .audio else {
            removeFromDownloadQueue(song: currentSong)
            start()
            return
        }
        
        // Make sure it's not already cached
        guard !currentSong.isFullyCached else {
            removeFromDownloadQueue(song: currentSong)
            start()
            return
        }
        
        isDownloading = true
        
        // TODO: Download the art
        
        // Create the stream handler
        if StreamQueue.si.song == currentSong, let handler = StreamQueue.si.streamHandler {
            log.debug("stealing handler from StreamQueue")
            // It's in the stream queue so steal the handler
            StreamQueue.si.streamHandler = nil
            StreamQueue.si.stop()
            StreamQueue.si.start()
            
            handler.delegate = self
            if !handler.isDownloading {
                handler.start()
            }
        } else {
            log.debug("creating handler")
            streamHandler = StreamHandler(song: currentSong, isTemp: false, delegate: self)
            streamHandler?.start()
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.started)
    }
    
    func stop() {
        isDownloading = false
        
        streamHandler?.cancel()
        streamHandler = nil
        currentSong = nil
        
        NotificationCenter.postOnMainThread(name: Notifications.stopped)
    }
    
    func resume() {
        if !SavedSettings.si.isOfflineMode {
            streamHandler?.start()
        }
    }
    
    func removeCurrentSong() {
        if isDownloading {
            stop()
        }
        
        if let currentSong = currentSong {
            removeFromDownloadQueue(song: currentSong)
        }
    }
    
    // MARK: - Helper Functions -
    
    fileprivate func removeFile(forHandler handler: StreamHandler) {
        // TODO: Error handling
        try? FileManager.default.removeItem(atPath: handler.filePath)
    }
    
    fileprivate func removeFromDownloadQueue(song: Song) {
        Playlist.downloadQueue.remove(song: song, notify: true)
    }
    
    // MARK: - Stream Handler Delegate -
    
    func streamHandlerStarted(_ handler: StreamHandler) {
        
    }
    
    func streamHandlerConnectionFinished(_ handler: StreamHandler) {
        isDownloading = false
        
        var isSuccess = true
        if handler.totalBytesTransferred == 0 {
            let alert = UIAlertController(title: "Uh oh!",
                                          message: "We asked to cache a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed.\n\nIf you need help, please tap the Support button on the Home tab.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            AppDelegate.si.sidePanelController.present(alert, animated: true, completion: nil)
            
            // TODO: Error handling
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
                // This is a trial period message, alert the user and stop streaming
                
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
            if let currentSong = currentSong {
                currentSong.isFullyCached = true
                removeFromDownloadQueue(song: currentSong)
            }
            
            currentSong = nil
            streamHandler = nil
                        
            start()
        }
    }
    
    func streamHandlerConnectionFailed(_ handler: StreamHandler, withError error: Error?) {
        isDownloading = false
        
        if handler.allowReconnects && handler.numberOfReconnects < maxReconnects {
            // Less than max number of reconnections, so try again
            handler.numberOfReconnects += 1;
            
            // Retry connection after a delay to prevent a tight loop
            DispatchQueue.main.async(after: 2.0) {
                self.resume()
            }
        } else {
            // TODO: Use a different mechanism
            //[[EX2SlidingNotification slidingNotificationOnTopViewWithMessage:NSLocalizedString(@"Song failed to download", @"Download manager, download failed message") image:nil] showAndHideSlidingNotification];

            // Tried max number of times so remove
            streamHandler = nil;
            if let currentSong = currentSong {
                removeFromDownloadQueue(song: currentSong)
            }
            
            NotificationCenter.postOnMainThread(name: Notifications.songFailed)
            
            start()
        }
    }
}
