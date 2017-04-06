//
//  MediaFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class MediaFoldersLoader: ApiLoader, ItemLoader {
    var mediaFolders = [MediaFolder]()
    
    var associatedItem: Item?
    
    var items: [Item] {
        return mediaFolders
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getMusicFolders, serverId: serverId)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var mediaFoldersTemp = [MediaFolder]()
        
        root.iterate("musicFolders.musicFolder") { musicFolder in
            if let aMediaFolder = MediaFolder(rxmlElement: musicFolder, serverId: self.serverId) {
                mediaFoldersTemp.append(aMediaFolder)
            }
        }
        mediaFolders = mediaFoldersTemp
        
        self.persistModels()
        
        return true
    }
    
    func persistModels() {
        // TODO: Only delete missing ones
        MediaFolderRepository.si.deleteAllMediaFolders(serverId: serverId)
        mediaFolders.forEach({$0.replace()})
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        mediaFolders = MediaFolderRepository.si.allMediaFolders(serverId: serverId)
        return mediaFolders.count > 0
    }
}
