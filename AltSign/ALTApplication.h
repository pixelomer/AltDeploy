//
//  ALTApplication.h
//  AltSign
//
//  Created by Riley Testut on 6/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "ALTCapabilities.h"

@class ALTProvisioningProfile;

NS_ASSUME_NONNULL_BEGIN

@interface ALTApplication : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, copy, readonly) NSString *version;

#if TARGET_OS_IPHONE
@property (nonatomic, readonly) UIImage *icon;
#endif

@property (nonatomic, readonly, nullable) ALTProvisioningProfile *provisioningProfile;

@property (nonatomic, readonly) NSOperatingSystemVersion minimumiOSVersion;

@property (nonatomic, copy, readonly) NSDictionary<ALTEntitlement, id> *entitlements;

@property (nonatomic, copy, readonly) NSURL *fileURL;

- (nullable instancetype)initWithFileURL:(NSURL *)fileURL;

@end

NS_ASSUME_NONNULL_END
