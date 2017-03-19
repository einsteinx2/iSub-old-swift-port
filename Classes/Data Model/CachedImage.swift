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
    
    static func request(coverArtId: String, serverId: Int64, size: CachedImageSize) -> Request? {
        var parameters = ["id": coverArtId]
        if size != .original {
            parameters["size"] = "\(size.pixelSize)"
        }
        let fragment = "s_\(serverId)_id_\(coverArtId)_size_\(size.name)"
        if let urlRequest = URLRequest(subsonicAction: .getCoverArt, serverId: serverId, parameters: parameters, fragment: fragment) {
            var request = Request(urlRequest: urlRequest)
            request.cacheKey = fragment
            request.loadKey = fragment
            return request
        }
        return nil
    }
    
    static func preheat(coverArtId: String, serverId: Int64, size: CachedImageSize) {
        if let request = self.request(coverArtId: coverArtId, serverId: serverId, size: size) {
            preheater.startPreheating(with: [request])
        }
    }
    
    static func cached(coverArtId: String, serverId: Int64, size: CachedImageSize) -> UIImage? {
        if let request = self.request(coverArtId: coverArtId, serverId: serverId, size: size) {
            let image = Cache.shared[request]
            return image
        }
        return nil
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
