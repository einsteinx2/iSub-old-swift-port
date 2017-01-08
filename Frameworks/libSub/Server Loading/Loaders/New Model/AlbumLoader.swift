//
//  AlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class AlbumLoader: ISMSLoader, ItemLoader {
    let albumId: Int
    
    var songs = [ISMSSong]()
    
    var items: [ISMSItem] {
        return songs
    }
    
    init(albumId: Int) {
        self.albumId = albumId
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        let parameters = ["id": "\(albumId)"]
        return NSMutableURLRequest(susAction: "getAlbum", parameters: parameters) as URLRequest
    }
    
    override func processResponse() {
        guard let root = RXMLElement(fromXMLData: self.receivedData), root.isValid else {
            let error = NSError(ismsCode: ISMSErrorCode_NotXML)
            self.informDelegateLoadingFailed(error)
            return
        }
        
        if let error = root.child("error"), error.isValid {
            let code = error.attribute("code") ?? "-1"
            let message = error.attribute("message")
            self.subsonicErrorCode(Int(code) ?? -1, message: message)
        } else {
            var songsTemp = [ISMSSong]()
            
            let serverId = SavedSettings.sharedInstance().currentServerId
            root.iterate("album.song") { song in
                let aSong = ISMSSong(rxmlElement: song, serverId: serverId)
                songsTemp.append(aSong)
            }
            songs = songsTemp
            
            // Persist associated object model if needed
            if !ISMSAlbum.isPersisted(NSNumber(value: albumId), serverId: NSNumber(value: serverId)) {
                if let element = root.child("album") {
                    let album = ISMSAlbum(rxmlElement: element, serverId: serverId)
                    album.replace()
                }
            }
            
            self.persistModels()
            
            self.informDelegateLoadingFinished()
        }
    }
    
    func persistModels() {
        // Save the new songs
        songs.forEach({$0.replace()})
        
        // Add to cache table if needed
        if let album = associatedObject as? ISMSAlbum, album.hasCachedSongs() {
            album.cacheModel()
        }
        
        // Make sure all folder records are created if needed
        let queue = SelfReferencingOperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        var folderIds = Set<Int>()
        for song in songs {
            func performOperation(folderId: Int, mediaFolderId: Int) {
                if !folderIds.contains(folderId) {
                    folderIds.insert(folderId)
                    let loader = FolderLoader(folderId: folderId, mediaFolderId: mediaFolderId)
                    let operation = ItemLoaderOperation(loader: loader)
                    queue.addOperation(operation)
                }
            }
            
            if let folder = song.folder, let folderId = folder.folderId as? Int, let mediaFolderId = folder.mediaFolderId as? Int, !folder.isPersisted {
                performOperation(folderId: folderId, mediaFolderId: mediaFolderId)
            } else if song.folder == nil, let folderId = song.folderId as? Int, let mediaFolderId = song.mediaFolderId as? Int {
                performOperation(folderId: folderId, mediaFolderId: mediaFolderId)
            }
        }
    }
    
    func loadModelsFromDatabase() -> Bool {
        if let album = associatedObject as? ISMSAlbum {
            album.reloadSubmodels()
            songs = album.songs
            return songs.count > 0
        }
        return false
    }
    
    var associatedObject: Any? {
        return ISMSAlbum(albumId: albumId, serverId: SavedSettings.sharedInstance().currentServerId, loadSubmodels: false)
    }
}
