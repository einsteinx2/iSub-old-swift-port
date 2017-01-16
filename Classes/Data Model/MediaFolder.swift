//
//  MediaFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension MediaFolder: Item {
    var itemId: Int { return mediaFolderId }
    var itemName: String { return name }
}

class MediaFolder {
    let repository: MediaFolderRepository
    
    let mediaFolderId: Int
    let serverId: Int
    let name: String
    
    var folders = [Folder]()
    var songs = [Song]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int, repository: MediaFolderRepository = MediaFolderRepository.si) {
        guard let mediaFolderId = element.attribute(asIntOptional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }

        self.mediaFolderId = mediaFolderId
        self.serverId = serverId
        self.name = name
        self.repository = repository
    }
    
    required init(result: FMResultSet, repository: ItemRepository = MediaFolderRepository.si) {
        self.mediaFolderId = result.long(forColumnIndex: 0)
        self.serverId      = result.long(forColumnIndex: 1)
        self.name          = result.string(forColumnIndex: 2) ?? ""
        self.repository    = repository as! MediaFolderRepository
    }
}
