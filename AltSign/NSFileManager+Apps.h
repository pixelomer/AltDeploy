//
//  NSFileManager+Apps.h
//  AltSign
//
//  Created by Riley Testut on 5/28/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (Apps)

- (nullable NSURL *)unzipAppBundleAtURL:(NSURL *)ipaURL toDirectory:(NSURL *)directoryURL error:(NSError **)error;
- (nullable NSURL *)zipAppBundleAtURL:(NSURL *)appBundleURL error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
