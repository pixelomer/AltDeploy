//
//  ViewController.h
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController {
	NSArray *devices;
	NSProgress *currentProgress;
	NSArray<NSURL *> *utilityURLs;
	NSURL *selectedFileURL;
	NSURL *selectedUtilityURL;
	NSMenuItem *pluginMenuItem;
}
@property (weak) IBOutlet NSTextField *descriptionLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSView *progressContainerView;
@property (weak) IBOutlet NSPopUpButton *deviceButton;
@property (weak) IBOutlet NSPopUpButton *actionButton;
@property (weak) IBOutlet NSButton *startButton;
+ (BOOL)isPluginInstalled;
+ (NSString *)mailBundlesPath;
+ (NSString *)altPluginPath;
@end

