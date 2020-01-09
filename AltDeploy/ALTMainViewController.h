//
//  ALTMainViewController.h
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTMainViewController : NSViewController

+ (BOOL)isPluginInstalled;
+ (NSString *)mailBundlesPath;
+ (NSString *)altPluginPath;

@end

NS_ASSUME_NONNULL_END
