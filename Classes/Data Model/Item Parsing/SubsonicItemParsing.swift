//
//  SubsonicItemParsing.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 11/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension MediaFolder {
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, repository: MediaFolderRepository = MediaFolderRepository.si) {
        guard let mediaFolderId = element.attribute(asInt64Optional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        self.init(mediaFolderId: mediaFolderId, serverId: serverId, name: name, repository: repository)
    }
}

extension Folder {
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, mediaFolderId: Int64, repository: FolderRepository = FolderRepository.si) {
        guard let folderId = element.attribute(asInt64Optional: "id") else {
            return nil
        }
        
        let parentFolderId = element.attribute(asInt64Optional: "parent")
        let coverArtId = element.attribute(asStringOptional: "coverArt")
        var name = ""
        if let maybeName = element.attribute(asStringOptional: "title") {
            name = maybeName.clean
        } else if let maybeName = element.attribute(asStringOptional: "name") {
            name = maybeName.clean
        }
        
        self.init(folderId: folderId, serverId: serverId, parentFolderId: parentFolderId, mediaFolderId: mediaFolderId, coverArtId: coverArtId, name: name, repository: repository)
    }
}

extension Artist {
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, repository: ArtistRepository = ArtistRepository.si) {
        guard let artistId = element.attribute(asInt64Optional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        let coverArtId = element.attribute(asStringOptional: "coverArtId")
        let albumCount = element.attribute(asIntOptional: "albumCount")
        
        self.init(artistId: artistId, serverId: serverId, name: name, coverArtId: coverArtId, albumCount: albumCount, repository: repository)
    }
}

fileprivate let createdDateFormatter: DateFormatter = {
    let createdDateFormatter = DateFormatter()
    createdDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    return createdDateFormatter
}()

extension Album {
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, repository: AlbumRepository = AlbumRepository.si) {
        guard let albumId = element.attribute(asInt64Optional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        let artistId = element.attribute(asInt64Optional: "artistId")
        let coverArtId = element.attribute("coverArt")?.clean
        let songCount = element.attribute(asIntOptional: "songCount")
        let duration = element.attribute(asIntOptional: "duration")
        let year = element.attribute(asIntOptional: "year")
        let artistName = element.attribute(asStringOptional: "artist")
        var genreId: Int64? = nil
        if let genreString = element.attribute(asStringOptional: "genre") {
            let genre = GenreRepository.si.genre(name: genreString)
            // TODO: Figure out why this ever returns a nil genre, it should be impossible without a database error
            // which should also be impossible
            genreId = genre?.genreId
        }
        var created: Date? = nil
        if let createdString = element.attribute(asStringOptional: "created") {
            created = createdDateFormatter.date(from: createdString)
        }
        
        self.init(albumId: albumId, serverId: serverId, artistId: artistId, genreId: genreId, coverArtId: coverArtId, name: name, songCount: songCount, duration: duration, year: year, created: created, artistName: artistName, repository: repository)
    }
}

extension Song {
    // TODO: Handle media folder id
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, repository: SongRepository = SongRepository.si) {
        guard let songId = element.attribute(asInt64Optional: "id"), let title = element.attribute(asStringOptional: "title")?.clean else {
            return nil
        }
        
        let folderId = element.attribute(asInt64Optional: "parent")
        let artistId = element.attribute(asInt64Optional: "artistId")
        let albumId = element.attribute(asInt64Optional: "albumId")
        let coverArtId = element.attribute(asStringOptional: "coverArt")
        
        let duration = element.attribute(asIntOptional: "duration")
        let bitRate = element.attribute(asIntOptional: "bitRate")
        let trackNumber = element.attribute(asIntOptional: "track")
        let discNumber = element.attribute(asIntOptional: "discNumber")
        let year = element.attribute(asIntOptional: "year")
        let size = element.attribute(asInt64: "size")
        let path = element.attribute("path")?.clean ?? ""
        
        let artistName = element.attribute("artist")?.clean
        let albumName = element.attribute("album")?.clean
        
        // Retreive contentTypeId
        var contentType: ContentType?
        var contentTypeId: Int64 = -1
        if let contentTypeString = element.attribute(asStringOptional: "contentType"), let maybeContentType = ContentTypeRepository.si.contentType(mimeType: contentTypeString) {
            contentType = maybeContentType
            contentTypeId = maybeContentType.contentTypeId
        }
        
        // Retreive transcodedContentTypeId
        var transcodedContentType: ContentType?
        var transcodedContentTypeId: Int64?
        if let transcodedContentTypeString = element.attribute(asStringOptional: "transcodedContentType"), let maybeTranscodedContentType = ContentTypeRepository.si.contentType(mimeType: transcodedContentTypeString) {
            transcodedContentType = maybeTranscodedContentType
            transcodedContentTypeId = maybeTranscodedContentType.contentTypeId
        }
        
        // Retreive genreId
        var genre: Genre? = nil
        var genreId: Int64? = nil
        if let genreString = element.attribute(asStringOptional: "genre"), let maybeGenre = GenreRepository.si.genre(name: genreString) {
            genre = maybeGenre
            genreId = maybeGenre.genreId
        }
        
        // Retreive lastPlayed date, if it exists
        let lastPlayed = repository.lastPlayed(songId: songId, serverId: serverId)

        self.init(songId: songId, serverId: serverId, contentTypeId: contentTypeId, transcodedContentTypeId: transcodedContentTypeId, mediaFolderId: nil, folderId: folderId, artistId: artistId, artistName: artistName, albumId: albumId, albumName: albumName, genreId: genreId, coverArtId: coverArtId, title: title, duration: duration, bitRate: bitRate, trackNumber: trackNumber, discNumber: discNumber, year: year, size: size, path: path, lastPlayed: lastPlayed, genre: genre, contentType: contentType, transcodedContentType: transcodedContentType, repository: repository)
    }
}

extension Playlist {
    convenience init?(rxmlElement element: RXMLElement, serverId: Int64, repository: PlaylistRepository = PlaylistRepository.si) {
        guard let playlistId = element.attribute(asInt64Optional: "id") else {
            return nil
        }
        
        let name = element.attribute("name") ?? ""
        let coverArtId = element.attribute(asStringOptional: "coverArt")
        
        self.init(playlistId: playlistId, serverId: serverId, name: name, coverArtId: coverArtId, repository: repository)
    }
}
