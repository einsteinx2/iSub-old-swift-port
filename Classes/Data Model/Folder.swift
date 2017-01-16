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
    var songs = [Song]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int, mediaFolderId: Int, repository: FolderRepository = FolderRepository.si) {
        guard let folderId = element.attribute(asIntOptional: "id") else {
            return nil
        }
        
        self.folderId = folderId
        self.serverId = serverId
        self.parentFolderId = element.attribute(asIntOptional: "parent")
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
        self.folderId       = result.long(forColumnIndex: 0)
        self.serverId       = result.long(forColumnIndex: 1)
        self.parentFolderId = result.object(forColumnIndex: 2) as? Int
        self.mediaFolderId  = result.object(forColumnIndex: 3) as? Int
        self.coverArtId     = result.string(forColumnIndex: 4)
        self.name           = result.string(forColumnIndex: 5) ?? ""
        self.repository     = repository as! FolderRepository
    }
}
