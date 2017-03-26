//
//  VisualizerView.swift
//  iSub
//
//  Created by Benjamin Baron on 3/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import GLKit
import OpenGLES
import SnapKit

struct PixelRGBA {
    var r: UInt8 = 0
    var g: UInt8 = 0
    var b: UInt8 = 0
    var a: UInt8 = 0
}

fileprivate let specWidth = 512
fileprivate let specHeight = 512

class VisualizerView: UIView, GLKViewDelegate {
    fileprivate var glView: GLKView?
    fileprivate let buffer = UnsafeMutablePointer<UInt32>.allocate(capacity: specWidth * specHeight)
    fileprivate let palette = UnsafeMutablePointer<PixelRGBA>.allocate(capacity: specHeight + 128)
    
    init() {
        super.init(frame: CGRect.zero)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    fileprivate func commonInit() {
        //memset(palette, 0, (specHeight + 128) * 4)
        memset(palette, 0, specHeight + 128)
        
        let scale = Int(UIScreen.main.scale)
        
        // Setup palette
        for i in 1..<(128 * scale) {
            palette[i].b = UInt8((specHeight / 2) - ((2 / scale) * i))
            palette[i].g = UInt8((2 / scale) * i)
        }
        for i in 1..<(128 * scale) {
            let start = 128 * scale - 1
            palette[start+i].g = UInt8((specHeight / 2) - ((2 / scale) * i))
            palette[start+i].r = UInt8((2 / scale) * i)
        }
        
        for i in 0..<32 {
            palette[specHeight + i].b      = 8 * UInt8(i)
            palette[specHeight + 32 + i].b = 255;
            palette[specHeight + 32 + i].r = 8 * UInt8(i)
            palette[specHeight + 64 + i].r = 255
            palette[specHeight + 64 + i].b = 8 * (31 - UInt8(i))
            palette[specHeight + 64 + i].g = 8 * UInt8(i)
            palette[specHeight + 96 + i].r = 255
            palette[specHeight + 96 + i].g = 255
            palette[specHeight + 96 + i].b = 8 * UInt8(i)
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.glView?.removeFromSuperview()
        
        let glView = GLKView(frame: self.bounds)
        glView.context = EAGLContext(api: .openGLES2)
        glView.delegate = self
        self.addSubview(glView)
        self.glView = glView
    }
    
    fileprivate func eraseBuffer() {
        //memset(buffer, 0, (specWidth * specHeight * 4))
        memset(buffer, 0, specWidth * specHeight)
    }
    
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        guard BassGaplessPlayer.si.isPlaying else {
            return
        }
        
        /*
        BassGaplessPlayer.si.visualizer.readAudioData()
        
        eraseBuffer()
        var y = 0
        for x = 0..<specWidth {
            let v = 32767 - BassGaplessPlayer.si.visualizer.lineSpecData(index: x) * specHeight / 65536 // invert and scale to fit display
            if x == 0 {
                y = v;
            }
            
            
            int v=(32767 - [audioEngineS.visualizer lineSpecData:x]) * specHeight/65536; // invert and scale to fit display
            if (!x)
            y = v;
            do
            {
            // draw line from previous sample...
            if (y < v)
            y++;
            else if (y > v)
            y--;
            specbuf[y * specWidth + x] = palette[abs(y - specHeight / 2) * 2 + 1];
            } while (y!=v);
        }

        glClearColor(1.0, 0.0, 0.0, 1.0)
        glClear(0x00004000)
         */
    }
}

