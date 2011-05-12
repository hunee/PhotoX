//
//  EAGLView.m
//  OpenGLES_iPhone
//
//  Created by mmalc Crawford on 11/18/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "EAGLView.h"

//#define USE_FB

@interface EAGLView (PrivateMethods)
- (void)createFramebuffer;
- (void)deleteFramebuffer;

@end

@implementation EAGLView

@synthesize context;

// You must implement this method
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

//The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
- (id)initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = TRUE;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
																		[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
																		kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
																		nil];
	}
    
	_findex = 0;
	
	_framebuffer[0].width = 640;
	_framebuffer[0].height = 480;
	
	_framebuffer[1].width = 1280;
	_framebuffer[1].height = 720;
	
	return self;
}

- (void)dealloc
{
	[self deleteFramebuffer];
	[context release];
	
	[super dealloc];
}

- (void)setContext:(EAGLContext *)newContext
{
	if (context != newContext) {
		[self deleteFramebuffer];

		[context release];
		context = [newContext retain];
		
		[EAGLContext setCurrentContext:nil];
	}
}

- (void)createFramebuffer
{
#if defined(DEBUG)	
	NSLog(@"createFramebuffer");
#endif
	
	if (context && !defaultFramebuffer) {
		[EAGLContext setCurrentContext:context];
		
		// Create default framebuffer object.
		glGenFramebuffers(1, &defaultFramebuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
		
		// Create color render buffer and allocate backing store.
		glGenRenderbuffers(1, &colorRenderbuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
		[context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
		
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
		
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
		{
#if defined(DEBUG)	
			NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
#endif
		}
		
		//
		GLint oldFBO;
		glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &oldFBO);
		
		for (int n=0; n<2; ++n)
		{
			GLuint texture;
			GLuint framebuffer;
			
			glGenTextures(1, &texture);
			glBindTexture(GL_TEXTURE_2D, texture);
			
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			
			// This is necessary for non-power-of-two textures
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			
			// Using BGRA extension to pull in video frame data directly
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _framebuffer[n].width, _framebuffer[n].height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
			
			// Create default framebuffer object.
			glGenFramebuffers(1, &framebuffer);
			glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
			
			// attach renderbuffer
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
			
			if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
			{
#if defined(DEBUG)	
				NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
#endif
			}
			_framebuffer[n].texture = texture;
			_framebuffer[n].framebuffer = framebuffer;
		}
		
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, oldFBO);
	}
}

- (void)deleteFramebuffer
{
	if (context) {
		[EAGLContext setCurrentContext:context];
       
		for (int n=0; n<2; ++n)
		{
			if (_framebuffer[n].texture) {
				glDeleteTextures(1, &_framebuffer[n].texture);
				_framebuffer[n].texture = 0;
			}
			
			if (_framebuffer[n].framebuffer) {
				glDeleteFramebuffers(1, &_framebuffer[n].framebuffer);
				_framebuffer[n].framebuffer = 0;
			}
		}
			
		if (defaultFramebuffer) {
			glDeleteFramebuffers(1, &defaultFramebuffer);
			defaultFramebuffer = 0;
		}
			
		if (colorRenderbuffer) {
			glDeleteRenderbuffers(1, &colorRenderbuffer);
			colorRenderbuffer = 0;
		}
	}
}

- (void)setFramebuffer
{
	if (context) {
		[EAGLContext setCurrentContext:context];

	if (!defaultFramebuffer)
		[self createFramebuffer];
        
		glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
		glViewport(0, 0, framebufferWidth, framebufferHeight);
			
#ifdef USE_FB
		glActiveTexture(GL_TEXTURE0);	
		glBindTexture(GL_TEXTURE_2D, _framebuffer[_findex].texture);
#endif
	}
}

- (void)setPhotoFramebuffer
{
	if (context) {
		[EAGLContext setCurrentContext:context];
		
		if (!defaultFramebuffer)
			[self createFramebuffer];

		glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer[_findex].framebuffer);
		
		glViewport(0, 0, _framebuffer[_findex].width, _framebuffer[_findex].height);
	}
}

- (void)setPhotoFramebufferIndex:(int)index
{
	_findex = index;
}

- (BOOL)presentFramebuffer
{
	BOOL success = FALSE;
	
	if (context) {
		[EAGLContext setCurrentContext:context];
		
		glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
		
		success = [context presentRenderbuffer:GL_RENDERBUFFER];
	}
	
	return success;
}

- (void)layoutSubviews
{
	// The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
	[self deleteFramebuffer];
}

void releaseScreenshotData(void *info, const void *data, size_t size) 
{
	free((void *)data);
}

- (UIImage *)screenshotImage:(UIImageOrientation)orientation
{
	[self setPhotoFramebuffer];
	
	NSInteger dataLength = _framebuffer[_findex].width * _framebuffer[_findex].height * 4;
	
	// allocate array and read pixels into it.
	GLuint *buffer = (GLuint *) malloc(dataLength);
	glReadPixels(0, 0, _framebuffer[_findex].width, _framebuffer[_findex].height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
		
	// make data provider with data.
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, dataLength, releaseScreenshotData);
	
	// prep the ingredients
	const int bitsPerComponent = 8;
	const int bitsPerPixel = 4 * bitsPerComponent;
	const int bytesPerRow = 4 * _framebuffer[_findex].width;
	CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
	CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
	
	// make the cgimage
	CGImageRef imageRef = CGImageCreate(_framebuffer[_findex].width, _framebuffer[_findex].height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
	
	CGColorSpaceRelease(colorSpaceRef);
	CGDataProviderRelease(provider);
	
	// then make the UIImage from that
	UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:1.0 orientation:orientation];
	CGImageRelease(imageRef);
	
	return image;
}

@end
