//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

class RootArtistsLoader: ISMSAbstractItemLoader {
    var artists = [ISMSArtist]()
    var ignoredArticles = [String]()
    
    override var items: [ISMSItem]? {
        return artists
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getArtists", parameters: nil) as URLRequest
    }
    
    override func processResponse() {
        guard let root = RXMLElement(fromXMLData: self.receivedData! as Data), root.isValid else {
            let error = NSError(ismsCode: ISMSErrorCode_NotXML)
            self.informDelegateLoadingFailed(error)
            return
        }
        
        if let error = root.child("error"), error.isValid {
            let code = error.attribute("code") ?? "-1"
            let message = error.attribute("message")
            self.subsonicErrorCode(Int(code) ?? -1, message: message)
        } else {
            var artistsTemp = [ISMSArtist]()
            
            let serverId = SavedSettings.sharedInstance().currentServerId
            root.iterate("artists.index") { index in
                index.iterate("artist") { artist in
                    if artist.attribute("name") != ".AppleDouble" {
                        let anArtist = ISMSArtist(rxmlElement: artist, serverId: serverId)
                        artistsTemp.append(anArtist)
                    }
                }
            }
            
            if let ignoredArticlesString = root.child("artists")?.attribute("ignoredArticles") {
                ignoredArticles = ignoredArticlesString.components(separatedBy: " ")
            }
            artists = artistsTemp
            
            self.persistModels()
            
            self.informDelegateLoadingFinished()
        }
    }
    
    override func persistModels() {
        // Remove existing artists
        let serverId = SavedSettings.sharedInstance().currentServerId as NSNumber
        ISMSArtist.deleteAllArtists(withServerId: serverId)
        
        // Save the new artists
        artists.forEach({$0.insert()})
    }
    
    override func loadModelsFromCache() -> Bool {
        let serverId = SavedSettings.sharedInstance().currentServerId as NSNumber
        let artistsTemp = ISMSArtist.allArtists(withServerId: serverId)
        if artistsTemp.count > 0 {
            artists = artistsTemp
            return true
        }
        return false
    }
}
