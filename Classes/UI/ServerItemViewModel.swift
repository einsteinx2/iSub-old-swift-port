//
//  ServerItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 3/18/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class ServerItemViewModel: ItemViewModel {
    override func cellActionSheet(forItem item: Item, indexPath: IndexPath) -> UIAlertController {
        let actionSheet = super.cellActionSheet(forItem: item, indexPath: indexPath)
        
        self.addPlayQueueActions(toActionSheet: actionSheet, forItem: item, indexPath: indexPath)
        self.addGoToRelatedActions(toActionSheet: actionSheet, forItem: item, indexPath: indexPath)
        
        if let song = item as? Song {
            if song.isFullyCached {
                actionSheet.addAction(UIAlertAction(title: "Remove from Downloads", style: .destructive) { action in
                    CacheManager.si.remove(song: song)
                    self.loadModelsFromDatabase()
                    self.delegate?.itemsChanged(viewModel: self)
                })
            } else {
                actionSheet.addAction(UIAlertAction(title: "Download", style: .default) { action in
                    CacheQueue.si.add(song: song)
                })
            }
        } else {
            actionSheet.addAction(UIAlertAction(title: "Download", style: .default) { action in
                let loader = RecursiveSongLoader(item: item)
                loader.completionHandler = { success, _, _ in
                    if success {
                        for song in loader.songs {
                            CacheQueue.si.add(song: song)
                        }
                    }
                }
                loader.start()
            })
        }
                
        return actionSheet
    }
    
    override func viewOptionsActionSheet() -> UIAlertController {
        let actionSheet = super.viewOptionsActionSheet()
        
        self.addSortOptions(toActionSheet: actionSheet)
        self.addDisplayOptions(toActionSheet: actionSheet)
                
        return actionSheet
    }
}
