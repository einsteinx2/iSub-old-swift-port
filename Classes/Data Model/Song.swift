//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Song: Item {
    var itemId: Int64 { return songId }
    var itemName: String { return title }
}

@objc class Song: NSObject {
    let repository: SongRepository
    
    let songId: Int64
    let serverId: Int64
    
    let contentTypeId: Int64
    let transcodedContentTypeId: Int64?
    // TODO: See if mediaFolderId should be nullable
    let mediaFolderId: Int64?
    let folderId: Int64?
    let artistId: Int64?
    let artistName: String?
    let albumId: Int64?
    let albumName: String?
    let genreId: Int64?
    let coverArtId: String?
    let title: String
    let duration: Int?
    let bitRate: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let year: Int?
    let size: Int64
    let path: String
    
    var lastPlayed: Date?
    
    var folder: Folder?
    var artist: Artist?
    var album: Album?
    var genre: Genre?
    var contentType: ContentType?
    var transcodedContentType: ContentType?
    
    var basicType: BasicContentType? {
        return contentType?.basicType
    }
    
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
    
    var localFileSize: Int64 {
        if fileExists {
            let attributes = try? FileManager.default.attributesOfItem(atPath: currentPath)
            return attributes?[.size] as? Int64 ?? 0
        }
        return 0
    }
    
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: currentPath)
    }
    
    var estimatedBitRate: Int {
        let currentMaxBitRate = SavedSettings.si.currentMaxBitRate;
        
        // Default to 128 if there is no bitRate for this song object (should never happen)
        var rate = (bitRate == nil || bitRate == 0) ? 128 : bitRate!
        
        // Check if this is being transcoded to the best of our knowledge
        if transcodedContentType == nil {
            // This is not being transcoded between formats, however bitRate limiting may be active
            if rate > currentMaxBitRate && currentMaxBitRate != 0 {
                rate = currentMaxBitRate
            }
        } else {
            // This is probably being transcoded, so attempt to determine the bitRate
            if rate > 128 && currentMaxBitRate == 0 {
                rate = 128 // Subsonic default transcoding bitRate
            } else if rate > currentMaxBitRate && currentMaxBitRate != 0 {
                rate = currentMaxBitRate
            }
        }
        
        return rate;
    }
    
    init?(rxmlElement element: RXMLElement, serverId: Int64, repository: SongRepository = SongRepository.si) {
        guard let songId = element.attribute(asInt64Optional: "id"), let title = element.attribute(asStringOptional: "title") else {
            return nil
        }
        
        self.songId = songId
        self.serverId = serverId
        self.folderId = element.attribute(asInt64Optional: "parent")
        self.artistId = element.attribute(asInt64Optional: "artistId")
        self.albumId = element.attribute(asInt64Optional: "albumId")
        self.coverArtId = element.attribute(asStringOptional: "coverArt")
        
        self.title = title.clean
        self.duration = element.attribute(asIntOptional: "duration")
        self.bitRate = element.attribute(asIntOptional: "bitRate")
        self.trackNumber = element.attribute(asIntOptional: "track")
        self.discNumber = element.attribute(asIntOptional: "discNumber")
        self.year = element.attribute(asIntOptional: "year")
        self.size = element.attribute(asInt64: "size")
        self.path = element.attribute("path")?.clean ?? ""
        
        self.artistName = element.attribute("artist")?.clean
        self.albumName = element.attribute("album")?.clean
        
        // Retreive contentTypeId
        if let contentTypeString = element.attribute(asStringOptional: "contentType"), let contentType = ContentTypeRepository.si.contentType(mimeType: contentTypeString) {
            self.contentType = contentType
            self.contentTypeId = contentType.contentTypeId
        } else {
            self.contentTypeId = -1
        }
        
        // Retreive transcodedContentTypeId
        if let transcodedContentTypeString = element.attribute(asStringOptional: "transcodedContentType"), let transcodedContentType = ContentTypeRepository.si.contentType(mimeType: transcodedContentTypeString) {
            self.transcodedContentType = transcodedContentType
            self.transcodedContentTypeId = transcodedContentType.contentTypeId
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
        self.lastPlayed = repository.lastPlayed(songId: songId, serverId: serverId)
        
        self.repository = repository
        
        // TODO: Handle media folder id
        self.mediaFolderId = nil
    }
    
    required init(result: FMResultSet, repository: ItemRepository = SongRepository.si) {
        self.songId                  = result.longLongInt(forColumnIndex: 0)
        self.serverId                = result.longLongInt(forColumnIndex: 1)
        self.contentTypeId           = result.longLongInt(forColumnIndex: 2)
        self.transcodedContentTypeId = result.object(forColumnIndex: 3) as? Int64
        self.mediaFolderId           = result.object(forColumnIndex: 4) as? Int64
        self.folderId                = result.object(forColumnIndex: 5) as? Int64
        self.artistId                = result.object(forColumnIndex: 6) as? Int64
        self.albumId                 = result.object(forColumnIndex: 7) as? Int64
        self.genreId                 = result.object(forColumnIndex: 8) as? Int64
        self.coverArtId              = result.string(forColumnIndex: 9)
        self.title                   = result.string(forColumnIndex: 10) ?? ""
        self.duration                = result.object(forColumnIndex: 11) as? Int
        self.bitRate                 = result.object(forColumnIndex: 12) as? Int
        self.trackNumber             = result.object(forColumnIndex: 13) as? Int
        self.discNumber              = result.object(forColumnIndex: 14) as? Int
        self.year                    = result.object(forColumnIndex: 15) as? Int
        self.size                    = result.longLongInt(forColumnIndex: 16)
        self.path                    = result.string(forColumnIndex: 17) ?? ""
        self.lastPlayed              = result.date(forColumnIndex: 18)
        self.artistName              = result.string(forColumnIndex: 19)
        self.albumName               = result.string(forColumnIndex: 20)
        self.repository              = repository as! SongRepository
        
        // Preload content type objects
        self.contentType = ContentTypeRepository.si.contentType(contentTypeId: self.contentTypeId)
        if let transcodedContentTypeId = self.transcodedContentTypeId {
            self.transcodedContentType = ContentTypeRepository.si.contentType(contentTypeId: transcodedContentTypeId)
        }
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let song = object as? Song {
            return self == song
        }
        return false
    }
    
    static func ==(lhs: Song, rhs: Song) -> Bool {
        return lhs.songId == rhs.songId && lhs.serverId == rhs.serverId
    }
}

// Shim for Objective-C
extension Song {
    var durationObjC: Int {
        return duration ?? 0
    }
    
    var basicContentTypeObjC: Int64 {
        return contentType?.basicType?.rawValue ?? Int64(0)
    }
}
