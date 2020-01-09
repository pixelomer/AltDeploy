//
//  ALTAddAppleIDViewController.h
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ALTAddAppleIDDelegate <NSObject>
- (void)didAddAppleID;
@end

@interface ALTAddAppleIDViewController : NSViewController
@property (nonatomic, weak) id <ALTAddAppleIDDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
