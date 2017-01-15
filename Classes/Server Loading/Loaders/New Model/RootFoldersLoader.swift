//
//  RootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

class RootFoldersLoader: ApiLoader, ItemLoader {
    var mediaFolderId: Int?
    
    var ignoredArticles = [String]()
    var folders = [ISMSFolder]()
    var songs = [ISMSSong]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return folders as [ISMSItem] + songs as [ISMSItem]
    }
    
    override func createRequest() -> URLRequest {
        var parameters: [String: String]?
        if let mediaFolderId = mediaFolderId, mediaFolderId >= 0 {
            parameters = ["musicFolderId": "\(mediaFolderId)"]
        }
        return URLRequest(subsonicAction: .getIndexes, parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var foldersTemp = [ISMSFolder]()
        var songsTemp = [ISMSSong]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("indexes.index") { index in
            index.iterate("artist") { artist in
                if artist.attribute("name") != ".AppleDouble" {
                    let aFolder = ISMSFolder(rxmlElement: artist, serverId: serverId, mediaFolderId: self.mediaFolderId ?? 0)
                    foldersTemp.append(aFolder)
                }
            }
        }
        
        root.iterate("indexes.child") { child in
            let aSong = ISMSSong(rxmlElement: child, serverId: serverId)
            if aSong.contentType != nil {
                songsTemp.append(aSong)
            }
        }
        
        if let ignoredArticlesString = root.child("indexes")?.attribute("ignoredArticles") {
            ignoredArticles = ignoredArticlesString.components(separatedBy: " ")
        }
        folders = foldersTemp
        songs = songsTemp
        
        self.persistModels()
        
        return true
    }
    
    func persistModels() {
        // TODO: Only delete missing ones
        // Remove existing root folders
        let serverId = SavedSettings.si().currentServerId
        let mediaFolder = ISMSMediaFolder(mediaFolderId: mediaFolderId ?? 0, serverId: serverId)
        mediaFolder?.deleteRootFolders()
        
        // Save the new folders and songs
        folders.forEach({$0.replace()})
        songs.forEach({$0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si().currentServerId
        if let mediaFolderId = mediaFolderId, let mediaFolder = ISMSMediaFolder(mediaFolderId: mediaFolderId, serverId: serverId) {
            folders = mediaFolder.rootFolders()
            songs = ISMSSong.rootSongs(inMediaFolder: mediaFolderId, serverId: serverId)
        } else {
            folders = ISMSMediaFolder.allRootFolders(withServerId: serverId as NSNumber)
        }
        
        return folders.count + songs.count > 0
    }
}
