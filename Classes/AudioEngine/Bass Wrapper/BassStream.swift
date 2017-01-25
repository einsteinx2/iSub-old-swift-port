//
//  BassStream.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class BassStream: Equatable {
    weak var player: BassGaplessPlayer?
    
    var stream: HSTREAM = 0
    
    let song: Song
    var isTempCached: Bool { return song.isTempCached }
    var writePath: String { return song.currentPath }
    let fileHandle: FileHandle
    
    var shouldBreakWaitLoop = false
    var shouldBreakWaitLoopForever = false
    var neededSize = Int64.max
    var isWaiting = false
    

    var isSongStarted = false
    var isFileUnderrun = false
    var wasFileJustUnderrun = false
    var channelCount = 0
    var sampleRate = 0
    
    var isEnded = false
    var isEndedCalled = false
    var bufferSpaceTilSongEnd = 0
    
    var isNextSongStreamFailed = false
    
    var localFileSize: Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: writePath)
        return attributes?[.size] as? Int64 ?? 0
    }
    
    init?(song: Song) {
        self.song = song
        if let fileHandle = FileHandle(forReadingAtPath: song.currentPath) {
            self.fileHandle = fileHandle
        } else {
            return nil
        }
    }
    
    deinit {
        fileHandle.closeFile()
    }
    
    static func ==(lhs: BassStream, rhs: BassStream) -> Bool {
        return lhs === rhs
    }
}
