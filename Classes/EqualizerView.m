//
//  EqualizerPointView.m
//  iSub
//
//  Created by Ben Baron on 11/23/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EqualizerView.h"
#import "BassWrapperSingleton.h"

//CLASS IMPLEMENTATIONS:

// A class extension to declare private methods
@interface EqualizerView (private)

- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;

@end

@implementation EqualizerView

@synthesize  location;
@synthesize  previousLocation;
@synthesize drawTimer;

#define SPECWIDTH 256	// display width
#define SPECHEIGHT 256	// height (changing requires palette adjustments too)
#define DRAWINTERVAL (1./60.)
static CGContextRef specdc;
static DWORD specbuf[SPECWIDTH*SPECHEIGHT];
static DWORD palette[SPECHEIGHT+128];
int specpos = 0;

typedef struct 
{
	BYTE rgbRed, rgbGreen, rgbBlue, Aplha;
} RGBQUAD;

typedef enum
{
	ISMSBassVisualType_line,
	ISMSBassVisualType_skinnyBar,
	ISMSBassVisualType_fatBar,
	ISMSBassVisualType_aphexFace
} ISMSBassVisualType;

ISMSBassVisualType visualType = ISMSBassVisualType_skinnyBar;

static void SetupDrawEQPalette()
{
	// setup palette
	RGBQUAD *pal = (RGBQUAD *)palette;
	int a;
	memset(palette, 0, sizeof(palette));
	/*for (a = 1; a < 65; a++) 
	 {
	 pal[a].rgbRed = 130 - 2 * a;
	 pal[a].rgbBlue = 126 + 2 * a;
	 }
	 for (a = 1; a < 128; a++) 
	 {
	 pal[64+a].rgbBlue = 256 - 2 * a;
	 pal[64+a].rgbGreen   = 2 * a;
	 }
	 for (a = 1; a < 128; a++) 
	 {
	 pal[191+a].rgbGreen = 256 - 2 * a;
	 pal[191+a].rgbRed   = 2 * a;
	 }
	 for (a = 1; a < SPECHEIGHT - 318; a++)
	 {
	 pal[318+a].rgbRed = 255;
	 }*/
	
	for (a = 1; a < 128; a++) 
	{
		pal[a].rgbBlue = 256 - 2 * a;
		pal[a].rgbGreen   = 2 * a;
	}
    for (a = 1; a < 128; a++) 
	{
		pal[127+a].rgbGreen = 256 - 2 * a;
		pal[127+a].rgbRed   = 2 * a;
	}
	
	for (a = 0; a < 32; a++) 
	{
		pal[SPECHEIGHT + a].rgbBlue       = 8 * a;
		pal[SPECHEIGHT + 32 + a].rgbBlue  = 255;
		pal[SPECHEIGHT + 32 + a].rgbRed   = 8 * a;
		pal[SPECHEIGHT + 64 + a].rgbRed   = 255;
		pal[SPECHEIGHT + 64 + a].rgbBlue  = 8 * (31 - a);
		pal[SPECHEIGHT + 64 + a].rgbGreen = 8 * a;
		pal[SPECHEIGHT + 96 + a].rgbRed   = 255;
		pal[SPECHEIGHT + 96 + a].rgbGreen = 255;
		pal[SPECHEIGHT + 96 + a].rgbBlue  = 8 * a;
	}
}

//- (void)createBitmapToDraw
static void SetupDrawBitmap()
{
	// create the bitmap
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	specdc = CGBitmapContextCreate(specbuf, SPECWIDTH, SPECHEIGHT, 8, SPECWIDTH * 4, colorSpace, kCGImageAlphaNoneSkipLast);
	CGColorSpaceRelease(colorSpace);
}

__attribute__((constructor))
static void initialize_drawPalette() 
{
	SetupDrawEQPalette();
	SetupDrawBitmap();
}

__attribute__((destructor))
static void destroy_versionArrays() 
{
	CGContextRelease(specdc);
	free(palette);
	free(specbuf);
}

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder 
{
    if ((self = [super initWithCoder:coder]))
	{
		drawTimer = nil;
		
		//[self createBitmapToDraw];
		
		//[self setupPalette];
		
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		// In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		if (!context || ![EAGLContext setCurrentContext:context]) {
			[self release];
			return nil;
		}
		
		// Use OpenGL ES to generate a name for the texture.
		glGenTextures(1, &imageTexture);
		// Bind the texture name. 
		glBindTexture(GL_TEXTURE_2D, imageTexture);
		// Set the texture parameters to use a minifying filter and a linear filer (weighted average)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		
		//Set up OpenGL states
		glMatrixMode(GL_PROJECTION);
		CGRect frame = self.bounds;
		glOrthof(0, frame.size.width, 0, frame.size.height, -1, 1);
		glViewport(0, 0, frame.size.width, frame.size.height);
		glMatrixMode(GL_MODELVIEW);
		
		glDisable(GL_DITHER);
		glEnable(GL_TEXTURE_2D);
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnable(GL_POINT_SPRITE_OES);
		glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
		glPointSize(self.frame.size.width);
	}
	
	return self;
}

- (void)startEqDisplay
{
	self.drawTimer = [NSTimer scheduledTimerWithTimeInterval:DRAWINTERVAL target:self selector:@selector(drawTheEq) userInfo:nil repeats:YES];
}

- (void)stopEqDisplay
{
	[drawTimer invalidate]; drawTimer = nil;
}

- (void)createBitmapToDraw
{
	// create the bitmap
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	specdc = CGBitmapContextCreate(specbuf, SPECWIDTH, SPECHEIGHT, 8, SPECWIDTH * 4, colorSpace, kCGImageAlphaNoneSkipLast);
	CGColorSpaceRelease(colorSpace);
}

- (void)drawTheEq
{	
	BassWrapperSingleton *wrapper = [BassWrapperSingleton sharedInstance];
	
	switch(visualType)
	{
			int x, y, y1;
			
		case ISMSBassVisualType_line:
		{
			memset(specbuf,0,sizeof(specbuf));
			for (x = 0; x < SPECWIDTH; x++) 
			{
				int v=(32767 - [wrapper lineSpecData:x]) * SPECHEIGHT/65536; // invert and scale to fit display
				if (!x) 
					y = v;
				do 
				{ 
					// draw line from previous sample...
					if (y < v)
						y++;
					else if (y > v)
						y--;
					specbuf[y * SPECWIDTH + x] = palette[abs(y - SPECHEIGHT / 2) * 2 + 1];
				} while (y!=v);
			}
			break;
		}
		case ISMSBassVisualType_skinnyBar:
		{
			memset(specbuf,0,sizeof(specbuf));
			for (x=0;x<SPECWIDTH/2;x++) 
			{
#if 1
				y=sqrt([wrapper fftData:x+1]) * 3 * SPECHEIGHT - 4; // scale it (sqrt to make low values more visible)
#else
				y=[wrapper fftData:x+1] * 10 * SPECHEIGHT; // scale it (linearly)
#endif
				if (y>SPECHEIGHT) y=SPECHEIGHT; // cap it
				if (x && (y1=(y+y1)/2)) // interpolate from previous to make the display smoother
					while (--y1>=0) specbuf[(SPECHEIGHT-1-y1)*SPECWIDTH+x*2-1]=palette[y1+1];
				y1=y;
				while (--y>=0) specbuf[(SPECHEIGHT-1-y)*SPECWIDTH+x*2]=palette[y+1]; // draw level
			}
			break;
		}
		case ISMSBassVisualType_fatBar:
		{
			int b0 = 0;
			memset(specbuf,0,sizeof(specbuf));
#define BANDS 28
			for (x=0; x < BANDS; x++) 
			{
				float peak = 0;
				int b1 = pow(2, x * 10.0 / (BANDS - 1));
				if (b1 > 1023)
					b1 = 1023;
				if (b1 <= b0)
					b1 = b0 + 1; // make sure it uses at least 1 FFT bin
				
				for (; b0 < b1; b0++)
				{
					if (peak < [wrapper fftData:1+b0])
						peak = [wrapper fftData:1+b0];
				}
				
				y = sqrt(peak) * 3 * SPECHEIGHT - 4; // scale it (sqrt to make low values more visible)
				
				if (y > SPECHEIGHT) 
					y = SPECHEIGHT; // cap it
				
				while (--y >= 0)
				{
					for (y1 = 0; y1 < SPECWIDTH / BANDS - 2; y1++)
					{	
						specbuf[(SPECHEIGHT - 1 - y) * SPECWIDTH + x * (SPECWIDTH / BANDS) + y1] = palette[y + 1]; // draw bar
					}
				}
			}
			break;
		}
		case ISMSBassVisualType_aphexFace:
		{
			for (x=0; x < SPECHEIGHT; x++) 
			{
				y = sqrt([wrapper fftData:x+1]) * 3 * 127; // scale it (sqrt to make low values more visible)
				if (y > 127)
					y = 127; // cap it
				specbuf[(SPECHEIGHT - 1 - x) * SPECWIDTH + specpos] = palette[SPECHEIGHT - 1 + y]; // plot it
			}
			// move marker onto next position
			specpos = (specpos + 1) % SPECWIDTH;
			for (x = 0; x < SPECHEIGHT; x++) 
				specbuf[x * SPECWIDTH + specpos] = palette[SPECHEIGHT+126];
			break;
		}
	}
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SPECWIDTH, SPECHEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, specbuf);
	
	[EAGLContext setCurrentContext:context];
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	
	//Allocate vertex array buffer
	static GLfloat *vertexBuffer = NULL;
	if(vertexBuffer == NULL)
		vertexBuffer = malloc(2 * sizeof(GLfloat));
	
	vertexBuffer[0] = self.center.x;
	vertexBuffer[1] = self.center.y;
	
	//Render the vertex array
	glVertexPointer(2, GL_FLOAT, 0, vertexBuffer);
	glDrawArrays(GL_POINTS, 0, 1);
	
	//Display the buffer
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
-(void)layoutSubviews
{
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	
	// Clear the framebuffer the first time it is allocated
	if (needsErase) 
	{
		[self erase];
		needsErase = NO;
	}
}

- (BOOL)createFramebuffer
{
	// Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	glGenRenderbuffersOES(1, &depthRenderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}

// Clean up any buffers we have allocated.
- (void)destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

// Releases resources when they are not longer needed.
- (void) dealloc
{
	[drawTimer invalidate]; drawTimer = nil;
	
	if (imageTexture)
	{
		glDeleteTextures(1, &imageTexture);
		imageTexture = 0;
	}
	
	if([EAGLContext currentContext] == context)
	{
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];
	[super dealloc];
}

// Erases the screen
- (void) erase
{
	[EAGLContext setCurrentContext:context];
	
	//Clear the buffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(1.0, 1.0, 1.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	//Display the buffer
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)changeType
{
	switch (visualType)
	{
		case ISMSBassVisualType_line:
			visualType = ISMSBassVisualType_skinnyBar; break;
		case ISMSBassVisualType_skinnyBar:
			visualType = ISMSBassVisualType_fatBar; break;
		case ISMSBassVisualType_fatBar:
            memset(specbuf, 0, sizeof(specbuf));
            specpos = 0;
			visualType = ISMSBassVisualType_aphexFace; break;
		case ISMSBassVisualType_aphexFace:
			visualType = ISMSBassVisualType_line; break;
	}
}

@end
