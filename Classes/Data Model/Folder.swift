//
//  Folder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Folder: Item {
    var itemId: Int { return folderId }
    var itemName: String { return name }
    
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = FolderRepository.si) -> Item? {
        return (repository as? FolderRepository)?.folder(folderId: itemId, serverId: serverId)
    }
}

class Folder {
    let repository: FolderRepository
    
    let folderId: Int
    let serverId: Int
    
    let parentFolderId: Int?
    let mediaFolderId: Int?
    let coverArtId: String?
    
    let name: String
    
    var folders = [Folder]()
    var songs = [ISMSSong]()
    
    init(folderId: Int, serverId: Int, parentFolderId: Int?, mediaFolderId: Int?, coverArtId: String?, name: String, repository: FolderRepository = FolderRepository.si) {
        self.folderId = folderId
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        self.mediaFolderId = mediaFolderId
        self.coverArtId = coverArtId
        self.name = name
        self.repository = repository
    }
}
