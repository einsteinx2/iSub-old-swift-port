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
            
            self.persistModels()
            
            self.informDelegateLoadingFinished()
        }
    }
    
    func persistModels() {
        // Save the new songs
        songs.forEach({$0.replace()})
    }
    
    func loadModelsFromCache() -> Bool {
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
