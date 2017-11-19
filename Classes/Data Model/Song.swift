//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Song: Item, Equatable {
    var itemId: Int64 { return songId }
    var itemName: String { return title }
}

final class Song {
    let repository: SongRepository
    
    let songId: Int64
    let serverId: Int64
    
    let contentTypeId: Int64
    let transcodedContentTypeId: Int64?
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
    
    init(songId: Int64, serverId: Int64, contentTypeId: Int64, transcodedContentTypeId: Int64?, mediaFolderId: Int64?, folderId: Int64?, artistId: Int64?, artistName: String?, albumId: Int64?, albumName: String?, genreId: Int64?, coverArtId: String?, title: String, duration: Int?, bitRate: Int?, trackNumber: Int?, discNumber: Int?, year: Int?, size: Int64, path: String, lastPlayed: Date?, genre: Genre?, contentType: ContentType?, transcodedContentType: ContentType?, repository: SongRepository = SongRepository.si) {
        self.songId = songId
        self.serverId = serverId
        
        self.contentTypeId = contentTypeId
        self.transcodedContentTypeId = transcodedContentTypeId
        self.mediaFolderId = mediaFolderId
        self.folderId = folderId
        self.artistId = artistId
        self.artistName = artistName
        self.albumId = albumId
        self.albumName = albumName
        self.genreId = genreId
        self.coverArtId = coverArtId
        self.title = title
        self.duration = duration
        self.bitRate = bitRate
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.size = size
        self.path = path
        
        self.lastPlayed = lastPlayed
        
        self.genre = genre
        self.contentType = contentType
        self.transcodedContentType = transcodedContentType
        
        self.repository = repository
    }
}

// Calcuated properties
extension Song {
    var currentContentType: ContentType? {
        return transcodedContentType ?? contentType
    }
    
    var basicType: BasicContentType? {
        return contentType?.basicType
    }
    
    // Automatically chooses either the artist/album model name or uses the song property if it's not available
    // NOTE: Not every song has an Artist or Album object in Subsonic. So when folder browsing this is especially
    // important.
    var artistDisplayName: String? {
        return artist?.name ?? artistName
    }
    var albumDisplayName: String? {
        return album?.name ?? albumName
    }
    
    var fileName: String {
        return "\(serverId)-\(songId)"
    }
    
    var localPath: String {
        return songCachePath + "/" + fileName
    }
    
    var localTempPath: String {
        return tempCachePath + "/" + fileName
    }
    
    var currentPath: String {
        return isTempCached ? localTempPath : localPath
    }
    
    var isTempCached: Bool {
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    var localFileSize: Int64 {
        // Using C instead of FileManager because of a weird crash on iOS 5 and up devices in the audio engine
        // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
        // Still waiting on Apple to fix their bug, so this is my (now 5 years old) "temporary" solution
        
        var fileInfo = stat()
        stat(currentPath, &fileInfo)
        return fileInfo.st_size
    }
    
    var fileExists: Bool {
        // Using C instead of FileManager because of a weird crash in the bass callback functions
        var fileInfo = stat()
        stat(currentPath, &fileInfo)
        return fileInfo.st_dev > 0
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
}
