//
//  Folder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

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
    
    init(folderId: Int64, serverId: Int64, parentFolderId: Int64?, mediaFolderId: Int64?, coverArtId: String?, name: String, repository: FolderRepository = FolderRepository.si) {
        self.folderId = folderId
        self.serverId = serverId
        
        self.parentFolderId = parentFolderId
        self.mediaFolderId = mediaFolderId
        self.coverArtId = coverArtId
        
        self.name = name
        
        self.repository = repository
    }
}
