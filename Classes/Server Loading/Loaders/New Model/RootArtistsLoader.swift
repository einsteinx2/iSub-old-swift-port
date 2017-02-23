//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

final class RootArtistsLoader: ApiLoader, RootItemLoader {
    var mediaFolderId: Int64?

    var artists = [Artist]()
    var ignoredArticles = [String]()
    
    var associatedObject: Any?
    
    var items: [Item] {
        return artists
    }
    
    override func createRequest() -> URLRequest {
        var parameters: [String: String]?
        if let mediaFolderId = mediaFolderId, mediaFolderId >= 0 {
            parameters = ["musicFolderId": "\(mediaFolderId)"]
        }
        return URLRequest(subsonicAction: .getArtists, parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var artistsTemp = [Artist]()
        
        let serverId = SavedSettings.si.currentServerId
        root.iterate("artists.index") { index in
            index.iterate("artist") { artist in
                if artist.attribute("name") != ".AppleDouble" {
                    if let anArtist = Artist(rxmlElement: artist, serverId: serverId) {
                        artistsTemp.append(anArtist)
                    }
                }
            }
        }
        
        if let ignoredArticlesString = root.child("artists")?.attribute("ignoredArticles") {
            ignoredArticles = ignoredArticlesString.components(separatedBy: " ")
        }
        artists = artistsTemp
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // Remove existing artists
        let serverId = SavedSettings.si.currentServerId
        // TODO: Should only delete artists not in artists array, same for other loaders
        _ = ArtistRepository.si.deleteAllArtists(serverId: serverId)
        
        // Save the new artists
        artists.forEach({_ = $0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si.currentServerId
        let artistsTemp = ArtistRepository.si.allArtists(serverId: serverId)
        if artistsTemp.count > 0 {
            artists = artistsTemp
            return true
        }
        return false
    }
}
