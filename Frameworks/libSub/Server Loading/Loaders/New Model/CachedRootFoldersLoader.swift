//
//  CachedRootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootFoldersLoader: CachedDatabaseLoader {
    var folders = [ISMSFolder]()

    override var items: [ISMSItem] {
        return folders
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        folders = ISMSFolder.topLevelCachedFolders()
        return true
    }
}
