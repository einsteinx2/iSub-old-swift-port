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

class VisualizerView: UIView {
    fileprivate let context = EAGLContext(api: .openGLES1)
    
    fileprivate var displayLink: CADisplayLink?
    fileprivate let buffer = UnsafeMutablePointer<PixelRGBA>.allocate(capacity: specWidth * specHeight)
    fileprivate let palette = UnsafeMutablePointer<PixelRGBA>.allocate(capacity: specHeight + 128)
    
    // The pixel dimensions of the backbuffer
    fileprivate var backingWidth: GLint = 0
    fileprivate var backingHeight: GLint = 0
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    fileprivate var viewRenderbuffer: GLuint = 0
    fileprivate var viewFramebuffer: GLuint = 0
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    fileprivate var depthRenderbuffer: GLuint = 0
    
    fileprivate var imageTexture: GLuint = 0
    
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
        palette.initialize(to: PixelRGBA())
        
        let scale = Float(UIScreen.main.scale)
        
        // Setup palette
        for i in 1 ..< 128 * Int(scale) {
            //print("i: \(i)")
            palette[i].b = UInt8((Float(specHeight) / 2.0) - ((2.0 / scale) * Float(i)))
            palette[i].g = UInt8((2.0 / scale) * Float(i))
        }
        for i in 1 ..< 128 * Int(scale) {
            let start = 128 * Int(scale) - 1
            //print("start+i: \(start+i)")
            palette[start+i].g = UInt8((Float(specHeight) / 2.0) - ((2.0 / scale) * Float(i)))
            palette[start+i].r = UInt8((2.0 / scale) * Float(i))
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
        
        palette.deinitialize()
        palette.deallocate(capacity: specHeight + 128)
        
        buffer.deinitialize()
        buffer.deallocate(capacity: specWidth * specHeight)
        
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
    
    @objc fileprivate func render() {
        guard let context = context else {
            return
        }
        
        BassGaplessPlayer.si.visualizer.readAudioData()
        
        eraseBuffer()
        
        var y = 0
        for x in 0..<specWidth {
            let lineSpecData = Int(BassGaplessPlayer.si.visualizer.lineSpecData(index: x))
            let v = (32767 - lineSpecData) * specHeight / 65536 // invert and scale to fit display
            if x == 0 {
                y = v
            }
            
            repeat {
                // draw line from previous sample...
                if y < v {
                    y += 1
                } else if y > v {
                    y -= 1
                }
                //buffer[y * specWidth + x] = palette[Int(abs(Float(y) - Float(specHeight) / 2.0) * 2.0 + 1.0)]
                let bufferIndex = y * specWidth + x
                let paletteIndex = abs(y - specHeight / 2) * 2 + 1
                buffer[bufferIndex] = palette[paletteIndex]
            } while y != v
        }
        
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
        buffer.initialize(to: PixelRGBA(), count: specWidth * specHeight)
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
    }
}

