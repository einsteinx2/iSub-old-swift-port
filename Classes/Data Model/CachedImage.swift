//
//  CachedImage.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import Nuke

enum CachedImageSize {
    case cell
    case player
    case original
    
    var pixelSize: Int {
        switch self {
        case .cell: return 120
        case .player: return 640
        case .original: return -1
        }
    }
    
    var name: String {
        switch self {
        case .cell: return "cell"
        case .player: return "player"
        case .original: return "original"
        }
    }
}

struct CachedImage {
    static let preheater = Preheater()
    
    static func request(coverArtId: String, size: CachedImageSize) -> Request {
        var parameters = ["id": coverArtId]
        if size != .original {
            parameters["size"] = "\(size.pixelSize)"
        }
        let fragment = "s_\(SavedSettings.si.currentServerId)_id_\(coverArtId)_size_\(size.name)"
        let urlRequest = URLRequest(subsonicAction: .getCoverArt, parameters: parameters, fragment: fragment)
        var request = Request(urlRequest: urlRequest)
        request.cacheKey = fragment
        request.loadKey = fragment
        return request
    }
    
    static func preheat(coverArtId: String, size: CachedImageSize) {
        let request = self.request(coverArtId: coverArtId, size: size)
        preheater.startPreheating(with: [request])
    }
    
    static func cached(coverArtId: String, size: CachedImageSize) -> UIImage? {
        let request = self.request(coverArtId: coverArtId, size: size)
        let image = Cache.shared[request]
        return image
    }
    
    static func `default`(forSize size: CachedImageSize) -> UIImage {
        switch size {
        case .cell: return UIImage(named: "default-album-art-small")!
        case .player, .original: return UIImage(named: "default-album-art")!
        }
    }
    
//    static fileprivate func key(forCoverArtId coverArtId: String, serverId: Int, size: CachedImageSize) -> String {
//        let fragment = "s_\(serverId)_id_\(coverArtId)_size_\(size.name)"
//    }
//    
//    static fileprivate func imageFromDiskCache(coverArtId: String) -> UIImage {
//        return CacheManager.si.imageCache?.object(forKey: coverArtId)
//    }
}
