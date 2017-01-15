//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Song: Item {
    var itemId: Int { return songId }
    var itemName: String { return title }
}

class Song: NSObject {
    let repository: SongRepository
    
    let songId: Int
    let serverId: Int
    
    let contentTypeId: Int
    let transcodedContentTypeId: Int?
    let mediaFolderId: Int?
    let folderId: Int?
    let artistId: Int?
    let artistName: String?
    let albumId: Int?
    let albumName: String?
    let genreId: Int?
    let coverArtId: String?
    let title: String
    let duration: Int?
    let bitrate: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let year: Int?
    let size: Int
    let path: String
    
    var lastPlayed: Date?
    
    var folder: Folder?
    var artist: Artist?
    var album: Album?
    var genre: Genre?
    var contentType: ISMSContentType?
    var transcodedContentType: ISMSContentType?
    
    // Automatically chooses either the artist/album model name or uses the song property if it's not available
    // NOTE: Not every song has an Artist or Album object in Subsonic. So when folder browsing this is especially
    // important.
    var artistDisplayName: String? {
        return artist?.name ?? artistName;
    }
    var albumDisplayName: String? {
        return album?.name ?? albumName;
    }
    
    var fileName: String {
        return "\(serverId)-\(songId)"
    }
    
    var localPath: String {
        return CacheSingleton.songCachePath() + "/" + fileName
    }
    
    var localTempPath: String {
        return CacheSingleton.tempCachePath() + "/" + fileName
    }
    
    var currentPath: String {
        return isTempCached ? localTempPath : localPath
    }
    
    var isTempCached: Bool {
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    var localFileSize: Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: currentPath)
        return attributes?[.size] as? Int ?? 0
    }
    
    var estimatedBitrate: Int {
        let currentMaxBitrate = SavedSettings.si().currentMaxBitrate;
        
        // Default to 128 if there is no bitrate for this song object (should never happen)
        var rate = (bitrate == nil || bitrate == 0) ? 128 : bitrate!
        
        // Check if this is being transcoded to the best of our knowledge
        if transcodedContentType == nil {
            // This is not being transcoded between formats, however bitrate limiting may be active
            if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        } else {
            // This is probably being transcoded, so attempt to determine the bitrate
            if rate > 128 && currentMaxBitrate == 0 {
                rate = 128 // Subsonic default transcoding bitrate
            } else if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        }
        
        return rate;
    }
    
    init?(rxmlElement element: RXMLElement, serverId: Int, repository: SongRepository = SongRepository.si) {
        guard let songId = element.attribute(asIntOptional: "id"), let title = element.attribute(asStringOptional: "title") else {
            return nil
        }
        
        self.songId = songId
        self.serverId = serverId
        self.folderId = element.attribute(asIntOptional: "parent")
        self.artistId = element.attribute(asIntOptional: "artistId")
        self.albumId = element.attribute(asIntOptional: "albumId")
        self.coverArtId = element.attribute(asStringOptional: "coverArt")
        
        self.title = title.clean
        self.duration = element.attribute(asIntOptional: "duration")
        self.bitrate = element.attribute(asIntOptional: "bitRate")
        self.trackNumber = element.attribute(asIntOptional: "track")
        self.discNumber = element.attribute(asIntOptional: "discNumber")
        self.year = element.attribute(asIntOptional: "year")
        self.size = element.attribute(asInt: "size")
        self.path = element.attribute("path")?.clean ?? ""
        
        self.artistName = element.attribute("artist")?.clean
        self.albumName = element.attribute("album")?.clean
        
        // Retreive contentTypeId
        if let contentTypeString = element.attribute(asStringOptional: "contentType") {
            self.contentType = ISMSContentType(mimeType: contentTypeString)
            self.contentTypeId = contentType!.contentTypeId as? Int ?? -1
        } else {
            self.contentTypeId = -1
        }
        
        // Retreive transcodedContentTypeId
        if let transcodedContentTypeString = element.attribute(asStringOptional: "transcodedContentType") {
            self.transcodedContentType = ISMSContentType(mimeType: transcodedContentTypeString)
            self.transcodedContentTypeId = transcodedContentType!.contentTypeId as? Int
        } else {
            self.transcodedContentTypeId = nil
        }

        // Retreive genreId
        if let genreString = element.attribute(asStringOptional: "genre") {
            self.genre = GenreRepository.si.genre(name: genreString)
            self.genreId = self.genre!.genreId
        } else {
            self.genreId = nil
        }
        
        // Retreive lastPlayed date, if it exists
        self.lastPlayed = repository.lastPlayed(songId: songId, serverId: serverId, isCachedTable: false)
        
        self.repository = repository
        
        // TODO: Handle media folder id
        self.mediaFolderId = nil
    }
    
    required init(result: FMResultSet, repository: ItemRepository = SongRepository.si) {
        self.songId                  = result.long(forColumnIndex: 0)
        self.serverId                = result.long(forColumnIndex: 1)
        self.contentTypeId           = result.long(forColumnIndex: 2)
        self.transcodedContentTypeId = result.object(forColumnIndex: 3) as? Int
        self.mediaFolderId           = result.object(forColumnIndex: 4) as? Int
        self.folderId                = result.object(forColumnIndex: 5) as? Int
        self.artistId                = result.object(forColumnIndex: 6) as? Int
        self.albumId                 = result.object(forColumnIndex: 7) as? Int
        self.genreId                 = result.object(forColumnIndex: 8) as? Int
        self.coverArtId              = result.string(forColumnIndex: 9)
        self.title                   = result.string(forColumnIndex: 10) ?? ""
        self.duration                = result.object(forColumnIndex: 11) as? Int
        self.bitrate                 = result.object(forColumnIndex: 12) as? Int
        self.trackNumber             = result.object(forColumnIndex: 13) as? Int
        self.discNumber              = result.object(forColumnIndex: 14) as? Int
        self.year                    = result.object(forColumnIndex: 15) as? Int
        self.size                    = result.long(forColumnIndex: 16)
        self.path                    = result.string(forColumnIndex: 17) ?? ""
        self.lastPlayed              = result.date(forColumnIndex: 18)
        self.artistName              = result.string(forColumnIndex: 19)
        self.albumName               = result.string(forColumnIndex: 20)
        self.repository              = repository as! SongRepository
    }
}
