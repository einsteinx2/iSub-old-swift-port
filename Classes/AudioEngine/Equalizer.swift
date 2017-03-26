//
//  BassEqualizer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum EqualizerFrequency: Int {
    case hertz32  = 0
    case hertz64  = 1
    case hertz128 = 2
    case hertz256 = 3
    case hertz512 = 4
    case hertz1k  = 5
    case hertz2k  = 6
    case hertz4k  = 7
    case hertz8k  = 8
    case hertz16k = 9
    
    static let all: [EqualizerFrequency] = [.hertz32, .hertz64, .hertz128, .hertz256, .hertz512,
                                            .hertz1k, .hertz2k, .hertz4k, .hertz8k, .hertz16k]
    
    static let frequencies: [Float] = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]
    var centerFrequency: Float {
        return EqualizerFrequency.frequencies[self.rawValue]
    }
    
    var defaultBassParameters: BASS_DX8_PARAMEQ {
        var params = BASS_DX8_PARAMEQ()
        params.fCenter    = centerFrequency // Center frequency, in hertz
        params.fBandwidth = 18              // Bandwidth, in semitones, in the range from 1 to 36. The default value is 12
        params.fGain      = 0               // Gain, in the range from -15 to 15. The default value is 0 dB.
        return params
    }
    
    var label: String {
        switch self {
        case .hertz32:  return "32"
        case .hertz64:  return "64"
        case .hertz128: return "128"
        case .hertz256: return "256"
        case .hertz512: return "512"
        case .hertz1k:  return "1k"
        case .hertz2k:  return "2k"
        case .hertz4k:  return "4k"
        case .hertz8k:  return "8k"
        case .hertz16k: return "16k"
        }
    }
    
    func bassParameters(gain: Float) -> BASS_DX8_PARAMEQ {
        var bassParameters = defaultBassParameters
        bassParameters.fGain = gain
        return bassParameters
    }
}

class EqualizerValue {
    let frequency: EqualizerFrequency
    var gain: Float
    
    var channel: HCHANNEL?
    var handle: HFX?
    
    var bassParameters: BASS_DX8_PARAMEQ {
        return frequency.bassParameters(gain: gain)
    }
    
    init(frequency: EqualizerFrequency, gain: Float = 0, channel: HCHANNEL? = nil, handle: HFX? = nil) {
        self.frequency = frequency
        self.gain = gain
        self.channel = channel
        self.handle = handle
    }
    
    func enable() {
        if handle == nil, let channel = channel {
            handle = BASS_ChannelSetFX(channel, UInt32(BASS_FX_DX8_PARAMEQ), 0)
            var params = bassParameters
            BASS_FXSetParameters(handle!, &params);
        }
    }
    
    func update() {
        if let handle = handle {
            var params = bassParameters
            BASS_FXSetParameters(handle, &params);
        }
    }
    
    func disable() {
        if let channel = channel, let handle = handle {
            BASS_ChannelRemoveFX(channel, handle)
            self.handle = nil
        }
    }
}

class EqualizerPreset {
    static let flat = EqualizerPreset(name: "flat", values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])!
    static let presets = [flat]
    
    var name = ""
    fileprivate(set) var values: [Float] = [0, 0, 0, 0, 0,
                                            0, 0, 0, 0, 0]
    
    init?(name: String, values: [Float]) {
        guard values.count == 10 else {
            return nil
        }
        
        self.name = name
        self.values = values
    }
    
    func value(forFrequency frequency: EqualizerFrequency) -> Float {
        return values[frequency.rawValue]
    }
    
    func update(value: Float, forFrequency frequency: EqualizerFrequency) {
        values[frequency.rawValue] = value
    }
    
    static func ==(lhs: EqualizerPreset, rhs: EqualizerPreset) -> Bool {
        return lhs.values == rhs.values
    }
    
    static func !=(lhs: EqualizerPreset, rhs: EqualizerPreset) -> Bool {
        return lhs.values != rhs.values
    }
}

class Equalizer {
    fileprivate(set) var isActive = false
    fileprivate(set) var values = [EqualizerValue]()
    fileprivate var preampHandle: HFX?
    
    var preampGain: Float = 1.0 {
        didSet {
            if preampGain != oldValue {
                updatePreampGain(gain: preampGain)
            }
        }
    }
    
    var preset: EqualizerPreset = .flat {
        didSet {
            if preset != oldValue {
                let wasActive = isActive
                removeValues()
                createValues()
                if wasActive {
                    enable()
                }
            }
        }
    }
    
    var channel: HCHANNEL? {
        didSet {
            if channel != oldValue {
                createValues()
                
                for value in values {
                    value.channel = channel
                }
                
                if isActive {
                    enable()
                }
            }
        }
    }
    
    init() {
    }
    
    init(channel: HCHANNEL) {
        self.channel = channel
    }
    
    func removeValues() {
        disable()
        values = [EqualizerValue]()
    }
    
    func createValues() {
        removeValues()
        
        for frequency in EqualizerFrequency.all {
            let gain = preset.values[frequency.rawValue]
            let value = EqualizerValue(frequency: frequency, gain: gain, channel: channel)
            values.append(value)
        }
    }
    
    func enable() {
        if !isActive, let channel = channel {
            preampHandle = BASS_ChannelSetFX(channel, UInt32(BASS_FX_BFX_VOLUME), 1)
            updatePreampGain(gain: preampGain)
            
            for value in values {
                value.enable()
            }
            isActive = true
        }
    }
    
    func disable() {
        if isActive, let channel = channel, let preampHandle = preampHandle {
            BASS_ChannelRemoveFX(channel, preampHandle)
            
            for value in values {
                value.disable()
            }
            isActive = false
        }
    }
    
    func updatePreampGain(gain: Float) {
        if let channel = channel {
            var preampParams = BASS_BFX_VOLUME()
            preampParams.lChannel = Int32(bitPattern: channel)
            preampParams.fVolume = gain // 0.0 = -unlimited dB, 0.5 = -6dB, 1.0 = 0dB, 2.0 = +6dB, etc
            BASS_FXSetParameters(preampHandle!, &preampParams)
        }
    }
    
    func updateValue(index: Int, gain: Float) {
        if values.count > index {
            let value = values[index]
            value.gain = gain
            value.update()
        }
    }
    
    func updateValue(frequency: EqualizerFrequency, gain: Float) {
        let index = frequency.rawValue
        updateValue(index: index, gain: gain)
    }
}
