//
//  HLSPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//
// Loosely based on the example code here: https://github.com/kencool/KSHLSPlayer
//

import Foundation

final class HLSPlaylist {
    struct Schema {
        static let header         = "#EXTM3U"
        static let playlistType   = "#EXT-X-PLAYLIST-TYPE"
        static let targetDuration = "#EXT-X-TARGETDURATION"
        static let version        = "#EXT-X-VERSION"
        static let mediaSequence  = "#EXT-X-MEDIA-SEQUENCE"
        static let discontinuity  = "#EXT-X-DISCONTINUITY"
        static let streamInf      = "#EXT-X-STREAM-INF"
        static let inf            = "#EXTINF"
        static let endList        = "#EXT-X-ENDLIST"
        
        // EXT-X-STREAM-INF properties
        static let programId        = "PROGRAM-ID"
        static let bandwidth        = "BANDWIDTH"
        static let averageBandwidth = "AVERAGE-BANDWIDTH"
        static let resolution       = "RESOLUTION"
        static let codecs           = "CODECS"
    }
    
    enum StreamType: String {
        case live  = "LIVE"
        case event = "EVENT"
        case vod   = "VOD"
    }
    
    // Unique identifier to create segment and playlist URLs
    let uuid = UUID()
    
    // Input URL
    var url: URL
    
    // Schema
    var type: StreamType?
    var targetDuration: Int?
    var version: Int?
    var mediaSequence: Int?
    var hasEnd = false
    
    // Optional EXT-X-STREAM-INF properties
    var programId: Int?
    var bandwidth: Int?
    var averageBandwidth: Int?
    var resolution: String?
    var codecs: String?
    
    var playlists = [HLSPlaylist]()
    var segments = [HLSSegment]()
    var segmentNames = [String: HLSSegment]()
    
    init(url: URL) {
        self.url = url
    }
    
    init(url: URL, data: Data) {
        self.url = url
        if let text = String(data: data, encoding: .utf8) {
            parseText(text)
        }
    }
    
    fileprivate func parseText(_ text: String) {
        var segCount = 0
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            // Target Duration
            if line.hasPrefix(Schema.targetDuration) {
                let value = line.substring(from: Schema.targetDuration.length + 1)
                targetDuration = Int(value)
            }
            
            // Version
            else if line.hasPrefix(Schema.version) {
                version = Int(line.substring(from: Schema.version.length + 1))
            }
            
            // Media Sequence
            else if line.hasPrefix(Schema.mediaSequence) {
                let value = line.substring(from: Schema.mediaSequence.length + 1)
                mediaSequence = Int(value)
            }
                
            // Playlists
            else if line.hasPrefix(Schema.streamInf) {
                if let url = processUrlString(lines[i + 1]) {
                    let playlist = HLSPlaylist(url: url)
                    let value = line.substring(from: Schema.streamInf.length + 1)
                    let components = value.components(separatedBy: CharacterSet(charactersIn: ","))
                    for pair in components {
                        let split = pair.components(separatedBy: CharacterSet(charactersIn: "="))
                        if split.count == 2 {
                            switch split[0] {
                            case Schema.programId:        playlist.programId = Int(split[1])
                            case Schema.bandwidth:        playlist.bandwidth = Int(split[1])
                            case Schema.averageBandwidth: playlist.averageBandwidth = Int(split[1])
                            case Schema.resolution:       playlist.resolution = split[1]
                            case Schema.codecs:           playlist.codecs = split[1]
                            default: break
                            }
                        }
                    }
                    playlists.append(playlist)
                }
            }
            
            // Segments
            else if line.hasPrefix(Schema.inf) {
                // Find the duration
                let sequence = (mediaSequence ?? 0) + segments.count
                var value = line.substring(from: Schema.inf.length + 1)
                
                // Remove optional title data from duration
                if let commaIndex = value.index(of: Character(",")) {
                    value = value.substring(to: commaIndex.encodedOffset)
                }
                
                // Create and store the segment
                if let url = processUrlString(lines[i + 1]) {
                    let fileName = "segment\(segCount).ts"
                    let duration = Double(value) ?? 10.0
                    let ts = HLSSegment(url: url, fileName: fileName, duration: duration, sequence: sequence)
                    segments.append(ts)
                    segmentNames[ts.fileName] = ts
                    segCount += 1
                }
            }
            
            // End List
            else if line.hasPrefix(Schema.endList) {
                hasEnd = true
            }
        }
    }
    
    fileprivate func processUrlString(_ urlString: String) -> URL? {
        if let scheme = url.scheme, let host = url.host, urlString.hasPrefix("/") {
            var finalUrlString = scheme + "://" + host
            if let port = url.port {
                finalUrlString += ":\(port)"
            }
            
            finalUrlString += urlString
            return URL(string: finalUrlString)
        }
        return URL(string: urlString)
    }
    
    func generate(_ baseUrl: String?, overrideType: StreamType? = nil, overrideTargetDuration: Int? = nil, overrideVersion: Int? = nil, overrideMediaSequence: Int? = nil) -> String {
        // Header
        var string = Schema.header + "\n"
        if let type = (overrideType ?? type) {
            string += Schema.playlistType + ":\(type.rawValue)\n"
        }
        if let targetDuration = (overrideTargetDuration ?? targetDuration) {
            string += Schema.targetDuration + ":\(targetDuration)\n"
        }
        if let version = (overrideVersion ?? version) {
            string += Schema.version + ":\(version)\n"
        }
        if let mediaSequence = (overrideMediaSequence ?? mediaSequence) {
           string += Schema.mediaSequence + ":\(mediaSequence)\n"
        }
        
        // Playlists
        for playlist in playlists {
            var properties = ""
            if let programId = playlist.programId {
                properties += ",\(Schema.programId)=\(programId)"
            }
            if let bandwidth = playlist.bandwidth {
                properties += ",\(Schema.bandwidth)=\(bandwidth)"
            }
            if let averageBandwidth = playlist.averageBandwidth {
                properties += ",\(Schema.averageBandwidth)=\(averageBandwidth)"
            }
            if let resolution = playlist.resolution {
                properties += ",\(Schema.resolution)=\(resolution)"
            }
            if let codecs = playlist.codecs {
                properties += ",\(Schema.codecs)=\(codecs)"
            }
            if properties.length > 0 {
                // Remove the leading comma
                properties = properties.substring(from: 1)
            }
            
            string += "\(Schema.streamInf):\(properties)\n"
            
            // Either use the local URL if provided or the original URL
            if let base = baseUrl {
                string += "\(base)/playlist/\(playlist.uuid.uuidString).m3u8\n"
            } else {
                string += "\(url.absoluteString)\n"
            }
        }
        
        // Segments
        for segment in segments {
            // Floating point durations are only supported in version 3
            let duration: Any = version == 3 ? segment.duration : Int(segment.duration)
            string += Schema.inf + ":\(duration),\n"
            
            // Either use the local URL if provided or the original URL
            if let base = baseUrl {
                string += "\(base)/segment/\(uuid.uuidString)/\(segment.fileName)\n"
            } else {
                string += "\(segment.url)\n"
            }
        }
        
        // End List
        if hasEnd {
            string += Schema.endList
        }
        return string
    }
    
    func playlist(withUuidString uuidString: String) -> HLSPlaylist? {
        // Check if it matches the root playlist
        if uuid.uuidString == uuidString {
            return self
        }
        
        // Check if it matches any sub-playlist
        let index = playlists.index(where: { playlist -> Bool in
            return playlist.uuid.uuidString == uuidString
        })
        if let index = index {
            return playlists[index]
        }
        
        return nil
    }
}
