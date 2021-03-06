/*
     File: AVCaptureManager.m
 Abstract: Uses the AVCapture classes to capture video and still images.
  Version: 1.2
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */

#import "AVCaptureManager.h"
#import "AVCaptureUtilities.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/CGImageProperties.h>

#pragma mark -
@interface AVCaptureManager (InternalUtilityMethods)
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) frontFacingCamera;
- (AVCaptureDevice *) backFacingCamera;
@end


#pragma mark -
@implementation AVCaptureManager

@synthesize session;
@synthesize orientation;
@synthesize videoInput;
@synthesize videoDataOutput;
@synthesize deviceConnectedObserver;
@synthesize deviceDisconnectedObserver;
@synthesize delegate;

- (id) init
{
	self = [super init];
	if (self != nil) {
		__block id weakSelf = self;
		void (^deviceConnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			AVCaptureDevice *device = [notification object];
			
			BOOL sessionHasDeviceWithMatchingMediaType = NO;
			NSString *deviceMediaType = nil;
			if ([device hasMediaType:AVMediaTypeVideo])
				deviceMediaType = AVMediaTypeVideo;
			
			if (deviceMediaType != nil) {
				for (AVCaptureDeviceInput *input in [session inputs])
				{
					if ([[input device] hasMediaType:deviceMediaType]) {
						sessionHasDeviceWithMatchingMediaType = YES;
						break;
					}
				}
				
				if (!sessionHasDeviceWithMatchingMediaType) {
					NSError	*error;
					AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
					if ([session canAddInput:input])
						[session addInput:input];
				}				
			}
			
			if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged:)]) {
				[delegate captureManagerDeviceConfigurationChanged:self];
			}
		};
		
		void (^deviceDisconnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			AVCaptureDevice *device = [notification object];
			
			if ([device hasMediaType:AVMediaTypeVideo]) {
				[session removeInput:[weakSelf videoInput]];
				[weakSelf setVideoInput:nil];
			}
			
			if ([delegate respondsToSelector:@selector(captureManagerDeviceConfigurationChanged:)]) {
				[delegate captureManagerDeviceConfigurationChanged:self];
			}
		};
		
		
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[self setDeviceConnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:deviceConnectedBlock]];
		[self setDeviceDisconnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:deviceDisconnectedBlock]];
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		[notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
		
		orientation = AVCaptureVideoOrientationPortrait;
	}

	return self;
}

- (void) dealloc
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:[self deviceConnectedObserver]];
	[notificationCenter removeObserver:[self deviceDisconnectedObserver]];
	[notificationCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	
	[[self session] stopRunning];
	[session release];
	[videoInput release];
	[videoDataOutput release];
	
	[super dealloc];
}

- (BOOL) setupSession
{
	BOOL success = NO;
	
	// Set torch and flash mode to auto
	if ([[self backFacingCamera] hasFlash]) {
		if ([[self backFacingCamera] lockForConfiguration:nil]) {
			if ([[self backFacingCamera] isFlashModeSupported:AVCaptureFlashModeAuto]) {
				[[self backFacingCamera] setFlashMode:AVCaptureFlashModeAuto];
			}
			[[self backFacingCamera] unlockForConfiguration];
		}
	}
	if ([[self backFacingCamera] hasTorch]) {
		if ([[self backFacingCamera] lockForConfiguration:nil]) {
			if ([[self backFacingCamera] isTorchModeSupported:AVCaptureTorchModeAuto]) {
				[[self backFacingCamera] setTorchMode:AVCaptureTorchModeOff];
			}
			[[self backFacingCamera] unlockForConfiguration];
		}
	}
	
	// Init the device inputs
	AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:nil];
	AVCaptureVideoDataOutput *newVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
	
	//While a frame is processes in -newVideoDataOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	// If you don't want this behaviour set the property to NO
	newVideoDataOutput.alwaysDiscardsLateVideoFrames = YES; 
	
	// We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	// in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	// In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	// we are not able to process more than 10 frames per second.
	newVideoDataOutput.minFrameDuration = CMTimeMake(1, 10);
	
	// We create a serial queue to handle the processing of our frames
/*	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[newVideoDataOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
*/	
	[newVideoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
	
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[newVideoDataOutput setVideoSettings:videoSettings]; 
    
	// Create session (use default AVCaptureSessionPresetHigh)
  AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
  
	// Add inputs and output to the capture session
	if ([newCaptureSession canAddInput:newVideoInput]) {
		[newCaptureSession addInput:newVideoInput];
	}
	if ([newCaptureSession canAddOutput:newVideoDataOutput]) {
		[newCaptureSession addOutput:newVideoDataOutput];
	}
	
	// Start capturing
	//[newCaptureSession setSessionPreset:AVCaptureSessionPresetPhoto];
	//	[newCaptureSession setSessionPreset:AVCaptureSessionPresetHigh];
	//[self.newCaptureSession setSessionPreset:AVCaptureSessionPresetMedium];
	//	[newCaptureSession setSessionPreset:AVCaptureSessionPresetLow];
//	[newCaptureSession setSessionPreset:AVCaptureSessionPreset640x480];
	//	[newCaptureSession setSessionPreset:AVCaptureSessionPreset1280x720];
	
	[self setVideoDataOutput:newVideoDataOutput];
	[self setVideoInput:newVideoInput];
	[self setSession:newCaptureSession];
	
	[newVideoDataOutput release];
	[newVideoInput release];
	[newCaptureSession release];
	
	success = YES;
  
	return success;
}

#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
			 fromConnection:(AVCaptureConnection *)connection 
{
//	if ([connection isVideoOrientationSupported])
//		[connection setVideoOrientation:orientation];
	
//	CFDictionaryRef metaDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
//	CFRelease(metaDict);
	
	[[self delegate] captureManagerDataOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
}

- (void) captureStillImage
{
/*	ALAssetsLibraryWriteImageCompletionBlock completionBlock = ^(NSURL *assetURL, NSError *error) {
		if (error) {
			if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
				[[self delegate] captureManager:self didFailWithError:error];
			}
		}
	};
*/
	
	[session stopRunning];
	
	UIImage *image = [[self delegate] screenshotImage];

	[session startRunning];	
	
#if defined(DEBUG)	
	CGSize size = [image size];
	NSLog(@"captureStillImage: %f x %f", size.width, size.height);
#endif
	
//	UIImageWriteToSavedPhotosAlbum(image, self, nil, nil); 
	
	UIImageWriteToSavedPhotosAlbum(image, self, @selector(finishUIImageWriteToSavedPhotosAlbum:didFinishSavingWithError:contextInfo:), nil);
	
/*	ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
	
	[library writeImageToSavedPhotosAlbum:[image CGImage]
														orientation:(ALAssetOrientation)[image imageOrientation]
												completionBlock:completionBlock];
	[library release];
	*/
	
	[image release];
		
	if ([[self delegate] respondsToSelector:@selector(captureManagerStillImageCaptured:)]) {
		[[self delegate] captureManagerStillImageCaptured:self];
	}
}

- (void)finishUIImageWriteToSavedPhotosAlbum:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
}

// Toggle between the front and back camera, if both are present.
- (BOOL) toggleCamera
{
	BOOL success = NO;
	
	if ([self cameraCount] > 1) {
		NSError *error;
		AVCaptureDeviceInput *newVideoInput;
		AVCaptureDevicePosition position = [[videoInput device] position];
		
		if (position == AVCaptureDevicePositionBack)
			newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:&error];
		else if (position == AVCaptureDevicePositionFront)
			newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:&error];
		else
			goto bail;
		
		if (newVideoInput != nil) {
			[[self session] beginConfiguration];
			[[self session] removeInput:[self videoInput]];
			
			if ([[self session] canAddInput:newVideoInput]) {
				[[self session] addInput:newVideoInput];
				[self setVideoInput:newVideoInput];
			} else {
				[[self session] addInput:[self videoInput]];
			}
			
			[[self session] commitConfiguration];
			success = YES;
			[newVideoInput release];
		} else if (error) {
			if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
				[[self delegate] captureManager:self didFailWithError:error];
			}
		}
	}
	
bail:
	return success;
}


#pragma mark Device Counts
- (NSUInteger) cameraCount
{
	return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

#pragma mark Camera Properties
// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void) autoFocusAtPoint:(CGPoint)point
{
	AVCaptureDevice *device = [[self videoInput] device];
	if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
		NSError *error;
		if ([device lockForConfiguration:&error]) {
			[device setFocusPointOfInterest:point];
			[device setFocusMode:AVCaptureFocusModeAutoFocus];
			[device unlockForConfiguration];
		} else {
			if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
				[[self delegate] captureManager:self didFailWithError:error];
			}
		}        
	}
}

// Switch to continuous auto focus mode at the specified point
- (void) continuousFocusAtPoint:(CGPoint)point
{
	AVCaptureDevice *device = [[self videoInput] device];
	
	if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
		NSError *error;
		if ([device lockForConfiguration:&error]) {
			[device setFocusPointOfInterest:point];
			[device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
			[device unlockForConfiguration];
		} else {
			if ([[self delegate] respondsToSelector:@selector(captureManager:didFailWithError:)]) {
				[[self delegate] captureManager:self didFailWithError:error];
			}
		}
	}
}
@end


#pragma mark -
@implementation AVCaptureManager (InternalUtilityMethods)

// Keep track of current device orientation so it can be applied to movie recordings and still image captures
- (void)deviceOrientationDidChange
{	
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
	
	if (deviceOrientation == UIDeviceOrientationPortrait)
		orientation = AVCaptureVideoOrientationPortrait;
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		orientation = AVCaptureVideoOrientationPortraitUpsideDown;
	
	// AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
		orientation = AVCaptureVideoOrientationLandscapeRight;
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
		orientation = AVCaptureVideoOrientationLandscapeLeft;
	
	// Ignore device orientations for which there is no corresponding still image orientation (e.g. UIDeviceOrientationFaceUp)
}

// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) {
		if ([device position] == position) {
			return device;
		}
	}
	
	return nil;
}

// Find a front facing camera, returning nil if one is not found
- (AVCaptureDevice *) frontFacingCamera
{
	return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

// Find a back facing camera, returning nil if one is not found
- (AVCaptureDevice *) backFacingCamera
{
	return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

@end


