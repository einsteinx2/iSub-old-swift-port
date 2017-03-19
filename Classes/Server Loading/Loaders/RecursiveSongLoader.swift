//
//  RecursiveSongLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 2/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

// TODO: Control songs array order
class RecursiveSongLoader: ApiLoader, ItemLoader {
    var associatedItem: Item?
    
    var songs = [Song]()
    var songsDuration = 0
    
    var items: [Item] {
        return songs
    }
    
    fileprivate let operationQueue = OperationQueue()
    
    init(item: Item) {
        super.init(serverId: item.serverId)
        self.associatedItem = item
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    override func start() {
        guard let associatedItem = associatedItem else {
            return
        }
        
        songs = [Song]()
        
        processItem(item: associatedItem)
        if associatedItem is Song {
            finished()
        }
    }
    
    override func cancel() {
        operationQueue.cancelAllOperations()
    }
    
    fileprivate func subloaderFinished(success: Bool, error: Error?, loader: ApiLoader) {
        if success {
            if let loader = loader as? ItemLoader {
                for item in loader.items {
                    processItem(item: item)
                }
            }
            
            print("subloader finished, \(operationQueue.operationCount) currently in queue")
            
            // We're done
            if operationQueue.operationCount == 0 {
                print("all subloaders finished, done")
                finished()
            }
        } else {
            // For now, treat any loading failure as a complete failure
            operationQueue.cancelAllOperations()
            failed(error: error)
        }
    }
    
    fileprivate func processItem(item: Item) {
        print("Processing item: \(item)")//\(item.itemId) - \(item.itemName)")
        
        var loader: ItemLoader?
        switch item {
        case let song as Song:
            songs.append(song)
        case let folder as Folder:
            loader = FolderLoader(folderId: folder.folderId, serverId: folder.serverId)
        case let artist as Artist:
            loader = ArtistLoader(artistId: artist.artistId, serverId: artist.serverId)
        case let album as Album:
            loader = AlbumLoader(albumId: album.albumId, serverId: album.serverId)
        case let playlist as Playlist:
            loader = PlaylistLoader(playlistId: playlist.playlistId, serverId: playlist.serverId)
        default:
            break
        }
        
        if var loader = loader {
            loader.completionHandler = subloaderFinished
            let operation = ItemLoaderOperation(loader: loader, onlyLoadIfNotExists: false)
            operationQueue.addOperation(operation)
        }
    }
}

// Not implemented
extension RecursiveSongLoader {
    func persistModels() {
        fatalError("Do not persist models from the RecursiveSongLoader, it's done by the sub-loaders")
    }
    
    func loadModelsFromDatabase() -> Bool {
        fatalError("Do not load models using the RecursiveSongLoader, use the appropriate repository class")
    }
}
