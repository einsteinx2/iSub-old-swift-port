//
//  BassVisualizer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/21/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum LineVisualizerType: Int {
    case none       = 0
    case line       = 1
    case skinnyBar  = 2
    case fatBar     = 3
    case aphexFace  = 4
    
    case maxValue   = 5
}

enum VisualizerType: Int {
    case none = 0
    case fft  = 1
    case line = 2
}

class Visualizer {
    fileprivate let fftBuffer = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
    fileprivate let lineBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: 1024)
    
    var channel: HCHANNEL = 0
    var visualizerType: VisualizerType = .line
    
    init() {
    }
    
    init(channel: HCHANNEL) {
        self.channel = channel
    }
    
    deinit {
        fftBuffer.deinitialize()
        fftBuffer.deallocate(capacity: 1024)
        
        lineBuffer.deinitialize()
        lineBuffer.deallocate(capacity: 1024)
    }
    
    func fftData(index: Int) -> Float {
        return fftBuffer[index]
    }
    
    func lineSpecData(index: Int) -> Int16 {
        return lineBuffer[index]
    }
    
    func readAudioData() {
        // Get the FFT data for visualizer
        if visualizerType == .fft {
            BASS_ChannelGetData(channel, fftBuffer, BASS_DATA_FFT2048);
        }
        
        // Get the data for line spec visualizer
        if visualizerType == .line {
            BASS_ChannelGetData(channel, lineBuffer, 1024);
        }
    }
}
