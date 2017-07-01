//
//  BassVisualizer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/21/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum VisualizerType: Int {
    case line       = 0
    case skinnyBar  = 1
    case fatBar     = 2
    case aphexFace  = 3
    
    var dataType: VisualizerDataType {
        switch self {
        case .line: return .line
        case .skinnyBar: return .fft
        case .fatBar: return .fft
        case .aphexFace: return .fft
        }
    }
    
    var next: VisualizerType {
        if self == .aphexFace {
            return .line
        } else {
            return VisualizerType(rawValue: self.rawValue + 1)!
        }
    }
    
    var previous: VisualizerType {
        if self == .line {
            return .aphexFace
        } else {
            return VisualizerType(rawValue: self.rawValue - 1)!
        }
    }
}

enum VisualizerDataType: Int {
    case none = 0
    case fft  = 1
    case line = 2
}

class Visualizer {
    fileprivate let fftBuffer = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
    fileprivate let lineBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: 1024)
    
    var channel: HCHANNEL = 0
    
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
    
    func readAudioData(visualizerType: VisualizerType) {
        let dataType = visualizerType.dataType
        
        // Get the FFT data for visualizer
        if dataType == .fft {
            BASS_ChannelGetData(channel, fftBuffer, BASS_DATA_FFT2048);
        }
        
        // Get the data for line spec visualizer
        if dataType == .line {
            BASS_ChannelGetData(channel, lineBuffer, 1024);
        }
    }
}
