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

fileprivate let specWidth: Int = {
    // TODO: Modify based on screen scale
    return 512
}()
fileprivate let specHeight: Int = {
    return specWidth
}()

class VisualizerView: UIView {
    fileprivate let context = EAGLContext(api: .openGLES1)
    fileprivate var displayLink: CADisplayLink?
    fileprivate let buffer: UnsafeMutablePointer<PixelRGBA> = {
        return UnsafeMutablePointer<PixelRGBA>.allocate(capacity: specWidth * specHeight)
    }()
    fileprivate let palette: UnsafeMutablePointer<PixelRGBA> = {
        return UnsafeMutablePointer<PixelRGBA>.allocate(capacity: specHeight + 128)
    }()
    
    fileprivate var specPos = 0
    
    // The pixel dimensions of the backbuffer
    fileprivate var backingWidth: GLint = 0
    fileprivate var backingHeight: GLint = 0
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    fileprivate var viewRenderbuffer: GLuint = 0
    fileprivate var viewFramebuffer: GLuint = 0
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    fileprivate var depthRenderbuffer: GLuint = 0
    
    fileprivate var imageTexture: GLuint = 0
    
    var visualizerType: VisualizerType = .line {
        didSet {
            erase()
        }
    }
    
    override class var layerClass: AnyClass {
        get {
            return CAEAGLLayer.self
        }
    }
    
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
        palette.initialize(repeating: PixelRGBA(), count: specHeight + 128)
        
        // TODO: Use actual screen scale
        let scale = 2
        
        // Setup palette
        for i in 1 ..< 128 * scale {
            //print("i: \(i)")
            palette[i].b = UInt8(256 - ((2.0 / Float(scale)) * Float(i)))
            palette[i].g = UInt8((2.0 / Float(scale)) * Float(i))
        }
        for i in 1 ..< 128 * scale {
            let start = 128 * scale - 1
            //print("start+i: \(start+i)")
            palette[start+i].g = UInt8(256 - ((2.0 / Float(scale)) * Float(i)))
            palette[start+i].r = UInt8((2.0 / Float(scale)) * Float(i))
        }
        
        for i in 0 ..< 32 {
            palette[specHeight + i].b      = 8 * UInt8(i)
            palette[specHeight + 32 + i].b = 255;
            palette[specHeight + 32 + i].r = 8 * UInt8(i)
            palette[specHeight + 64 + i].r = 255
            palette[specHeight + 64 + i].b = 8 * (31 - UInt8(i))
            palette[specHeight + 64 + i].g = 8 * UInt8(i)
            palette[specHeight + 96 + i].r = 255
            palette[specHeight + 96 + i].g = 255
            palette[specHeight + 96 + i].b = 8 * UInt8(i)
            //print("specHeight + 96 + i: \(specHeight + 96 + i)")
        }
        
        if let glLayer = self.layer as? CAEAGLLayer {
            glLayer.isOpaque = true
            glLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking: true,
                                          kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8]
        }
        
        EAGLContext.setCurrent(context)
        
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &imageTexture);
        // Bind the texture name.
        glBindTexture(GLenum(GL_TEXTURE_2D), imageTexture);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST);
        
        //Set up OpenGL states
        glMatrixMode(GLenum(GL_PROJECTION));
        let frame = self.bounds
        glOrthof(0, GLfloat(frame.size.width), 0, GLfloat(frame.size.height), -1, 1);
        glViewport(0, 0, GLsizei(frame.size.width), GLsizei(frame.size.height));
        glMatrixMode(GLenum(GL_MODELVIEW));
        
        glDisable(GLenum(GL_DITHER));
        glEnable(GLenum(GL_TEXTURE_2D));
        glEnableClientState(GLenum(GL_VERTEX_ARRAY));
        glEnable(GLenum(GL_POINT_SPRITE_OES));
        glTexEnvf(GLenum(GL_POINT_SPRITE_OES), GLenum(GL_COORD_REPLACE_OES), GLfloat(GL_TRUE));
        
        //        [self changeType:settingsS.currentVisualizerType];
        //
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startDrawing), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopDrawing), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }
    
    deinit {
        stopDrawing()
        
        palette.deinitialize(count: specHeight + 128)
        palette.deallocate()
        
        buffer.deinitialize(count: specWidth * specHeight)
        buffer.deallocate()
        
        if imageTexture != 0 {
            glDeleteTextures(1, &imageTexture)
        }
        
        if EAGLContext.current() == context {
            EAGLContext.setCurrent(nil)
        }
    }
    
    @objc fileprivate func startDrawing() {
        guard displayLink == nil else {
            return
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(render))
        displayLink!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
    }
    
    // Playing around with averaging samples
    var fftValues: [Float] = [0]//, 0, 0]
    var fftValuesIndex = 0
    var lineValues: [Int] = [0]//, 0, 0]
    var lineValuesIndex = 0
    
    // Playing around with lowering framerate
    var test = 0
    
    @objc fileprivate func render() {
        guard let context = context else {
            return
        }
        
        GaplessPlayer.si.visualizer.readAudioData(visualizerType: visualizerType)
        
        if visualizerType != .aphexFace {
            eraseBuffer()
        }
        
        var y = 0
        var y1 = 0
        if visualizerType == .line {
            for x in 0 ..< specWidth {
                var lineSpecData = Int(GaplessPlayer.si.visualizer.lineSpecData(index: x))
                lineValues[lineValuesIndex] = lineSpecData
                lineValuesIndex += 1
                if lineValuesIndex > lineValues.count - 1 {
                    lineValuesIndex = 0
                }
                lineSpecData = Int(Float(lineValues.reduce(0, +)) / Float(lineValues.count))
                
                // Invert and scale to fit display
                let v = (32767 - lineSpecData) * specHeight / 65536
                if x == 0 {
                    y = v
                }
                
                repeat {
                    // Draw line from previous sample...
                    if y < v {
                        y += 1
                    } else if y > v {
                        y -= 1
                    }
                    let bufferIndex = y * specWidth + x
                    let paletteIndex = abs(y - specHeight / 2) * 2 + 1
                    buffer[bufferIndex] = palette[paletteIndex]
                } while y != v
            }
        } else if visualizerType == .skinnyBar {
            for x in 0 ..< specWidth / 2 {
                var fftData = GaplessPlayer.si.visualizer.fftData(index: x + 1)
                fftValues[fftValuesIndex] = fftData
                fftValuesIndex = fftValuesIndex + 1 > fftValues.count - 1 ? 0 : fftValuesIndex + 1

                fftData = Float(fftValues.reduce(0, +)) / Float(fftValues.count)
                
                // Scale it (sqrt to make low values more visible)
                let fftSqrt = sqrt(fftData)
                y = Int(fftSqrt * 3 * Float(specHeight) - 4)
            
                // Cap it
                y = min(specHeight - 1, y)
                
                // Interpolate from previous to make the display smoother
                y1 = (y + y1) / 2 - 1
                if x > 0 && y1 > 0 {
                    while y1 >= 0 {
                        let bufferIndex = (specHeight - 1 - y1) * specWidth + x * 2 - 1
                        buffer[bufferIndex] = palette[y1 + 1]
                        y1 -= 1
                    }
                }
                
                // Draw level
                y1 = y - 1
                while y >= 0 {
                    let bufferIndex = (specHeight - 1 - y ) * specWidth + x * 2
                    buffer[bufferIndex] = palette[y + 1]
                    y -= 1
                }
            }
        } else if visualizerType == .fatBar {
            let bands = 28
            var b0 = 0
            for x in 0 ..< bands {
                var peak: Float = 0
                var b1 = Int(pow(2, Float(x) * 10 / (Float(bands) - 1)))
                if b1 > 1023 {
                    b1 = 1023
                }
                if b1 <= b0 {
                    // Make sure it uses at least 1 FFT bin
                    b1 = b0 + 1
                }
                
                while b0 < b1 {
                    var fftData = GaplessPlayer.si.visualizer.fftData(index: b0 + 1)
                    fftValues[fftValuesIndex] = fftData
                    fftValuesIndex += 1
                    if fftValuesIndex > fftValues.count - 1 {
                        fftValuesIndex = 0
                    }
                    fftData = Float(fftValues.reduce(0, +)) / Float(fftValues.count)
                    
                    if peak < fftData {
                        peak = fftData
                    }
                    b0 += 1
                }
                
                // Scale it (sqrt to make low values more visible)
                let peakSqrt = sqrt(peak)
                y = Int(peakSqrt * 3 * Float(specHeight) - 4)
                
                // Cap it
                if y > specHeight {
                    y = specHeight - 1
                }
                
                y -= 1
                while y >= 0
                {
                    for i in y1 ..< specWidth / bands - 2
                    {
                        // Draw bar
                        let bufferIndex = (specHeight - 1 - y) * specWidth + x * (specWidth / bands) + i
                        buffer[bufferIndex] = palette[y + 1]
                    }
                    y -= 1
                }
            }
        } else if visualizerType == .aphexFace {
            for x in 0 ..< specHeight {
                let fftData = GaplessPlayer.si.visualizer.fftData(index: x + 1)
                let fftSqrt = sqrt(fftData)
                
                // Scale it (sqrt to make low values more visible)
                y = Int(fftSqrt * 3 * 127)
                
                // Cap it
                if y > 127 {
                    y = 127
                }
                
                // Plot it
                let bufferIndex = (specHeight - 1 - x) * specWidth + specPos
                buffer[bufferIndex] = palette[specHeight - 1 + y]
            }
            
            // Move marker onto next position
            specPos = (specPos + 1) % specWidth;
            for x in 0 ..< specHeight {
                buffer[x * specWidth + specPos] = palette[specHeight + 126]
                
                // TODO: Use real scale
                let scale = 2.0
                if scale == 2.0 && specPos + 1 < specWidth {
                    buffer[x * specWidth + specPos + 1] = palette[specHeight + 126]
                }
            }
        }
        
        if test < 0 {//3 {
            test += 1
            return
        }
        test = 0
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(specWidth), GLsizei(specHeight), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), buffer);
        
        EAGLContext.setCurrent(context)
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer);
        
        let width = GLfloat(self.frame.size.width);
        let height = GLfloat(self.frame.size.height);
        let box: [GLfloat] = [0,     height, 0,
                              width, height, 0,
                              width, 0,      0,
                              0,     0,      0]
        let tex: [GLfloat] = [0,0, 1,0, 1,1, 0,1]
        
        glEnableClientState(GLenum(GL_VERTEX_ARRAY));
        glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY));
        
        glVertexPointer(3, GLenum(GL_FLOAT), 0, box);
        glTexCoordPointer(2, GLenum(GL_FLOAT), 0, tex);
        
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4);
        
        glDisableClientState(GLenum(GL_VERTEX_ARRAY));
        glDisableClientState(GLenum(GL_TEXTURE_COORD_ARRAY));
        
        //Display the buffer
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        context.presentRenderbuffer(Int(GL_RENDERBUFFER_OES))
    }
    
    @objc fileprivate func stopDrawing() {
        displayLink?.isPaused = true
        displayLink?.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        displayLink = nil
    }
    
    // If our view is resized, we'll be asked to layout subviews.
    // This is the perfect opportunity to also update the framebuffer so that it is
    // the same size as our display area.
    override func layoutSubviews() {
        stopDrawing()
        
        guard let context = context else {
            return
        }
        
        EAGLContext.setCurrent(context)
        
        glMatrixMode(GLenum(GL_PROJECTION))
        let frame = self.bounds;
        let scaleFactor = self.contentScaleFactor
        glLoadIdentity()
        glOrthof(0, GLfloat(frame.size.width * scaleFactor), 0, GLfloat(frame.size.height * scaleFactor), -1, 1)
        glViewport(0, 0, GLsizei(frame.size.width * scaleFactor), GLsizei(frame.size.height * scaleFactor))
        glMatrixMode(GLenum(GL_MODELVIEW))
        
        destroyFrameBuffer()
        createFrameBuffer()
        
        startDrawing()
    }
    
    fileprivate func eraseBuffer() {
        buffer.initialize(repeating: PixelRGBA(), count: specWidth * specHeight)
    }
    
    @discardableResult fileprivate func createFrameBuffer() -> Bool {
        guard let context = context, let glLayer = self.layer as? EAGLDrawable else {
            return false
        }
        
        EAGLContext.setCurrent(context)
        // Generate IDs for a framebuffer object and a color renderbuffer
        glGenFramebuffersOES(1, &viewFramebuffer);
        glGenRenderbuffersOES(1, &viewRenderbuffer);
        
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer);
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        
        // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
        // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
        if !context.renderbufferStorage(Int(GL_RENDERBUFFER_OES), from: glLayer) {
            return false
        }
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_COLOR_ATTACHMENT0_OES), GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_WIDTH_OES), &backingWidth);
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_HEIGHT_OES), &backingHeight);
        
        // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer);
        glRenderbufferStorageOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_DEPTH_COMPONENT16_OES), backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_DEPTH_ATTACHMENT_OES), GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer);
        
        if glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)) != GLenum(GL_FRAMEBUFFER_COMPLETE_OES) {
            print("failed to make complete framebuffer object \(glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)))")
            return false
        }
        
        return true
    }
    
    fileprivate func destroyFrameBuffer() {
        guard let context = context else {
            return
        }
        
        EAGLContext.setCurrent(context)
        
        glDeleteFramebuffersOES(1, &viewFramebuffer);
        viewFramebuffer = 0
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0
        
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffersOES(1, &depthRenderbuffer);
            depthRenderbuffer = 0
        }
    }
    
    fileprivate func erase() {
        guard let context = context else {
            return
        }
        
        EAGLContext.setCurrent(context)
        
        //Clear the buffer
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer);
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT));
        
        //Display the buffer
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        context.presentRenderbuffer(Int(GL_RENDERBUFFER_OES))
        
        eraseBuffer()
        for i in 0 ..< fftValues.count {
            fftValues[i] = 0
        }
        for i in 0 ..< lineValues.count {
            lineValues[i] = 0
        }
        specPos = 0
    }
}

