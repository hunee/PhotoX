//
//  Photo_BoothViewController.m
//  Photo Booth
//
//  Created by Jang Jeonghun on 4/20/11.
//  Copyright 2011 home. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "PhotoXViewController.h"
#import "EAGLView.h"

#import "AVCaptureManager.h"

#include <mach/mach_time.h>

//#define USE_FB

// Uniform index.
enum {
	UNIFORM_TEXTURE0,
	UNIFORM_TEXTURE1,
	UNIFORM_TEXTURE2,
	UNIFORM_TEXTURE3,
	
	// GAMMA	
	UNIFORM_GAMMA,
	UNIFORM_NUMCOLORS,
	
	UNIFORM_TIME,
	UNIFORM_WIDTH,
	UNIFORM_HEIGHT,
	
	UNIFORM_CENTER,
	UNIFORM_SHOCK_PARAMS,

	UNIFORM_MIRROR,

	UNIFORM_PARAM1,
	UNIFORM_PARAM2,
	
	NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
	ATTRIB_POSITION,
	ATTRIB_TEXCOORD0,
	NUM_ATTRIBUTES
};

// Touches index.
enum {
	TOUCHES_BEGIN,
	TOUCHES_MOVED,
	TOUCHES_END,
	NUM_TOUCHES
};

static inline uint64_t timer_now()
{
	return(mach_absolute_time());
}

static inline double timer_elapsed(uint64_t start, uint64_t end)
{
	mach_timebase_info_data_t info;
	mach_timebase_info(&info);
	return((double)(end - start) * info.numer / (info.denom * 1000000000.));
}

#ifndef SAFE_FREE
#define SAFE_FREE(p)			{ if (p) { free(p);     (p) = NULL; } }		// free
#endif //SAFE_FREE

static void *AVCaptureFocusModeObserverContext = &AVCaptureFocusModeObserverContext;

@interface PhotoXViewController () <UIGestureRecognizerDelegate>
@end

@interface PhotoXViewController (InternalMethods)
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer;
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer;
- (void)moveToLeftOrRight:(UISwipeGestureRecognizer *)gestureRecognizer;

- (void)updateButtonStates;
@end

@interface PhotoXViewController (AVCaptureManagerDelegate) <AVCaptureManagerDelegate>
@end

@interface PhotoXViewController ()
@property (nonatomic, retain) EAGLContext *_context;
@property (nonatomic, assign) CADisplayLink *displayLink;

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

- (GLuint)loadShader:(NSString *)vertexShaderName fragment:(NSString *)fragmentShaderName;

- (BOOL)loadShaders;

- (void)drawFrame_;
- (void)photoFrame;
@end

@implementation PhotoXViewController

@synthesize animating, displayLink;

@synthesize _context;

@synthesize captureManager;
@synthesize cameraToggleButton;
@synthesize stillButton;
@synthesize effectButton;
@synthesize photoButton;

@synthesize leftButton;
@synthesize rightButton;

@synthesize iad;
@synthesize page;

@synthesize param1Slider;
@synthesize param2Slider;
@synthesize fps;

@synthesize activityIndicatorView;

@synthesize player;

@synthesize imageURL, imageAsset, image;

- (void)awakeFromNib
{
#if defined(DEBUG)	
 	NSLog(@"awakeFromNib");
#endif
	
	EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	
	if (!aContext) {
		aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	}
	
#if defined(DEBUG)	
	if (!aContext)
		NSLog(@"Failed to create ES context");
	else if (![EAGLContext setCurrentContext:aContext])
		NSLog(@"Failed to set ES context current");
#endif
	
	self._context = aContext;
	[aContext release];
	
	[(EAGLView *)self.view setContext:_context];
	[(EAGLView *)self.view setFramebuffer];
  
	//
	for (int n=0; n<MAX_SHADERS; ++n)
		_program[n] = 0;
	
	for (int n=0; n<MAX_VIEW; ++n)
		_pindex[n] = 0;
	
	_grid = 0;
	_gcount = 1;
	
  if ([_context API] == kEAGLRenderingAPIOpenGLES2)
    [self loadShaders];
	
	//
	glGenTextures(1, &_texture);
	
	_cindex = 0;
	_sindex = 0;
	_pindex[0] = 1;
	
	_center.x = _center.y = 0.5;
	
	// Load the the sample file, use mono or stero sample
	NSURL *fileURL = [[NSURL alloc] initFileURLWithPath: [[NSBundle mainBundle] pathForResource:@"Camera" ofType:@"wav"]];
	
	self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];	
	
	player.numberOfLoops = 0;
	player.delegate = self;
	
	OSStatus result = AudioSessionInitialize(NULL, NULL, NULL, NULL);
	if (result)
	{
#if defined(DEBUG)	
		NSLog(@"Error initializing audio session! %ld", result);
#endif
	}
	
	[[AVAudioSession sharedInstance] setDelegate: self];

	NSError *setCategoryError = nil;
	[[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:&setCategoryError];
	if (setCategoryError)
	{
#if defined(DEBUG)	
		NSLog(@"Error setting category! %@", setCategoryError);
#endif
	}
	
	[fileURL release];
	
#if defined(DEBUG)
	fps.hidden = FALSE;
#else
	fps.hidden = TRUE;
#endif
	
	activityIndicatorView.hidden = TRUE;
	
	animating = FALSE;
	animationFrameInterval = 1;
	self.displayLink = nil;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"captureManager.videoInput.device.focusMode"];
	[captureManager release];
	[cameraToggleButton release];
	[stillButton release];	
	
	[player release];
	
	glDeleteTextures(1, &_texture);
	
	///	
	for (int n=0; n<MAX_SHADERS; ++n)
	{
		if (_program[n])
		{
			glDeleteProgram(_program[n]);
			_program[n] = 0;
		}
	}
	
	// Tear down context.
	if ([EAGLContext currentContext] == _context)
		[EAGLContext setCurrentContext:nil];
	
	[_context release];
	[super dealloc];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

/*- (void)viewWillAppear:(BOOL)animated
{
    [self startAnimation];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];
    
    [super viewWillDisappear:animated];
}*/

- (void)viewDidLoad
{
#if defined(DEBUG)	
	NSLog(@"viewDidLoad");
#endif
	
	//	[[self cameraToggleButton] setTitle:NSLocalizedString(@"Camera", @"Toggle camera button title")];
	//	[[self stillButton] setTitle:NSLocalizedString(@"Photo", @"Capture still image button title")];
	
	if ([self captureManager] == nil) {
		AVCaptureManager *manager = [[AVCaptureManager alloc] init];
		[self setCaptureManager:manager];
		[manager release];
		
		[[self captureManager] setDelegate:self];
		
		if ([[self captureManager] setupSession]) {
			// Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[[[self captureManager] session] startRunning];
			});
			
			[self updateButtonStates];
			
			//			CGRect bounds = [(EAGLView *)self.view bounds]; 
			
			// Add a single tap gesture to focus on the point tapped, then lock focus
			UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToAutoFocus:)];
			[singleTap setDelegate:self];
			[singleTap setNumberOfTapsRequired:1];
			[self.view addGestureRecognizer:singleTap];
			
			// Add a double tap gesture to reset the focus mode to continuous auto focus
			UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToContinouslyAutoFocus:)];
			[doubleTap setDelegate:self];
			[doubleTap setNumberOfTapsRequired:2];
			[singleTap requireGestureRecognizerToFail:doubleTap];
			[self.view addGestureRecognizer:doubleTap];
			
			UISwipeGestureRecognizer *recognizerLeft = [[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(moveToLeftOrRight:)] autorelease];
			recognizerLeft.numberOfTouchesRequired = 1;
			recognizerLeft.direction = UISwipeGestureRecognizerDirectionLeft;
			[self.view addGestureRecognizer:recognizerLeft];
			
			UISwipeGestureRecognizer *recognizerRight = [[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(moveToLeftOrRight:)] autorelease];
			recognizerRight.numberOfTouchesRequired = 1;
			recognizerRight.direction = UISwipeGestureRecognizerDirectionRight;
			[self.view addGestureRecognizer:recognizerRight];			
			
			[doubleTap release];
			[singleTap release];
		}
	}
	
	_start = _end = timer_now();

	iad.frame = CGRectOffset(iad.frame, 0, 50);
	iad.requiredContentSizeIdentifiers = [NSSet setWithObject:ADBannerContentSizeIdentifier320x50];
	iad.currentContentSizeIdentifier = ADBannerContentSizeIdentifier320x50;
	iad.delegate = self;
	
	_bvisible = NO;
	_bindex = 0;
	
	iad.hidden = TRUE;
	
	page.numberOfPages = 2;
	page.hidden = TRUE;
	
	leftButton.hidden = TRUE;
	rightButton.hidden = TRUE;
	
	[super viewDidLoad];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	
	// Tear down context.
	if ([EAGLContext currentContext] == _context)
		[EAGLContext setCurrentContext:nil];
	
	self._context = nil;	
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	if (!_bvisible) {
		[UIView beginAnimations:@"animateAdBannerOn" context:NULL];
		iad.frame = CGRectOffset(iad.frame, 0, -50);
		[UIView commitAnimations];
		
		_bvisible = YES;
		
		if (_grid)
		{
			_bindex = 1;
		}
		else
		{
			_bindex = 0;
		}

		page.frame = CGRectOffset(page.frame, 0, -50); 
	}
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
	if (_bvisible) {
		[UIView beginAnimations:@"animateAdBannerOff" context:NULL];
		iad.frame = CGRectOffset(iad.frame, 0, 50);
		[UIView commitAnimations];

		_bvisible = NO;
		_bindex = 0;
		
		page.frame = CGRectOffset(page.frame, 0, 50); 
	}
}

- (NSInteger)animationFrameInterval
{
    return animationFrameInterval;
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
    /*
	 Frame interval defines how many display frames must pass between each time the display link fires.
	 The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. The default frame interval setting of one will fire 60 times a second when the display refreshes at 60 times a second. A frame interval setting of less than one results in undefined behavior.
	 */
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;
        
        if (animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

- (void)startAnimation
{
 if (!animating) {
	 CADisplayLink *aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(drawFrame)];
	 [aDisplayLink setFrameInterval:animationFrameInterval];
	 [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	 self.displayLink = aDisplayLink;
 
	 animating = TRUE;
 }
}

- (void)stopAnimation
{
 if (animating) {
	 [self.displayLink invalidate];
	 self.displayLink = nil;
	 animating = FALSE;
 }
}

#pragma mark Toolbar Actions
- (IBAction)toggleCamera:(id)sender
{
//	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
	
	// Toggle between cameras when there is more than one
	[[self captureManager] toggleCamera];
	
	// Do an initial focus
	[[self captureManager] continuousFocusAtPoint:CGPointMake(.5f, .5f)];
	
	_cindex = !_cindex;
	
	[(EAGLView *)self.view setPhotoFramebufferIndex:_cindex];
}

#pragma mark delegate methods
- (void) imagePickerController:(UIImagePickerController *)picker
 didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	// Don't pay any attention if somehow someone picked something besides an image.
	if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString *)kUTTypeImage]){
		// Hand on to the asset URL for the picked photo..
		self.imageURL = [info objectForKey:UIImagePickerControllerReferenceURL];
			
		// To get an asset library reference we need an instance of the asset library.
		ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];

		// The assetForURL: method of the assets library needs a block for success and
		// one for failure. The resultsBlock is used for the success case.
		ALAssetsLibraryAssetForURLResultBlock resultsBlock = ^(ALAsset *asset) {
			self.imageAsset = asset;
			ALAssetRepresentation *representation = [asset defaultRepresentation];
			CGImageRef imageRef = [representation fullScreenImage];
		
			// Make sure that the UIImage we create from the CG image has the appropriate
			// orientation, based on the EXIF data from the image.
			ALAssetOrientation orientation = [representation orientation];
			image = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:(UIImageOrientation)orientation];
		};
		ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error){
			/*  A failure here typically indicates that the user has not allowed this app access
			 to location data. In that case the error code is ALAssetsLibraryAccessUserDeniedError.
			 In principle you could alert the user to that effect, i.e. they have to allow this app
			 access to location services in Settings > General > Location Services and turn on access
			 for this application.
			 */
			NSLog(@"FAILED! due to error in domain %@ with error code %d", error.domain, error.code);
			// This sample will abort since a shipping product MUST do something besides logging a
			// message. A real app needs to inform the user appropriately.
			abort();
		};
			
		NSLog(@"imageURL:%@", self.imageURL);
			
		// Get the asset for the asset URL.
		[assetsLibrary assetForURL:self.imageURL resultBlock:resultsBlock failureBlock:failureBlock];
		
		// Release the assets library now that we are done with it.
		[assetsLibrary release];
		
		CGImageRef CGImage = image.CGImage;	
		
		int imgWidth = CGImageGetWidth(CGImage);
		int imgHeight = CGImageGetHeight(CGImage);
		
		NSLog(@"%d x %d", imgWidth, imgHeight);		
		
//		[[self image] release];
  }
	
	[[picker parentViewController] dismissModalViewControllerAnimated:YES];

	[[[self captureManager] session] startRunning];
	[self startAnimation];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
	[[[self captureManager] session] startRunning];
	[self startAnimation];
	
	[picker dismissModalViewControllerAnimated:YES];
}

- (IBAction)togglePhoto:(id)sender
{
	[self stopAnimation];
	[[[self captureManager] session] stopRunning];
	
  // UIImagePickerController let's the user choose an image.
  UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
  imagePicker.delegate = self;
  imagePicker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
	
  [self presentModalViewController:imagePicker animated:YES];
  [imagePicker release];
}

- (IBAction)toggleEffect:(id)sender
{
	//disable input
//	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	_grid = 1;
	_gcount = 9;
		
	iad.hidden = FALSE;
		
	cameraToggleButton.hidden = TRUE;
	stillButton.hidden = TRUE;
	effectButton.hidden = TRUE;
	photoButton.hidden = TRUE;
	page.hidden = FALSE;
	
	leftButton.hidden = FALSE;
	rightButton.hidden = FALSE;
	
	_bindex = _bvisible;
	
//	_sindex = 0;
//	page.currentPage = 0;
	
	/////	
	int pindex = _sindex;
	for (int n=0; n<9; ++n)
	{
		if (n == 4)
			continue;
		
		_pindex[n] = pindex+2;
		pindex ++;
	}
		
	_pindex[4] = 1;
	
	_center.x = _center.y = 0.5;
	
//	[[UIApplication sharedApplication] endIgnoringInteractionEvents];

}

- (IBAction)togglePage:(id)sender
{
}

- (IBAction)setParam1:(id)sender
{
}

- (IBAction)setParam2:(id)sender
{
}

- (UIImage *)screenshotImage
{
	AVCaptureVideoOrientation orientation = [[self captureManager] orientation];
	UIImageOrientation uiorientation;
	
	if (orientation == AVCaptureVideoOrientationPortrait)
		uiorientation = UIImageOrientationRight;
	else if (orientation == AVCaptureVideoOrientationPortraitUpsideDown)
		uiorientation = UIImageOrientationLeft;
	
	// AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
	else if (orientation == AVCaptureVideoOrientationLandscapeRight)
		uiorientation = UIImageOrientationUp;
	else if (orientation == AVCaptureVideoOrientationLandscapeLeft)
		uiorientation = UIImageOrientationDown;
	
	UIImage *image = [(EAGLView *)self.view screenshotImage:uiorientation];
	return image;
}

// Thread Function
- (void) captureThread: (NSString *)name
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSLog(@"Thread: %@", name);

	[[self captureManager] captureStillImage];
	
	[pool release];
}

- (IBAction)captureStillImage:(id)sender
{
//	NSString *path = [[NSBundle mainBundle] pathForResource:@"Camera" ofType:@"wav"];
	
	/*
	SystemSoundID soundID;
	AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath:path], &soundID);
	AudioServicesPlaySystemSound(soundID);		
	AudioServicesDisposeSystemSoundID(soundID);
	*/
	
//	activityIndicatorView.hidden = FALSE;
//	[[self activityIndicatorView] startAnimating];

	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	// Capture a still image
	[[self stillButton] setEnabled:NO];

	[self photoFrame];

	[[self player] play];
	
	NSString *str = @"captureStillImage";
	NSThread *thread = [[NSThread alloc] initWithTarget:self
																						 selector:@selector(captureThread:) object:str];
	[thread start];
	
	// Flash the screen white and fade it out to give UI feedback that a still image was taken
	UIView *flashView = [[UIView alloc] initWithFrame:[[self view] frame]];
	[flashView setBackgroundColor:[UIColor whiteColor]];
	[[[self view] window] addSubview:flashView];
	
	[UIView animateWithDuration:.4f
									 animations:^{
										 [flashView setAlpha:0.f];
									 }
									 completion:^(BOOL finished){
										 [flashView removeFromSuperview];
										 [flashView release];
									 }
	 ];

//	[[self activityIndicatorView] stopAnimating];
//	activityIndicatorView.hidden = TRUE;
	
	[[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source)
    {
#if defined(DEBUG)	
        NSLog(@"Failed to load vertex shader");
#endif
        return FALSE;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        glDeleteShader(*shader);
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
	
#if defined(DEBUG)	
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
	
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

- (GLuint)loadShader:(NSString *)vertexShaderName fragment:(NSString *)fragmentShaderName
{
	GLuint vertShader=0, fragShader=0;
  NSString *vertShaderPathname, *fragShaderPathname;
	
  // Create shader program.
  GLuint program = glCreateProgram();
	
  // Create and compile vertex shader.
  vertShaderPathname = [[NSBundle mainBundle] pathForResource:vertexShaderName ofType:@"vsh"];
  if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname])
  {
    if (vertShader)
			glDeleteShader(vertShader);

		glDeleteProgram(program);

#if defined(DEBUG)	
    NSLog(@"Failed to compile vertex shader");
#endif
    return 0;
  }
	
  // Create and compile fragment shader.
  fragShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShaderName ofType:@"fsh"];
  if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname])
  {
    if (vertShader)
			glDeleteShader(vertShader);

    if (fragShader)
      glDeleteShader(fragShader);

    glDeleteProgram(program);
		
#if defined(DEBUG)	
    NSLog(@"Failed to compile fragment shader");
#endif
    return 0;
  }
	
  // Attach vertex shader to program.
  glAttachShader(program, vertShader);
	
  // Attach fragment shader to program.
  glAttachShader(program, fragShader);
	
	// Bind attribute locations.
	// This needs to be done prior to linking.
	glBindAttribLocation(program, ATTRIB_POSITION, "position");
	glBindAttribLocation(program, ATTRIB_TEXCOORD0, "texcoord0");
	
  // Link program.
  if (![self linkProgram:program])
  {
#if defined(DEBUG)	
    NSLog(@"Failed to link program: %d", program);
#endif
		
    if (vertShader)
			glDeleteShader(vertShader);
		
    if (fragShader)
      glDeleteShader(fragShader);
		
    glDeleteProgram(program);
		
    return 0;
	}
	
	// Get uniform locations.
	uniforms[UNIFORM_TEXTURE0] = glGetUniformLocation(program, "texture0");
	uniforms[UNIFORM_TEXTURE1] = glGetUniformLocation(program, "texture1");
	uniforms[UNIFORM_TEXTURE2] = glGetUniformLocation(program, "texture2");
	uniforms[UNIFORM_TEXTURE3] = glGetUniformLocation(program, "texture3");
	
	uniforms[UNIFORM_GAMMA] = glGetUniformLocation(program, "gamma");
	uniforms[UNIFORM_NUMCOLORS] = glGetUniformLocation(program, "numColors");
	
	uniforms[UNIFORM_TIME] = glGetUniformLocation(program, "time");
	
	uniforms[UNIFORM_WIDTH] = glGetUniformLocation(program, "width");
	uniforms[UNIFORM_HEIGHT] = glGetUniformLocation(program, "height");
	
  // Release vertex and fragment shaders.
  if (vertShader)
    glDeleteShader(vertShader);
	
  if (fragShader)
    glDeleteShader(fragShader);
	
  return program;
}

- (BOOL)loadShaders
{
	for (int n=0; n<MAX_SHADERS; ++n)
	{
		NSString *fs = [[NSString alloc] initWithFormat:@"Shader_%02d", n];
		
#if defined(DEBUG)	
		NSLog(@"loadShader: fragment shader (%@)", fs);
#endif
		
		_program[n] = [self loadShader:@"Shader" fragment:fs];
		[fs release];		
		
		_pcount = n;
		
		if (_program[n] == 0)
			return FALSE;
	}
	
	return TRUE;
}

- (void)presentFramebuffer
{
	/*
	 (-1,1 0,1)         (1,1 0,0)
	 +(2)-----------+(3)
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 +(0)-----------+(1)
	 (-1,-1, 1,1)       (1,-1 1,0)
	 */
	
	// Replace the implementation of this method to do your own custom drawing.
	static const GLfloat squarePosition[] = {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		-1.0f,  1.0f,
		1.0f,  1.0f,
	};
	
	static const GLfloat squareTexCoord0[] = {
		1.0f, 1.0f,
		1.0f, 0.0f,
		0.0f,  1.0f,
		0.0f,  0.0f,
	};
	
	// Use shader program.
	glUseProgram(_program[0]);
	
	// Bind attribute locations.
	// This needs to be done prior to linking.
	glBindAttribLocation(_program[0], ATTRIB_POSITION, "position");
	glBindAttribLocation(_program[0], ATTRIB_TEXCOORD0, "texcoord0");
	
	// Get uniform locations.
	uniforms[UNIFORM_TEXTURE0] = glGetUniformLocation(_program[0], "texture0");
	
	// Update uniform values
	glUniform1i(uniforms[UNIFORM_TEXTURE0], 0);
	
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_POSITION, 2, GL_FLOAT, 0, 0, squarePosition);
	glEnableVertexAttribArray(ATTRIB_POSITION);
	glVertexAttribPointer(ATTRIB_TEXCOORD0, 2, GL_FLOAT, 0, 0, squareTexCoord0);
	glEnableVertexAttribArray(ATTRIB_TEXCOORD0);
	
	// Validate program before drawing. This is a good check, but only really necessary in a debug build.
	// DEBUG macro must be defined in your debug configurations if that's not already the case.
#if defined(DEBUG)
	if (![self validateProgram:_program[0]])
	{
		NSLog(@"Failed to validate program: %d", _program[0]);
		return;
	}
#endif
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)drawFrame_
{
	/*
	 (-1,1 0,1)         (1,1 0,0)
	 +(2)-----------+(3)
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 +(0)-----------+(1)
	 (-1,-1, 1,1)       (1,-1 1,0)
	 */
	
	// Replace the implementation of this method to do your own custom drawing.
	static const GLfloat squarePosition[] = {
	  -1.0f, -1.0f,
		1.0f, -1.0f,
	  -1.0f,  1.0f,
		1.0f,  1.0f,
		
		//0,0
		-1.00f, 0.33f,
		-0.33f, 0.33f,
		-1.00f, 1.00f,
		-0.33f, 1.00f,
		
		//0,1
		-0.32f, 0.33f,
		0.34f, 0.33f,
		-0.32f, 1.00f,
		0.34f, 1.00f,
		
		//0,2
		0.35f, 0.33f,
		1.00f, 0.33f,
		0.35f, 1.00f,
		1.00f, 1.00f,
		
		//1,0
		-1.00f, -0.32f,
		-0.33f, -0.32f,
		-1.00f,  0.32f,
		-0.33f,  0.32f,
		
		//1,1
		-0.32f, -0.32f,
		0.34f, -0.32f,
		-0.32f,  0.32f,
		0.34f,  0.32f,
		
		//1,2
		0.35f, -0.32f,
		1.00f, -0.32f,
		0.35f,  0.32f,
		1.00f,  0.32f,
		
		//2,0
		-1.00f, -1.00f,
		-0.33f, -1.00f,
		-1.00f, -0.33f,
		-0.33f, -0.33f,
		
		//2,1
		-0.32f, -1.00f,
		0.34f, -1.00f,
		-0.32f, -0.33f,
		0.34f, -0.33f,
		
		//2,2
		0.35f, -1.00f,
		1.00f, -1.00f,
		0.35f, -0.33f,
		1.00f, -0.33f,		
		
#ifdef USE_FB
		//0,0
		-1.00f, 0.33f,
		-0.42f, 0.33f,
		-1.00f, 1.00f,
		-0.42f, 1.00f,
		
		//0,1
		-0.41f, 0.33f,//lb
		0.18f, 0.33f,//lt
		-0.41f, 1.00f,//rb
		0.18f, 1.00f,//rt
		
		//0,2
		0.19f, 0.33f,
		0.79f, 0.33f,
		0.19f, 1.00f,
		0.79f, 1.00f,
		
		//1,0
		-1.00f, -0.33f,
		-0.42f, -0.33f,
		-1.00f,  0.34f,
		-0.42f,  0.34f,
		
		//1,1
		-0.41f, -0.33f,
		0.18f, -0.33f,
		-0.41f,  0.32f,
		0.18f,  0.32f,
		
		//1,2
		0.19f, -0.33f,
		0.79f, -0.33f,
		0.19f,  0.32f,
		0.79f,  0.32f,
		
		//2,0
		-1.00f, -1.00f,
		-0.42f, -1.00f,
		-1.00f, -0.34f,
		-0.42f, -0.34f,
		
		//2,1
		-0.41f, -1.00f,
		0.18f, -1.00f,
		-0.41f, -0.34f,
		0.18f, -0.34f,
		
		//2,2
		0.19f, -1.00f,
		0.79f, -1.00f,
		0.19f, -0.34f,
		0.79f, -0.34f,
#else
		//0,0
		-1.00f, 0.42f,
		-0.33f, 0.42f,
		-1.00f, 1.00f,
		-0.33f, 1.00f,
		
		//0,1
		-0.32f, 0.42f,//lb
		0.32f, 0.42f,//lt
		-0.32f, 1.00f,//rb
		0.32f, 1.00f,//rt
		
		//0,2
		0.33f, 0.42f,
		1.00f, 0.42f,
		0.33f, 1.00f,
		1.00f, 1.00f,
		
		//1,0
		-1.00f, -0.21f,
		-0.33f, -0.21f,
		-1.00f,  0.41f,
		-0.33f,  0.41f,
		
		//1,1
		-0.32f, -0.21f,
		0.32f, -0.21f,
		-0.32f,  0.41f,
		0.32f,  0.41f,
		
		//1,2
		0.33f, -0.21f,
		1.00f, -0.21f,
		0.33f,  0.41f,
		1.00f,  0.41f,
		
		//2,0
		-1.00f, -0.78f,
		-0.33f, -0.78f,
		-1.00f, -0.22f,
		-0.33f, -0.22f,
		
		//2,1
		-0.32f, -0.78f,
		0.32f, -0.78f,
		-0.32f, -0.22f,
		0.32f, -0.22f,
		
		//2,2
		0.33f, -0.78f,
		1.00f, -0.78f,
		0.33f, -0.22f,
		1.00f, -0.22f,
#endif
		
	};
	
	static const GLfloat squareTexCoord0[] = {
#ifdef USE_FB
		//front
		0.0f, 1.0f,
		1.0f, 1.0f,
		0.0f, 0.0f,
		1.0f, 0.0f,
		
		//back
		0.0f, 0.0f,
		1.0f, 0.0f,
		0.0f, 1.0f,
		1.0f, 1.0f,
#else		
		1.0f, 0.0f,
		1.0f, 1.0f,
		0.0f,  0.0f,
		0.0f,  1.0f,		
		
		1.0f, 1.0f,
		1.0f, 0.0f,
		0.0f,  1.0f,
		0.0f,  0.0f,		
#endif
	};
	
	if (_grid)
	{
		glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	//	glActiveTexture(GL_TEXTURE0);
	//	glBindTexture(GL_TEXTURE_2D, _texture);
	
	//	glActiveTexture(GL_TEXTURE1);
	//	glBindTexture(GL_TEXTURE_2D, _texture);
	
	for (int n=0; n<_gcount; ++n)
	{
		GLuint program = _program[_pindex[n]];
		
		// Use shader program.
		glUseProgram(program);
		
		// Bind attribute locations.
		// This needs to be done prior to linking.
		glBindAttribLocation(program, ATTRIB_POSITION, "position");
		glBindAttribLocation(program, ATTRIB_TEXCOORD0, "texcoord0");
		
		// Get uniform locations.
		uniforms[UNIFORM_TEXTURE0] = glGetUniformLocation(program, "texture0");
		//	uniforms[UNIFORM_TEXTURE1] = glGetUniformLocation(program, "texture1");
		//	uniforms[UNIFORM_TEXTURE2] = glGetUniformLocation(program, "texture2");
		//	uniforms[UNIFORM_TEXTURE3] = glGetUniformLocation(program, "texture3");
		
		uniforms[UNIFORM_GAMMA] = glGetUniformLocation(program, "gamma");
		uniforms[UNIFORM_NUMCOLORS] = glGetUniformLocation(program, "numColors");
		
		uniforms[UNIFORM_TIME] = glGetUniformLocation(program, "time");
		
		uniforms[UNIFORM_WIDTH] = glGetUniformLocation(program, "width");
		uniforms[UNIFORM_HEIGHT] = glGetUniformLocation(program, "height");
		
		uniforms[UNIFORM_SHOCK_PARAMS] = glGetUniformLocation(program, "shockParams");
		uniforms[UNIFORM_CENTER] = glGetUniformLocation(program, "center");
		
		uniforms[UNIFORM_MIRROR] = glGetUniformLocation(program, "mirror");
		
		uniforms[UNIFORM_PARAM1] = glGetUniformLocation(program, "param1");
		uniforms[UNIFORM_PARAM2] = glGetUniformLocation(program, "param2");
		
		GLfloat gamma = 0.6;
		GLfloat numColors = 8.0;
		
		// Update uniform values
		glUniform1i(uniforms[UNIFORM_TEXTURE0], 0);
		//	glUniform1i(uniforms[UNIFORM_TEXTURE1], 1);
		
		glUniform1f(uniforms[UNIFORM_GAMMA], gamma);
		glUniform1f(uniforms[UNIFORM_NUMCOLORS], numColors);
		
		_end = timer_now();
		
		GLfloat ttime = (GLfloat) timer_elapsed(_start, _end);
		
		GLfloat shockParams[3] = { 10.0, 0.8, 0.1 };
		
		glUniform1f(uniforms[UNIFORM_TIME], ttime);
		
		glUniform3f(uniforms[UNIFORM_SHOCK_PARAMS], shockParams[0], shockParams[1], shockParams[2]);
		glUniform2f(uniforms[UNIFORM_CENTER], _center.x, _center.y);
		
		glUniform1i(uniforms[UNIFORM_MIRROR], _cindex);
		
		glUniform1f(uniforms[UNIFORM_WIDTH], _width);
		glUniform1f(uniforms[UNIFORM_HEIGHT], _height);
		
		// Update attribute values.
		glVertexAttribPointer(ATTRIB_POSITION, 2, GL_FLOAT, 0, 0, squarePosition + (n+_grid)*8 + _bindex * 9*8);
		glEnableVertexAttribArray(ATTRIB_POSITION);
		glVertexAttribPointer(ATTRIB_TEXCOORD0, 2, GL_FLOAT, 0, 0, squareTexCoord0 + _cindex * 8);
		glEnableVertexAttribArray(ATTRIB_TEXCOORD0);
		
		// Validate program before drawing. This is a good check, but only really necessary in a debug build.
		// DEBUG macro must be defined in your debug configurations if that's not already the case.
#if defined(DEBUG)
		if (![self validateProgram:program])
		{
			NSLog(@"Failed to validate program: %d", program);
			return;
		}
#endif
		
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	}
	
/*	glUseProgram(0);
	
	glActiveTexture(GL_TEXTURE0);	
	glBindTexture(GL_TEXTURE_2D, 0);
	
	glDisableVertexAttribArray(ATTRIB_POSITION);
	glDisableVertexAttribArray(ATTRIB_TEXCOORD0);*/
}

- (void)drawPhoto_
{
	/*
	 (-1,1 0,1)         (1,1 0,0)
	 +(2)-----------+(3)
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 |              |
	 +(0)-----------+(1)
	 (-1,-1, 1,1)       (1,-1 1,0)
	 */
	
	// Replace the implementation of this method to do your own custom drawing.
	static const GLfloat squarePosition[] = {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		-1.0f,  1.0f,
		1.0f,  1.0f,
	};
	
	static const GLfloat squareTexCoord0[] = {
		//front
		0.0f, 1.0f,
		1.0f, 1.0f,
		0.0f, 0.0f,
		1.0f, 0.0f,
		
		//back
		0.0f, 0.0f,
		1.0f, 0.0f,
		0.0f, 1.0f,
		1.0f, 1.0f,
	};
	
	// Use shader program.
	GLuint program = _program[_pindex[0]];
	glUseProgram(program);
	
	// Bind attribute locations.
	// This needs to be done prior to linking.
	glBindAttribLocation(program, ATTRIB_POSITION, "position");
	glBindAttribLocation(program, ATTRIB_TEXCOORD0, "texcoord0");
	
	// Get uniform locations.
	uniforms[UNIFORM_TEXTURE0] = glGetUniformLocation(program, "texture0");
	
	// Update uniform values
	glUniform1i(uniforms[UNIFORM_TEXTURE0], 0);
	
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_POSITION, 2, GL_FLOAT, 0, 0, squarePosition);
	glEnableVertexAttribArray(ATTRIB_POSITION);
	glVertexAttribPointer(ATTRIB_TEXCOORD0, 2, GL_FLOAT, 0, 0, squareTexCoord0 + _cindex * 8);
	glEnableVertexAttribArray(ATTRIB_TEXCOORD0);
	
	// Validate program before drawing. This is a good check, but only really necessary in a debug build.
	// DEBUG macro must be defined in your debug configurations if that's not already the case.
#if defined(DEBUG)
	if (![self validateProgram:program])
	{
		NSLog(@"Failed to validate program: %d", program);
		return;
	}
#endif
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)photoFrame
{
	[(EAGLView *)self.view setPhotoFramebuffer];

	[self drawPhoto_];
}

double dt_frame = 0;
uint64_t t_frame = 0;

- (void)drawFrame
{
#if defined(DEBUG)
	static bool firstCall = true;
	if (firstCall)
	{
		t_frame = timer_now();
		dt_frame = 0;
		
		firstCall = false;
	}
	
	uint64_t now = timer_now();
	if (dt_frame)
		dt_frame = (dt_frame + timer_elapsed(t_frame, now)) / 2.0;
	else
		dt_frame = timer_elapsed(t_frame, now);
	t_frame = now;
	
	[fps setText:[NSString stringWithFormat:@"fps: %ld", (int)(1.0f / dt_frame)]];
#endif
	
#ifdef USE_FB
	[(EAGLView *)self.view setPhotoFramebuffer];
#else
	[(EAGLView *)self.view setFramebuffer];
#endif
	
	[self drawFrame_];
	
#ifdef USE_FB	
	[(EAGLView *)self.view setFramebuffer];
	
	[self presentFramebuffer];
#endif
	
	[(EAGLView *)self.view presentFramebuffer];
}

@end


@implementation PhotoXViewController (InternalMethods)

// Convert from view coordinates to camera coordinates, where {0,0} represents the top left of the picture area, and {1,1} represents
// the bottom right in landscape mode with the home button on the right.
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates 
{
	CGPoint pointOfInterest = CGPointMake(.5f, .5f);
	CGSize frameSize = [[self view] frame].size;
	
	CGRect cleanAperture;
	for (AVCaptureInputPort *port in [[[self captureManager] videoInput] ports]) {
		if ([port mediaType] == AVMediaTypeVideo) {
			cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
			CGSize apertureSize = cleanAperture.size;
			CGPoint point = viewCoordinates;
			
			CGFloat apertureRatio = apertureSize.height / apertureSize.width;
			CGFloat viewRatio = frameSize.width / frameSize.height;
			CGFloat xc = .5f;
			CGFloat yc = .5f;
			
			// Scale, switch x and y, and reverse x
			if (viewRatio > apertureRatio) {
				CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
				xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2; // Account for cropped height
				yc = (frameSize.width - point.x) / frameSize.width;
			} else {
				CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
				yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2); // Account for cropped width
				xc = point.y / frameSize.height;
			}
			
			pointOfInterest = CGPointMake(xc, yc);
		}
	}
	
	return pointOfInterest;
}

// Auto focus at a particular point. The focus mode will change to locked once the auto focus happens.
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
	if (cameraToggleButton.hidden == FALSE)
	{
		if ([[[captureManager videoInput] device] isFocusPointOfInterestSupported]) {
			CGPoint tapPoint = [gestureRecognizer locationInView:[self view]];
			CGPoint convertedFocusPoint = [self convertToPointOfInterestFromViewCoordinates:tapPoint];
			[captureManager autoFocusAtPoint:convertedFocusPoint];
		}

		CGPoint tapPoint = [gestureRecognizer locationInView:[self view]];
		CGRect rect = [(EAGLView *)self.view bounds]; 

		CGSize frameSize = [[self view] frame].size;

		float th = frameSize.height / 3;
		if (tapPoint.y > th*2.7)
			return;
		
		if (_cindex)
		{
			_center.y = 1.0 - tapPoint.x / rect.size.width;
			_center.x = tapPoint.y / rect.size.height;
		}
		else
		{
			_center.y = tapPoint.x / rect.size.width;
			_center.x = tapPoint.y / rect.size.height;
		}
		_start = timer_now();
	}
	else
	{
		CGPoint tapPoint = [gestureRecognizer locationInView:[self view]];
		CGSize frameSize = [[self view] frame].size;

#if defined(DEBUG)	
		NSLog(@"%f, %f  %f,%f", tapPoint.x, tapPoint.y, frameSize.width, frameSize.height);
#endif
		
		float tw = frameSize.width / 3;
		float th = frameSize.height / 3;
		
		int pw = 0;
		int ph = 0;
		
		if (tapPoint.x < tw)
			pw = 0;
		else if (tapPoint.x <tw*2)
			pw = 1;
		else
			pw = 2;
		
		if (tapPoint.y < th)
			ph = 0;
		else if (tapPoint.y <th*2)
			ph = 1;
		else if (tapPoint.y <th*2.7)
			ph = 2;
		else
			return;
		
		//
#ifdef USE_FB		
		int pindex = ph + (pw*3);
#else
		int pindex = pw + (ph*3);
#endif
		
		_grid = 0;
		_gcount = 1;
		
		iad.hidden = TRUE;
		_bindex= 0;
		
		cameraToggleButton.hidden = FALSE;
		stillButton.hidden = FALSE;
		effectButton.hidden = FALSE;
		photoButton.hidden = FALSE;
		page.hidden = TRUE;
		
		leftButton.hidden = TRUE;
		rightButton.hidden = TRUE;
		
		int _11 = 0;
		if (pindex == 4)
			_11 = 1;
		
		if (pindex < 4)
			pindex = pindex + 1;
		
		if (_11 == 0)
			pindex += _sindex;
		else
			pindex = 0;
		
		_pindex[0] = pindex +1;

		_center.x = _center.y = 0.5;
		
#if defined(DEBUG)	
		NSLog(@"pindex: %d %f", pindex, th*2.8);
#endif
	}
}

// Change to continuous auto focus. The camera will constantly focus at the point choosen.
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
	if ([[[captureManager videoInput] device] isFocusPointOfInterestSupported])
		[captureManager continuousFocusAtPoint:CGPointMake(.5f, .5f)];
}

- (void)moveToLeftOrRight:(UISwipeGestureRecognizer *)gestureRecognizer
{
	if (cameraToggleButton.hidden == FALSE)
		return;
		
	if (page.currentPage == 0)
	{
		_sindex = 8;
		
		page.currentPage = 1;
	}
	else
	{
		_sindex = 0;
		
		page.currentPage = 0;
	}

	int pindex = _sindex;
	for (int n=0; n<9; ++n)
	{
		if (n == 4)
			continue;
			
		_pindex[n] = pindex+2;
		pindex ++;
	}
		
	_pindex[4] = 1;
}

// Update button states based on the number of available cameras and mics
- (void)updateButtonStates
{
	NSUInteger cameraCount = [[self captureManager] cameraCount];
	
	CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
		if (cameraCount < 2) {
			[[self cameraToggleButton] setEnabled:NO]; 
			
			if (cameraCount < 1) {
				[[self stillButton] setEnabled:NO];
				
			} else {
				[[self stillButton] setEnabled:YES];
			}
		} else {
			[[self cameraToggleButton] setEnabled:YES];
			[[self stillButton] setEnabled:YES];
		}
	});
}

@end

@implementation PhotoXViewController (AVCamCaptureManagerDelegate)

- (void)captureManager:(AVCaptureManager *)captureManager didFailWithError:(NSError *)error
{
	CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
																												message:[error localizedFailureReason]
																											 delegate:nil
																							cancelButtonTitle:NSLocalizedString(@"OK", @"OK button title")
																							otherButtonTitles:nil];
		[alertView show];
		[alertView release];
	});
}

- (void)captureManagerStillImageCaptured:(AVCaptureManager *)captureManager
{
	CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
		[[self stillButton] setEnabled:YES];
	});
}

- (void)captureManagerDeviceConfigurationChanged:(AVCaptureManager *)captureManager
{
	[self updateButtonStates];
}

- (void) captureManagerDataOutput:(AVCaptureOutput *)captureOutput
						didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
									 fromConnection:(AVCaptureConnection *)connection
{
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	
	// Lock the image buffer
	CVPixelBufferLockBaseAddress(imageBuffer,0);
	
	// Get information about the image
	void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
	//size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);
	
	/*	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	 CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	 CGImageRef cgimage = CGBitmapContextCreateImage(newContext);
	 UIImage *sourceImage= [UIImage imageWithCGImage:cgimage scale:1.0f orientation:UIImageOrientationLeftMirrored];
	 CGImageRelease(cgimage);
	 CGContextRelease(newContext);
	 CGColorSpaceRelease(colorSpace);
	 */
	
	glActiveTexture(GL_TEXTURE0);	
	glBindTexture(GL_TEXTURE_2D, _texture);
	
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
	// This is necessary for non-power-of-two textures
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	// Using BGRA extension to pull in video frame data directly
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, baseAddress);
	
	_width = width;
	_height = height;
	
	// We unlock the  image buffer
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);

#if defined(DEBUG)	
	//	NSLog(@"captureManagerDataOutput: %lu x %lu", width, height);
#endif
}
@end
