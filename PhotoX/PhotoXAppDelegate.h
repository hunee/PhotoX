//
//  PhotoXAppDelegate.h
//  PhotoX
//
//  Created by Jang Jeonghun on 4/20/11.
//  Copyright 2011 home. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PhotoXViewController;

@interface PhotoXAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet PhotoXViewController *viewController;

@end
