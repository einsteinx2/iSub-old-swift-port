//
//  RootServerItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 3/18/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class RootServerItemViewModel: ServerItemViewModel {
    override var isTopLevelController: Bool {
        return true
    }
    
    override func viewOptionsActionSheet() -> UIAlertController {
        let actionSheet = super.viewOptionsActionSheet()
        
        if MediaFolderRepository.si.allMediaFolders(serverId: SavedSettings.si.currentServerId).count > 1 {
            actionSheet.addAction(UIAlertAction(title: "Choose Media Folder", style: .default) { action in
                self.chooseMediaFolder()
            })
        }
                
        return actionSheet
    }
    
    fileprivate func chooseMediaFolder() {
        let mediaFolders = MediaFolderRepository.si.allMediaFolders(serverId: SavedSettings.si.currentServerId)
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "All", style: .default) { action in
            self.loadMediaFolder(nil)
        })
        for mediaFolder in mediaFolders {
            alertController.addAction(UIAlertAction(title: mediaFolder.name, style: .default) { action in
                self.loadMediaFolder(mediaFolder)
            })
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        delegate?.presentActionSheet(alertController, viewModel: self)
    }
    
    fileprivate func loadMediaFolder(_ mediaFolder: MediaFolder?) {
        mediaFolderId = mediaFolder?.mediaFolderId
        loadModelsFromDatabase()
        loadModelsFromWeb()
    }
}
