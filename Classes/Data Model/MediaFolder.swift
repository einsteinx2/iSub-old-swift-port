//
//  MediaFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension MediaFolder: Item, Equatable {
    var itemId: Int64 { return mediaFolderId }
    var itemName: String { return name }
    var coverArtId: String? { return nil }
}

final class MediaFolder {
    let repository: MediaFolderRepository
    
    let mediaFolderId: Int64
    let serverId: Int64
    let name: String
    
    var folders = [Folder]()
    var songs = [Song]()
    
    init(mediaFolderId: Int64, serverId: Int64, name: String, repository: MediaFolderRepository = MediaFolderRepository.si) {
        self.mediaFolderId = mediaFolderId
        self.serverId = serverId
        self.name = name
        
        self.repository = repository
    }
}
