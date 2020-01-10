//
//  ALTMainViewController.h
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ALTAddAppleIDDelegate;
@protocol ALTDragDropViewDelegate;

@interface ALTMainViewController : NSViewController<ALTAddAppleIDDelegate, ALTDragDropViewDelegate>
@property (weak) IBOutlet NSTextField *descriptionLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSView *progressContainerView;
@property (weak) IBOutlet NSPopUpButton *accountButton;
@property (weak) IBOutlet NSPopUpButton *deviceButton;
@property (weak) IBOutlet NSPopUpButton *actionButton;
@property (weak) IBOutlet NSButton *startButton;
+ (BOOL)isPluginInstalled;
+ (NSString *)mailBundlesPath;
+ (NSString *)altPluginPath;
@end

NS_ASSUME_NONNULL_END
