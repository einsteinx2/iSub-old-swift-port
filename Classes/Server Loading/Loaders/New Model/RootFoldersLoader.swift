//
//  RootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

final class RootFoldersLoader: ApiLoader, RootItemLoader {
    var mediaFolderId: Int64?
    
    var ignoredArticles = [String]()
    var folders = [Folder]()
    var songs = [Song]()
    
    var associatedItem: Item?
    
    var items: [Item] {
        return folders as [Item] + songs as [Item]
    }
    
    override func createRequest() -> URLRequest? {
        var parameters: [String: String]?
        if let mediaFolderId = mediaFolderId, mediaFolderId >= 0 {
            parameters = ["musicFolderId": "\(mediaFolderId)"]
        }
        return URLRequest(subsonicAction: .getIndexes, serverId: serverId, parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var foldersTemp = [Folder]()
        var songsTemp = [Song]()
        
        root.iterate("indexes.index") { index in
            index.iterate("artist") { artist in
                if artist.attribute("name") != ".AppleDouble" {
                    if let aFolder = Folder(rxmlElement: artist, serverId: self.serverId, mediaFolderId: self.mediaFolderId ?? 0) {
                        foldersTemp.append(aFolder)
                    }
                }
            }
        }
        
        root.iterate("indexes.child") { child in
            if let aSong = Song(rxmlElement: child, serverId: self.serverId), aSong.contentType != nil {
                songsTemp.append(aSong)
            }
        }
        
        if let ignoredArticlesString = root.child("indexes")?.attribute("ignoredArticles") {
            ignoredArticles = ignoredArticlesString.components(separatedBy: " ")
        }
        folders = foldersTemp
        songs = songsTemp
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // TODO: Only delete missing ones
        // Remove existing root folders
        FolderRepository.si.deleteRootFolders(mediaFolderId: mediaFolderId, serverId: serverId)
        SongRepository.si.deleteRootSongs(mediaFolderId: mediaFolderId, serverId: serverId)
        
        // Save the new folders and songs
        folders.forEach({$0.replace()})
        songs.forEach({$0.replace()})
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        folders = FolderRepository.si.rootFolders(mediaFolderId: mediaFolderId, serverId: serverId)
        songs = SongRepository.si.rootSongs(mediaFolderId: mediaFolderId, serverId: serverId)
        
        return folders.count + songs.count > 0
    }
}
