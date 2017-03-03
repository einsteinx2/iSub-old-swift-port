//
//  CachedRootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedRootFoldersLoader: CachedDatabaseLoader {
    var folders = [Folder]()

    override var items: [Item] {
        return folders
    }
    
    override var associatedItem: Item? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        folders = FolderRepository.si.rootFolders(isCachedTable: true)
        return true
    }
}
