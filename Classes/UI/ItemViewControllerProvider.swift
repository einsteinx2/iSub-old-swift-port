//
//  ItemViewControllerProvider.swift
//  iSub
//
//  Created by Benjamin Baron on 3/18/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate func loader(forItem item: Item, isBrowsingCache: Bool) -> PersistedItemLoader? {
    if isBrowsingCache {
        switch item {
        case let item as Folder:
            return CachedFolderLoader(folderId: item.itemId, serverId: item.serverId)
        case let item as Artist:
            return CachedArtistLoader(artistId: item.itemId, serverId: item.serverId)
        case let item as Album:
            return CachedAlbumLoader(albumId: item.itemId, serverId: item.serverId)
        default:
            break
        }
    } else {
        switch item {
        case let item as Folder:
            if let mediaFolderId = item.mediaFolderId {
                return FolderLoader(folderId: item.itemId, serverId: item.serverId, mediaFolderId: mediaFolderId)
            }
        case let item as Artist:
            return ArtistLoader(artistId: item.itemId, serverId: item.serverId)//, mediaFolderId: mediaFolderId)
        case let item as Album:
            return AlbumLoader(albumId: item.itemId, serverId: item.serverId)//, mediaFolderId: mediaFolderId)
        case let item as Playlist:
            return PlaylistLoader(playlistId: item.itemId, serverId: item.serverId)
        default:
            break
        }
    }
    
    return nil
}

func itemViewController(forLoader loader: PersistedItemLoader) -> ItemViewController? {
    let viewModel = loader is CachedDatabaseLoader ? CachedItemViewModel(loader: loader) : ServerItemViewModel(loader: loader)
    
    switch viewModel.rootItem {
    case is Folder:
        return FolderViewController(viewModel: viewModel)
    case is Artist:
        return ArtistViewController(viewModel: viewModel)
    case is Album:
        return AlbumViewController(viewModel: viewModel)
//    case is Playlist:
//        return PlaylistViewController(with: viewModel)
    default:
        return nil
    }
}

func itemViewController(forItem item: Item, isBrowsingCache: Bool) -> ItemViewController? {
    if let loader = loader(forItem: item, isBrowsingCache: isBrowsingCache) {
        return itemViewController(forLoader: loader)
    }
    return nil
}
