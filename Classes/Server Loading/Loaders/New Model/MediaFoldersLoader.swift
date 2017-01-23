//
//  MediaFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class MediaFoldersLoader: ApiLoader, ItemLoader {
    var mediaFolders = [MediaFolder]()
    
    var associatedObject: Any?
    
    var items: [Item] {
        return mediaFolders
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getMusicFolders)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var mediaFoldersTemp = [MediaFolder]()
        
        let serverId = SavedSettings.si.currentServerId
        root.iterate("musicFolders.musicFolder") { musicFolder in
            if let aMediaFolder = MediaFolder(rxmlElement: musicFolder, serverId: serverId) {
                mediaFoldersTemp.append(aMediaFolder)
            }
        }
        mediaFolders = mediaFoldersTemp
        
        self.persistModels()
        
        return true
    }
    
    func persistModels() {
        // TODO: Only delete missing ones
        let serverId = SavedSettings.si.currentServerId
        _ = MediaFolderRepository.si.deleteAllMediaFolders(serverId: serverId)
        mediaFolders.forEach({_ = $0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si.currentServerId
        mediaFolders = MediaFolderRepository.si.allMediaFolders(serverId: serverId)
        return mediaFolders.count > 0
    }
}
