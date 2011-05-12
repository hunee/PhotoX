//
//  EAGLView.h
//  OpenGLES_iPhone
//
//  Created by mmalc Crawford on 11/18/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@class EAGLContext;

typedef struct {
	GLuint framebuffer;
	GLuint texture;
	
	GLint width;
	GLint height;
} GLframebuffer;

// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
// The view content is basically an EAGL surface you render your OpenGL scene into.
// Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
@interface EAGLView : UIView {
@private
	// The pixel dimensions of the CAEAGLLayer.
	GLint framebufferWidth;
	GLint framebufferHeight;
    
	// The OpenGL ES names for the framebuffer and renderbuffer used to render to this view.
	GLuint defaultFramebuffer, colorRenderbuffer;

	GLframebuffer _framebuffer[2];
	int _findex;
}

@property (nonatomic, retain) EAGLContext *context;

- (void)setFramebuffer;
- (void)setPhotoFramebuffer;
- (BOOL)presentFramebuffer;

- (void)setPhotoFramebufferIndex:(int)index;
- (UIImage *)screenshotImage:(UIImageOrientation)orientation;

@end
