//
//  File.swift
//  iSub
//
//  Created by Benjamin Baron on 1/13/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum SubsonicURLAction: String {
    case getMusicFolders   = "getMusicFolders"
    case getIndexes        = "getIndexes"
    case getArtists        = "getArtists"
    case getAlbumList2     = "getAlbumList2"
    case getPlaylists      = "getPlaylists"
    case getMusicDirectory = "getMusicDirectory"
    case getArtist         = "getArtist"
    case getAlbum          = "getAlbum"
    case getPlaylist       = "getPlaylist"
    case getCoverArt       = "getCoverArt"
    case stream            = "stream"
    case hls               = "hls"
    case ping              = "ping"
    
    var urlExtension: String {
        return self == .hls ? "m3u8" : "view"
    }
    
    var timeout: TimeInterval {
        switch self {
        case .getPlaylist: return 3600.0
        case .getCoverArt: return 30.0
        case .ping:        return ISMSServerCheckTimeout
        default:           return ISMSLoadingTimeout
        }
    }
}

fileprivate func encodedParameter(_ value: Any) -> String {
    if let value = value as? String {
        return value.URLQueryParameterEncodedValue
    } else {
        return "\(value)"
    }
}

extension URLRequest {
    init(subsonicAction: SubsonicURLAction, parameters: [String: Any]? = nil, fragment: String? = nil, byteOffset: Int = 0) {
        let baseUrl = SavedSettings.si().redirectUrlString ?? SavedSettings.si().currentServer.url
        let currentServer = SavedSettings.si().currentServer
        self.init(subsonicAction: subsonicAction,
                  baseUrl: baseUrl,
                  username: currentServer.username,
                  password: currentServer.password ?? "",
                  parameters: parameters,
                  fragment: fragment,
                  byteOffset: byteOffset)
    }
    
    init(subsonicAction: SubsonicURLAction, baseUrl: String, username: String, password: String, parameters: [String: Any]? = nil, fragment: String? = nil, byteOffset: Int = 0) {
        
        var urlString = "\(baseUrl)/rest/\(subsonicAction.rawValue).\(subsonicAction.urlExtension)"
        if let fragment = fragment {
            urlString += "#\(fragment)"
        }
        
        // Generate a 32 character random salt
        // Then use the Subsonic required md5(password + salt) function to generate the token.
        let salt = String.random(32)
        let token = (password + salt).md5.lowercased()
        
        // Only support Subsonic version 5.3 and later
        let version = "1.13.0"
        
        // Setup the post body
        var parametersString = "?c=iSub&v=\(version)&u=\(username)&t=\(token)&s=\(salt)"
        if let parameters = parameters {
            for (key, value) in parameters {
                if let value = value as? [Any] {
                    for subValue in value {
                        parametersString += "&\(key)=\(encodedParameter(subValue))"
                    }
                } else {
                    parametersString += "&\(key)=\(encodedParameter(value))"
                }
            }
        }
        urlString += parametersString
        
        self.init(url: URL(string: urlString)!)
        self.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.timeoutInterval = subsonicAction.timeout
        self.httpMethod = "GET"
        self.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if byteOffset > 0 {
            self.setValue("bytes=\(byteOffset)-", forHTTPHeaderField: "Range")
        }
        
        // Optional HTTP Basic Auth
        if SavedSettings.si().isBasicAuthEnabled {
            let authString = "\(username):\(encodedParameter(password))"
            let authData = authString.data(using: .ascii)
            let authValue = "Basic \(authData?.base64EncodedString())"
            self.setValue(authValue, forHTTPHeaderField: "Authorization")
        }
        
        print(self)
    }
}
