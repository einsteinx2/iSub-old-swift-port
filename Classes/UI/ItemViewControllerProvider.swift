//
//  ItemViewControllerProvider.swift
//  iSub
//
//  Created by Benjamin Baron on 3/18/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

func itemViewController(forItem item: Item, isBrowsingCache: Bool) -> ItemViewController? {
    if isBrowsingCache {
        switch item {
        case let item as Folder:
            let loader = CachedFolderLoader(folderId: item.itemId, serverId: item.serverId)
            let viewModel = CachedItemViewModel(loader: loader)
            return FolderViewController(viewModel: viewModel)
        case let item as Artist:
            let loader = CachedArtistLoader(artistId: item.itemId, serverId: item.serverId)
            let viewModel = CachedItemViewModel(loader: loader)
            return ArtistViewController(viewModel: viewModel)
        case let item as Album:
            let loader = CachedAlbumLoader(albumId: item.itemId, serverId: item.serverId)
            let viewModel = CachedItemViewModel(loader: loader)
            return AlbumViewController(viewModel: viewModel)
        default:
            break
        }
    } else {
        switch item {
        case let item as Folder:
            if let mediaFolderId = item.mediaFolderId {
                let loader = FolderLoader(folderId: item.itemId, serverId: item.serverId, mediaFolderId: mediaFolderId)
                let viewModel = ServerItemViewModel(loader: loader)
                return FolderViewController(viewModel: viewModel)
            }
        case let item as Artist:
            let loader = ArtistLoader(artistId: item.itemId, serverId: item.serverId)//, mediaFolderId: mediaFolderId)
            let viewModel = ServerItemViewModel(loader: loader)
            return ArtistViewController(viewModel: viewModel)
        case let item as Album:
            let loader = AlbumLoader(albumId: item.itemId, serverId: item.serverId)//, mediaFolderId: mediaFolderId)
            let viewModel = ServerItemViewModel(loader: loader)
            return AlbumViewController(viewModel: viewModel)
        case let item as Playlist:
            let loader = PlaylistLoader(playlistId: item.itemId, serverId: item.serverId)
            let viewModel = ServerItemViewModel(loader: loader)
            return PlaylistViewController(viewModel: viewModel)
        default:
            break
        }
    }
    
    return nil
}
