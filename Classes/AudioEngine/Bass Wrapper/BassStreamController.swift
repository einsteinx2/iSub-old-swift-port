//
//  BassStreamController.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/17/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class BassStreamController {
    let deviceNumber: UInt32
    
    var outStream: HSTREAM = 0
    var mixerStream: HSTREAM = 0
    
    let bassStreamsLock = SpinLock()
    var bassStreams = [BassStream]()
    var currentBassStream: BassStream? { return bassStreamsLock.synchronizedResult { return bassStreams.first } }
    var nextBassStream: BassStream? { return bassStreamsLock.synchronizedResult { return bassStreams.second } }
    var bassOutputBufferLengthMillis: UInt32 = 0
    
    init(deviceNumber: UInt32) {
        self.deviceNumber = deviceNumber
    }
    
    func add(bassStream: BassStream) {
        bassStreamsLock.synchronized {
            bassStreams.append(bassStream)
        }
    }
    
    func remove(bassStream: BassStream) {
        // Remove the stream from the queue
        BASS_SetDevice(deviceNumber)
        BASS_StreamFree(bassStream.stream)
        bassStreamsLock.synchronized {
            if let index = bassStreams.index(of: bassStream) {
                _ = bassStreams.remove(at: index)
            }
        }
    }
    
    func cleanup() {
        BASS_SetDevice(deviceNumber)
        bassStreamsLock.synchronized {
            for bassStream in bassStreams {
                bassStream.shouldBreakWaitLoopForever = true
                BASS_Mixer_ChannelRemove(bassStream.stream)
                BASS_StreamFree(bassStream.stream)
            }
            bassStreams.removeAll()
        }
    }
}
