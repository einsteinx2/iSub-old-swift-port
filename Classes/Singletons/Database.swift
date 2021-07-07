//
//  Database.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class Database {
    static let si = Database()
    
    static let databaseFolderPath = documentsPath + "/database"
    static let databasePath = databaseFolderPath + "/newSongModel.db"
    
    var write: FMDatabaseQueue!
    var read: FMDatabasePool!
    
    func setup() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Database.databaseFolderPath) {
            try? fileManager.createDirectory(atPath: Database.databaseFolderPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        setupDatabases()
    }
    
    func setupDatabases() {
        log.debug("sqlite3 \(Database.databasePath)")
        
        read = FMDatabasePool(path: Database.databasePath)
        read.maximumNumberOfDatabasesToCreate = 20
        read.delegate = self
        
        write = FMDatabaseQueue(path: Database.databasePath)
        
        write.inDatabase { db in
            db.executeStatements("PRAGMA journal_mode=WAL")

            if !db.tableExists("cachedSongsMetadata") {
                try? db.executeUpdate("CREATE TABLE cachedSongsMetadata (songId INTEGER, serverId INTEGER, partiallyCached INTEGER, fullyCached INTEGER, pinned INTEGER, PRIMARY KEY (songId, serverId))")
            }
            
            if !db.tableExists("contentTypes") {
                try? db.executeUpdate("CREATE TABLE contentTypes (contentTypeId INTEGER PRIMARY KEY, mimeType TEXT, extension TEXT, basicType TEXT)")
                try? db.executeUpdate("CREATE INDEX contentTypes_mimeTypeExtension ON contentTypes (mimeType, extension)")
                
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/mpeg", "mp3", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/ogg", "ogg", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/ogg", "oga", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/ogg", "opus", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/ogg", "ogx", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/mp4", "aac", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/mp4", "m4a", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/flac", "flac", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/x-wav", "wav", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/x-ms-wma", "wma", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/x-monkeys-audio", "ape", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/x-musepack", "mpc", 1)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "audio/x-shn", "shn", 1)
                
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/x-flv", "flv", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/avi", "avi", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/mpeg", "mpg", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/mpeg", "mpeg", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/mp4", "mp4", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/x-m4v", "m4v", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/x-matroska", "mkv", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/quicktime", "mov", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/x-ms-wmv", "wmv", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/ogg", "ogv", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/divx", "divx", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/MP2T", "m2ts", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/MP2T", "ts", 2)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "video/webm", "webm", 2)
                
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "image/gif", "gif", 3)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "image/jpeg", "jpg", 3)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "image/jpeg", "jpeg", 3)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "image/png", "png", 3)
                try? db.executeUpdate("INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", "image/bmp", "bmp", 3)
            }
            
            if !db.tableExists("mediaFolders") {
                try? db.executeUpdate("CREATE TABLE mediaFolders (mediaFolderId INTEGER, serverId INTEGER, name TEXT, PRIMARY KEY (mediaFolderId, serverId))")
            }
            
            if !db.tableExists("ignoredArticles") {
                try? db.executeUpdate("CREATE TABLE ignoredArticles (articleId INTEGER, serverId INTEGER, name TEXT, PRIMARY KEY (articleId, serverId))")
            }
            
            if !db.tableExists("folders") {
                try? db.executeUpdate("CREATE TABLE folders (folderId INTEGER, serverId INTEGER, parentFolderId INTEGER, mediaFolderId INTEGER, coverArtId TEXT, name TEXT, songSortOrder INTEGER, PRIMARY KEY (folderId, serverId))")
                try? db.executeUpdate("CREATE INDEX folders_parentFolderId ON folders (parentFolderId)")
                try? db.executeUpdate("CREATE INDEX folders_mediaFolderId ON folders (mediaFolderId)")
            }
            
            if !db.tableExists("cachedFolders") {
                try? db.executeUpdate("CREATE TABLE cachedFolders (folderId INTEGER, serverId INTEGER, parentFolderId INTEGER, mediaFolderId INTEGER, coverArtId TEXT, name TEXT, songSortOrder INTEGER, PRIMARY KEY (folderId, serverId))")
                try? db.executeUpdate("CREATE INDEX cachedFolders_parentFolderId ON cachedFolders (parentFolderId)")
                try? db.executeUpdate("CREATE INDEX cachedFolders_mediaFolderId ON cachedFolders (mediaFolderId)")
            }
                        
            if !db.tableExists("artists") {
                try? db.executeUpdate("CREATE TABLE artists (artistId INTEGER, serverId INTEGER, name TEXT, coverArtid TEXT, albumCount INTEGER, PRIMARY KEY (artistId, serverId))")
            }
            if !db.columnExists("albumSortOrder", inTableWithName: "artists") {
                try? db.executeUpdate("ALTER TABLE artists ADD COLUMN albumSortOrder INTEGER")
            }
            
            if !db.tableExists("cachedArtists") {
                try? db.executeUpdate("CREATE TABLE cachedArtists (artistId INTEGER, serverId INTEGER, name TEXT, coverArtId TEXT, albumCount INTEGER, PRIMARY KEY (artistId, serverId))")
            }
            if !db.columnExists("albumSortOrder", inTableWithName: "cachedArtists") {
                try? db.executeUpdate("ALTER TABLE cachedArtists ADD COLUMN albumSortOrder INTEGER")
            }
            
            if !db.tableExists("albums") {
                try? db.executeUpdate("CREATE TABLE albums (albumId INTEGER, serverId INTEGER, artistId INTEGER, genreId INTEGER, coverArtId TEXT, name TEXT, songCount INTEGER, duration INTEGER, year INTEGER, created REAL, PRIMARY KEY (albumId, serverId))")
            }
            if !db.columnExists("artistName", inTableWithName: "albums") {
                try? db.executeUpdate("ALTER TABLE albums ADD COLUMN artistName TEXT")
            }
            if !db.columnExists("songSortOrder", inTableWithName: "albums") {
                try? db.executeUpdate("ALTER TABLE albums ADD COLUMN songSortOrder INTEGER")
            }
            
            if !db.tableExists("cachedAlbums") {
                try? db.executeUpdate("CREATE TABLE cachedAlbums (albumId INTEGER, serverId INTEGER, artistId INTEGER, genreId INTEGER, coverArtId TEXT, name TEXT, songCount INTEGER, duration INTEGER, year INTEGER, created REAL, PRIMARY KEY (albumId, serverId))")
            }
            if !db.columnExists("artistName", inTableWithName: "cachedAlbums") {
                try? db.executeUpdate("ALTER TABLE cachedAlbums ADD COLUMN artistName TEXT")
            }
            if !db.columnExists("songSortOrder", inTableWithName: "cachedAlbums") {
                try? db.executeUpdate("ALTER TABLE cachedAlbums ADD COLUMN songSortOrder INTEGER")
            }
            
            if !db.tableExists("songs") {
                try? db.executeUpdate("CREATE TABLE songs (songId INTEGER, serverId INTEGER, contentTypeId INTEGER, transcodedContentTypeId INTEGER, mediaFolderId INTEGER, folderId INTEGER, artistId INTEGER, albumId INTEGER, genreId TEXT, coverArtId TEXT, title TEXT, duration INTEGER, bitrate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, path TEXT, lastPlayed REAL, artistName TEXT, albumName TEXT, PRIMARY KEY (songId, serverId))")
                try? db.executeUpdate("CREATE INDEX songs_mediaFolderId ON songs (mediaFolderId)")
                try? db.executeUpdate("CREATE INDEX songs_folderId ON songs (folderId)")
                try? db.executeUpdate("CREATE INDEX songs_artistId ON songs (artistId)")
                try? db.executeUpdate("CREATE INDEX songs_albumId ON songs (albumId)")
            }
            
            if !db.tableExists("cachedSongs") {
                try? db.executeUpdate("CREATE TABLE cachedSongs (songId INTEGER, serverId INTEGER, contentTypeId INTEGER, transcodedContentTypeId INTEGER, mediaFolderId INTEGER, folderId INTEGER, artistId INTEGER, albumId INTEGER, genreId TEXT, coverArtId TEXT, title TEXT, duration INTEGER, bitrate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, path TEXT, lastPlayed REAL, artistName TEXT, albumName TEXT, PRIMARY KEY (songId, serverId))")
                try? db.executeUpdate("CREATE INDEX cachedSongs_mediaFolderId ON cachedSongs (mediaFolderId)")
                try? db.executeUpdate("CREATE INDEX cachedSongs_folderId ON cachedSongs (folderId)")
                try? db.executeUpdate("CREATE INDEX cachedSongs_artistId ON cachedSongs (artistId)")
                try? db.executeUpdate("CREATE INDEX cachedSongs_albumId ON cachedSongs (albumId)")
            }
            
            if !db.tableExists("genres") {
                try? db.executeUpdate("CREATE TABLE genres (genreId INTEGER PRIMARY KEY, name TEXT)")
                try? db.executeUpdate("CREATE INDEX genres_name ON genres (name)")
            }
            
            if !db.tableExists("playlists") {
                try? db.executeUpdate("CREATE TABLE playlists (playlistId INTEGER, serverId INTEGER, name TEXT, coverArtId TEXT, PRIMARY KEY (playlistId, serverId))")
                try? db.executeUpdate("CREATE INDEX playlists_name ON playlists (name)")
            }
            
            // NOTE: Passwords stored in the keychain
            if !db.tableExists("servers") {
                try? db.executeUpdate("CREATE TABLE servers (serverId INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER, url TEXT, username TEXT)")
            }
            if !db.columnExists("basicAuth", inTableWithName: "servers") {
                try? db.executeUpdate("ALTER TABLE servers ADD COLUMN basicAuth INTEGER")
            }
            if !db.columnExists("legacyAuth", inTableWithName: "servers") {
                try? db.executeUpdate("ALTER TABLE servers ADD COLUMN legacyAuth INTEGER")
            }
        }
        
        // Create the default playlist tables
        let serverId = SavedSettings.si.currentServerId
        PlaylistRepository.si.createDefaultPlaylists(serverId: serverId)
    }
    
    func closeAll() {
        read.releaseAllDatabases()
        write.close()
    }
    
    func resetFolderCache() {
        // TODO: Reimplement this joining the song and playlist tables to leave only records belonging to the downloaded songs
        write.inDatabase { db in
            try? db.executeUpdate("DELETE FROM folders")
            try? db.executeUpdate("DELETE FROM artists")
            try? db.executeUpdate("DELETE FROM albums")
            try? db.executeUpdate("DELETE FROM songs")
            try? db.executeUpdate("DELETE FROM genres")
        }
    }
}
