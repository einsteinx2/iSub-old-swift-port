//
//  RootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

class RootAlbumsLoader: ISMSLoader, ItemLoader {
    var albums = [ISMSAlbum]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return albums
    }
    
    override func createRequest() -> URLRequest? {
        let parameters = ["type": "alphabeticalByName"]
        return NSMutableURLRequest(susAction: "getAlbumList2", parameters: parameters) as URLRequest
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
            var albumsTemp = [ISMSAlbum]()
            
            let serverId = SavedSettings.sharedInstance().currentServerId
            root.iterate("albumList2.album") { album in
                let anAlbum = ISMSAlbum(rxmlElement: album, serverId: serverId)
                albumsTemp.append(anAlbum)
            }

            albums = albumsTemp
            
            self.persistModels()
            
            self.informDelegateLoadingFinished()
        }
    }
    
    func persistModels() {
        // Remove existing artists
        let serverId = SavedSettings.sharedInstance().currentServerId as NSNumber
        ISMSAlbum.deleteAllAlbums(withServerId: serverId)
        
        // Save the new artists
        albums.forEach({$0.insert()})
    }
    
    func loadModelsFromCache() -> Bool {
        let serverId = SavedSettings.sharedInstance().currentServerId as NSNumber
        let albumsTemp = ISMSAlbum.allAlbums(withServerId: serverId)
        if albumsTemp.count > 0 {
            albums = albumsTemp
            return true
        }
        return false
    }
}
