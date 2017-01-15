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
    
    required init(result: FMResultSet, repository: ItemRepository = FolderRepository.si) {
        self.folderId       = result.long(forColumnIndex: 0)
        self.serverId       = result.long(forColumnIndex: 1)
        self.parentFolderId = result.object(forColumnIndex: 2) as? Int
        self.mediaFolderId  = result.object(forColumnIndex: 3) as? Int
        self.coverArtId     = result.string(forColumnIndex: 4)
        self.name           = result.string(forColumnIndex: 5) ?? ""
        self.repository     = repository as! FolderRepository
    }
}
