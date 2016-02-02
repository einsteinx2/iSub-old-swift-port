//
//  NewItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

public protocol NewItemViewModelDelegate {
    func itemsChanged()
    func loadingError(error: String)
}

public typealias LoadModelsCompletion = (success: Bool, error: NSError?) -> Void

public class NewItemViewModel : NSObject {
    
    private let _loader: ISMSItemLoader
    
    public var delegate: NewItemViewModelDelegate?
    
    public private(set) var rootItem: ISMSItem?
    
    public private(set) var items = [ISMSItem]()
    public private(set) var folders = [ISMSFolder]()
    public private(set) var artists = [ISMSArtist]()
    public private(set) var albums = [ISMSAlbum]()
    public private(set) var songs = [ISMSSong]()
    public private(set) var playlists = [ISMSPlaylist]()
    
    public private(set) var songsDuration = 0
    public private(set) var sectionIndexes = [ISMSSectionIndex]()
    
    init(loader: ISMSItemLoader) {
        _loader = loader
        rootItem = loader.associatedObject as? ISMSItem
    }
    
    public func loadModelsFromCache() -> Bool {
        let success = _loader.loadModelsFromCache()
        if (success) {
            self.processModels()
        }
        
        return success
    }
    
    public func loadModelsFromWeb(completion: LoadModelsCompletion?) {
        _loader.callbackBlock = { success, error, loader in
            if success {
                self.processModels()
                self.delegate?.itemsChanged()
            } else {
                let errorString = error == nil ? "Unknown error" : error!.localizedDescription
                self.delegate?.loadingError(errorString)
            }
        }
        
        _loader.startLoad()
    }
    
    // Eventually only do this if they've actually changed
    private func processModels() {
        _loader.persistModels()
        
        guard let items = _loader.items else {
            // No models to process
            return;
        }
        
        for item in items {
            switch item {
            case is ISMSFolder:   self.folders.append(item as! ISMSFolder)
            case is ISMSArtist:   self.artists.append(item as! ISMSArtist)
            case is ISMSAlbum:    self.albums.append(item as! ISMSAlbum)
            case is ISMSSong:     self.songs.append(item as! ISMSSong)
            case is ISMSPlaylist: self.playlists.append(item as! ISMSPlaylist)
            default: assertionFailure("WHY YOU NO ITEM?")
            }
        }
        
        var duration = 0
        for song in self.songs {
            if let songDuration = song.duration {
                duration = duration + Int(songDuration)
            }
        }
        self.songsDuration = duration
        
        if self.songs.count == 0 {
            if self.folders.count > 20 {
                self.sectionIndexes = sectionIndexesForItems(self.folders)
            } else if self.artists.count > 20 {
                self.sectionIndexes = sectionIndexesForItems(self.artists)
            }
        }
    }
    
    public func cancelLoad() {
        _loader.cancelLoad()
    }
}