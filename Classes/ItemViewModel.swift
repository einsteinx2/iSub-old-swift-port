//
//  ItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemViewModelDelegate {
    func itemsChanged()
    func loadingError(_ error: String)
}

typealias LoadModelsCompletion = (_ success: Bool, _ error: NSError?) -> Void

class ItemViewModel : NSObject {
    
    fileprivate let loader: ISMSItemLoader
    
    var delegate: ItemViewModelDelegate?
    
    var topLevelController = false
    
    fileprivate(set) var rootItem: ISMSItem?
    
    fileprivate(set) var items = [ISMSItem]()
    fileprivate(set) var folders = [ISMSFolder]()
    fileprivate(set) var artists = [ISMSArtist]()
    fileprivate(set) var albums = [ISMSAlbum]()
    fileprivate(set) var songs = [ISMSSong]()
    fileprivate(set) var playlists = [Playlist]()
    
    fileprivate(set) var songsDuration = 0
    fileprivate(set) var sectionIndexes = [SectionIndex]()
    
    init(loader: ISMSItemLoader) {
        self.loader = loader
        self.rootItem = loader.associatedObject as? ISMSItem
    }
    
    func loadModelsFromCache() -> Bool {
        let success = loader.loadModelsFromCache()
        if (success) {
            self.processModels()
        }
        
        return success
    }
    
    func loadModelsFromWeb(_ completion: LoadModelsCompletion?) {
        if loader.loaderState != .loading {
            loader.callbackBlock = { success, error, loader in
                if success {
                    self.processModels()
                    self.delegate?.itemsChanged()
                } else {
                    let errorString = error == nil ? "Unknown error" : error!.localizedDescription
                    self.delegate?.loadingError(errorString)
                }
            }
            
            loader.startLoad()
        }
    }
    
    func processModels() {
        // Reset models
        folders.removeAll()
        artists.removeAll()
        albums.removeAll()
        songs.removeAll()
        playlists.removeAll()
        
        guard let items = loader.items else {
            // No models to process
            return;
        }
        
        for item in items {
            switch item {
            case is ISMSFolder:   folders.append(item as! ISMSFolder)
            case is ISMSArtist:   artists.append(item as! ISMSArtist)
            case is ISMSAlbum:    albums.append(item as! ISMSAlbum)
            case is ISMSSong:     songs.append(item as! ISMSSong)
            case is Playlist:     playlists.append(item as! Playlist)
            default: assertionFailure("WHY YOU NO ITEM?")
            }
        }
        
        var duration = 0
        for song in songs {
            if let songDuration = song.duration {
                duration = duration + Int(songDuration)
            }
        }
        songsDuration = duration
        
        if songs.count == 0 {
            if folders.count > 20 {
                sectionIndexes = SectionIndex.sectionIndexesForItems(folders)
            } else if self.artists.count > 20 {
                sectionIndexes = SectionIndex.sectionIndexesForItems(artists)
            }
        }
    }
    
    func cancelLoad() {
        loader.cancelLoad()
    }
}
