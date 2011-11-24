//
//  EqualizerPointView.h
//  iSub
//
//  Created by Ben Baron on 11/23/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

//CONSTANTS:

#define kBrushOpacity		1.0
#define kBrushPixelStep		3
#define kBrushScale			4
#define kLuminosity			0.75
#define kSaturation			1.0

//CLASS INTERFACES:

@interface EqualizerView : UIView
{
@private
	// The pixel dimensions of the backbuffer
	GLint backingWidth;
	GLint backingHeight;
	
	EAGLContext *context;
	
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
	
	// OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
	GLuint depthRenderbuffer;
	
	GLuint	imageTexture;
	CGPoint	location;
	CGPoint	previousLocation;
	Boolean	firstTouch;
	Boolean needsErase;
}

@property(nonatomic, readwrite) CGPoint location;
@property(nonatomic, readwrite) CGPoint previousLocation;

@property (nonatomic, retain) NSTimer *drawTimer;

- (void)erase;
//- (void)drawImage:(GLubyte *)imageData;

//- (void)setupPalette;
//- (void)createBitmapToDraw;

- (void)changeType;

- (void)startEqDisplay;
- (void)stopEqDisplay;

@end
