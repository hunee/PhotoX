//
//  PhotoXViewController.h
//  PhotoX
//
//  Created by Jang Jeonghun on 4/20/11.
//  Copyright 2011 home. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <OpenGLES/EAGL.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <iAd/iAd.h>

typedef struct {
	CGFloat x, y, z;
} CGVector3;

#define MAX_SHADERS	(19)
#define MAX_VIEW		(9)

@class AVCaptureManager;

@interface PhotoXViewController : UIViewController <ADBannerViewDelegate, AVAudioPlayerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
@private
	BOOL animating;
	NSInteger animationFrameInterval;
	CADisplayLink *displayLink;
	
	EAGLContext *_context;
	
	GLuint _program[MAX_SHADERS];
  int _pindex[MAX_VIEW], _pcount;
	
	GLuint _texture;
	GLfloat _width, _height;
	
	uint64_t _start;
	uint64_t _end;
	
	int _cindex;
	
	int _grid;
	int _gcount;

	BOOL _bvisible;
	int _bindex;
	
	int _sindex;
	CGPoint _center;
	
	AVAudioPlayer	*player;	
	
  NSURL		  *imageURL;
  ALAsset	  *imageAsset;
  UIImage	  *image;
}

@property (readonly, nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) NSInteger animationFrameInterval;

@property (nonatomic,retain) AVCaptureManager *captureManager;
@property (nonatomic,retain) IBOutlet UIButton *cameraToggleButton;
@property (nonatomic,retain) IBOutlet UIButton *stillButton;
@property (nonatomic,retain) IBOutlet UIButton *effectButton;
@property (nonatomic,retain) IBOutlet UIButton *photoButton;

@property (nonatomic,retain) IBOutlet UIButton *leftButton;
@property (nonatomic,retain) IBOutlet UIButton *rightButton;

@property (nonatomic,retain) IBOutlet ADBannerView *iad;
@property (nonatomic,retain) IBOutlet UIPageControl *page;

@property (nonatomic,retain) IBOutlet UILabel *fps;

@property (nonatomic,retain) IBOutlet UISlider *param1Slider;
@property (nonatomic,retain) IBOutlet UISlider *param2Slider;

@property (nonatomic,retain) IBOutlet UIActivityIndicatorView *activityIndicatorView;

@property (nonatomic, assign)	AVAudioPlayer	*player;

@property (retain, readwrite) NSURL	      *imageURL;
@property (retain, readwrite) ALAsset	    *imageAsset;
@property (retain, readwrite) UIImage	    *image;

- (void)startAnimation;
- (void)stopAnimation;

#pragma mark Toolbar Actions
- (IBAction)captureStillImage:(id)sender;
- (IBAction)toggleCamera:(id)sender;
- (IBAction)toggleEffect:(id)sender;
- (IBAction)togglePhoto:(id)sender;
- (IBAction)togglePage:(id)sender;

- (IBAction)setParam1:(id)sender;
- (IBAction)setParam2:(id)sender;

@end
