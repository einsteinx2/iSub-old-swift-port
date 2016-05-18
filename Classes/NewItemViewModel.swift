//
//  NewItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import libSub
import Foundation

protocol NewItemViewModelDelegate {
    func itemsChanged()
    func loadingError(error: String)
}

typealias LoadModelsCompletion = (success: Bool, error: NSError?) -> Void

class NewItemViewModel : NSObject {
    
    private let loader: ISMSItemLoader
    
    var delegate: NewItemViewModelDelegate?
    
    var topLevelController = false
    
    private(set) var rootItem: ISMSItem?
    
    private(set) var items = [ISMSItem]()
    private(set) var folders = [ISMSFolder]()
    private(set) var artists = [ISMSArtist]()
    private(set) var albums = [ISMSAlbum]()
    private(set) var songs = [ISMSSong]()
    private(set) var playlists = [Playlist]()
    
    private(set) var songsDuration = 0
    private(set) var sectionIndexes = [SectionIndex]()
    
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
    
    func loadModelsFromWeb(completion: LoadModelsCompletion?) {
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
                sectionIndexes = sectionIndexesForItems(folders)
            } else if self.artists.count > 20 {
                sectionIndexes = sectionIndexesForItems(artists)
            }
        }
    }
    
    func cancelLoad() {
        loader.cancelLoad()
    }
}