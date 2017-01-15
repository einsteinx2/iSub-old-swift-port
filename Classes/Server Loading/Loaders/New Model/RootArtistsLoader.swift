//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

class RootArtistsLoader: ApiLoader, ItemLoader {
    var artists = [ISMSArtist]()
    var ignoredArticles = [String]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return artists
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getArtists)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var artistsTemp = [ISMSArtist]()
        
        let serverId = SavedSettings.si().currentServerId
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
        
        return true
    }
    
    func persistModels() {
        // Remove existing artists
        let serverId = SavedSettings.si().currentServerId as NSNumber
        // TODO: Should only delete artists not in artists array, same for other loaders
        ISMSArtist.deleteAllArtists(withServerId: serverId)
        
        // Save the new artists
        artists.forEach({$0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si().currentServerId as NSNumber
        let artistsTemp = ISMSArtist.allArtists(withServerId: serverId)
        if artistsTemp.count > 0 {
            artists = artistsTemp
            return true
        }
        return false
    }
}
