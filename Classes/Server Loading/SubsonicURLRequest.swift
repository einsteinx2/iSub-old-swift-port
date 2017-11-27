//
//  File.swift
//  iSub
//
//  Created by Benjamin Baron on 1/13/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate let defaultLoadingTimeout = 240.0
fileprivate let serverCheckTimeout = 15.0

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
    case createPlaylist    = "createPlaylist"
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
        case .ping:        return serverCheckTimeout
        default:           return defaultLoadingTimeout
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
    init?(subsonicAction: SubsonicURLAction, serverId: Int64, parameters: [String: Any]? = nil, fragment: String? = nil, byteOffset: Int = 0) {
        var server: Server?
        if serverId == Server.testServerId {
            server = Server.testServer
        } else {
            server = ServerRepository.si.server(serverId: serverId)
        }
        
        if let server = server {
            var baseUrl = server.url
            if serverId == SavedSettings.si.currentServerId, let redirectUrl = SavedSettings.si.redirectUrlString {
                baseUrl = redirectUrl
            }
            
            if server.password == "" {
                log.debug("creating request for serverId: \(server.serverId) password is empty")
            }
            
            self.init(subsonicAction: subsonicAction,
                      baseUrl: baseUrl,
                      username: server.username,
                      password: server.password ?? "",
                      parameters: parameters,
                      fragment: fragment,
                      byteOffset: byteOffset,
                      basicAuth: server.basicAuth)
        } else {
             return nil
        }
    }
    
    init(subsonicAction: SubsonicURLAction, baseUrl: String, username: String, password: String, parameters: [String: Any]? = nil, fragment: String? = nil, byteOffset: Int = 0, basicAuth: Bool = false) {
        
        var urlString = "\(baseUrl)/rest/\(subsonicAction.rawValue).\(subsonicAction.urlExtension)"
        
        // Generate a 32 character random salt
        // Then use the Subsonic required md5(password + salt) function to generate the token.
        let salt = String.random(32)
        let token = (password + salt).md5.lowercased()
        
        // Only support Subsonic version 5.3 and later
        let version = "1.13.0"
        
        // Setup the parameters
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
        
        // Add the fragment
        if let fragment = fragment {
            urlString += "#\(fragment)"
        }
        
        self.init(url: URL(string: urlString)!)
        self.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.timeoutInterval = subsonicAction.timeout
        self.httpMethod = "GET"
        self.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if byteOffset > 0 {
            self.setValue("bytes=\(byteOffset)-", forHTTPHeaderField: "Range")
        }
        
        // Optional HTTP Basic Auth
        if basicAuth {
            let authString = "\(username):\(encodedParameter(password))"
            if let authData = authString.data(using: .ascii) {
                let authValue = "Basic \(authData.base64EncodedString())"
                self.setValue(authValue, forHTTPHeaderField: "Authorization")
            }
        }        
    }
}
