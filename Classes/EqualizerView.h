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

@property(readwrite) CGPoint location;
@property(readwrite) CGPoint previousLocation;

@property (retain) NSTimer *drawTimer;

@property ISMSBassVisualType visualType;


- (void)erase;
- (void)eraseBitBuffer;

- (void)changeType:(ISMSBassVisualType)type;
- (void)changeType;

- (void)startEqDisplay;
- (void)stopEqDisplay;

@end
