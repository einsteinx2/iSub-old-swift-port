//
//  HLSPlaylist.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/11.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class HLSPlaylist {
    
    struct Schema {
        static let Head = "#EXTM3U"
        static let ListType = "#EXT-X-PLAYLIST-TYPE"
        static let TargetDuration = "#EXT-X-TARGETDURATION"
        static let Version = "#EXT-X-VERSION"
        static let Sequence = "#EXT-X-MEDIA-SEQUENCE"
        static let Discontinuity = "#EXT-X-DISCONTINUITY"
        static let Inf = "#EXTINF"
        static let Endlist = "#EXT-X-ENDLIST"
    }
    
    public enum StreamType: String {
        case LIVE, EVENT, VOD
    }
    
    var type: StreamType?
    
    var version: String?
    
    var targetDuration: Double?
    
    var sequence: Int?
    
    var end: Bool?
    
    private(set) public var segments: [TSSegment] = []
    
    private(set) public var segmentNames: [String] = []
    
    private(set) public var discontinuity: Bool = false
    
    init(version: String?, targetDuration: Double?, sequence: Int?, segments: [TSSegment]) {
        self.version = version
        self.targetDuration = targetDuration
        self.sequence = sequence
        self.segments = segments
        for ts in segments {
            segmentNames.append(ts.filename())
        }
    }
    
    init(data: NSData) {
        if let text = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
            parseText(text)
        }
    }
    
    private func parseText(text: String) {
        segments = []
        segmentNames = []
        version = nil
        targetDuration = nil
        sequence = nil
        end = nil
        let lines = text.componentsSeparatedByString("\n")
        for i in 0..<lines.count {
            let str = lines[i]
            // target duration
            if targetDuration == nil && str.hasPrefix(Schema.TargetDuration) {
                let value = str.substringFromIndex(Schema.TargetDuration.endIndex.successor())
                targetDuration = Double(value)
            }
            // version
            else if version == nil && str.hasPrefix(Schema.Version) {
                version = str.substringFromIndex(Schema.Version.endIndex.successor())
            }
            // sequence
            else if sequence == nil && str.hasPrefix(Schema.Sequence) {
                let value = str.substringFromIndex(Schema.Sequence.endIndex.successor())
                sequence = Int(value)
            }
            // segments
            else if str.hasPrefix(Schema.Inf) {
                let seq = (sequence ?? 0) + segments.count
                let value = str.substringWithRange(Schema.Inf.endIndex.successor()..<str.endIndex.predecessor())
                let ts = TSSegment(url: lines[i + 1], duration: Double(value)!, sequence: seq)
                segments.append(ts)
                segmentNames.append(ts.filename())
            }
            // end list
            else if str.hasPrefix(Schema.Endlist) {
                end = true
            }
        }
    }
    
    func generate(baseUrl: String?) -> String {
        return generate(baseUrl, end: isEnd())
    }
    
    func generate(baseUrl: String?, end: Bool) -> String {
        // head
        var string = Schema.Head + "\n"
        // Type
        if let t = type {
            string += Schema.ListType + ":\(t.rawValue)\n"
        }
        // target duration
        if let t = targetDuration {
            string += Schema.TargetDuration + ":\(t)\n"
        }
        // version
        if let v = version {
            string += Schema.Version + ":\(v)\n"
        }
        // sequence
        if let s = sequence {
            string += Schema.Sequence + ":\(s)\n"
        }
        // segments
        for ts in segments {
            // duration
            string += Schema.Inf + ":\(ts.duration),\n"
            // url
            if let base = baseUrl {
                string += "\(base)/\(ts.filename())\n"
            } else {
                string += "\(ts.url)\n"
            }
        }
        // end list
        if end {
            string += Schema.Endlist
        }
        return string
    }
    
    func isEnd() -> Bool {
        return end ?? false
    }
    
    func addSegment(ts: TSSegment) {
        segments += [ts]
        segmentNames += [ts.filename()]
    }
}