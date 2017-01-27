//
//  Folder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum SongSortOrder: Int {
    case track  = 0
    case title  = 1
    case artist = 2
    case album  = 3
}

extension Folder: Item, Equatable {
    var itemId: Int64 { return folderId }
    var itemName: String { return name }
}

final class Folder {
    let repository: FolderRepository
    
    let folderId: Int64
    let serverId: Int64
    
    let parentFolderId: Int64?
    let mediaFolderId: Int64?
    let coverArtId: String?
    
    let name: String
    
    var songSortOrder: SongSortOrder = .track
    
    var folders = [Folder]()
    var songs = [Song]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int64, mediaFolderId: Int64, repository: FolderRepository = FolderRepository.si) {
        guard let folderId = element.attribute(asInt64Optional: "id") else {
            return nil
        }
        
        self.folderId = folderId
        self.serverId = serverId
        self.parentFolderId = element.attribute(asInt64Optional: "parent")
        self.mediaFolderId = mediaFolderId
        self.coverArtId = element.attribute(asStringOptional: "coverArt")
        if let name = element.attribute(asStringOptional: "title") {
            self.name = name.clean
        } else if let name = element.attribute(asStringOptional: "name") {
            self.name = name.clean
        } else {
            self.name = ""
        }
        self.repository = repository
    }
    
    required init(result: FMResultSet, repository: ItemRepository = FolderRepository.si) {
        self.folderId       = result.longLongInt(forColumnIndex: 0)
        self.serverId       = result.longLongInt(forColumnIndex: 1)
        self.parentFolderId = result.object(forColumnIndex: 2) as? Int64
        self.mediaFolderId  = result.object(forColumnIndex: 3) as? Int64
        self.coverArtId     = result.string(forColumnIndex: 4)
        self.name           = result.string(forColumnIndex: 5) ?? ""
        self.songSortOrder  = SongSortOrder(rawValue: result.long(forColumnIndex: 6)) ?? .track
        self.repository     = repository as! FolderRepository
    }
}
