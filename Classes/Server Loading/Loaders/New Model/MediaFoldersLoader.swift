//
//  MediaFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class MediaFoldersLoader: ApiLoader, ItemLoader {
    var mediaFolders = [ISMSMediaFolder]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return mediaFolders
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getMusicFolders)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var mediaFoldersTemp = [ISMSMediaFolder]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("musicFolders.musicFolder") { musicFolder in
            let aMediaFolder = ISMSMediaFolder(rxmlElement: musicFolder, serverId: serverId)
            mediaFoldersTemp.append(aMediaFolder)
        }
        mediaFolders = mediaFoldersTemp
        
        self.persistModels()
        
        return true
    }
    
    func persistModels() {
        // TODO: Only delete missing ones
        let serverId = SavedSettings.si().currentServerId
        ISMSMediaFolder.deleteAllMediaFolders(withServerId: serverId as NSNumber)
        mediaFolders.forEach({$0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si().currentServerId
        mediaFolders = ISMSMediaFolder.allMediaFolders(withServerId: serverId as NSNumber)
        return mediaFolders.count > 0
    }
}
