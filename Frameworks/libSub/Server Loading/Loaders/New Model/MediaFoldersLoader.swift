//
//  MediaFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class MediaFoldersLoader: ISMSLoader, ItemLoader {
    var mediaFolders = [ISMSMediaFolder]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return mediaFolders
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getMusicFolders", parameters: nil) as URLRequest
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
            var mediaFoldersTemp = [ISMSMediaFolder]()
            
            let serverId = SavedSettings.si().currentServerId
            root.iterate("musicFolders.musicFolder") { musicFolder in
                let aMediaFolder = ISMSMediaFolder(rxmlElement: musicFolder, serverId: serverId)
                mediaFoldersTemp.append(aMediaFolder)
            }
            mediaFolders = mediaFoldersTemp
            
            self.persistModels()
            
            self.informDelegateLoadingFinished()
        }
    }
    
    func persistModels() {
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
