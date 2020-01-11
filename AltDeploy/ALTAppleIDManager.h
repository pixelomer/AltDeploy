//
//  ALTAppleIDManager.h
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTAppleIDManager : NSObject

+ (instancetype)sharedManager;
- (NSArray <NSDictionary *> *)getAllAppleIDs;
- (BOOL)getLastAppleID:(NSString *_Nullable*_Nullable)usernamePt;
- (NSString *)passwordOfAppleID:(NSString *)username;
- (BOOL)addAppleID:(NSString *)username password:(NSString *)password;
- (void)removeAppleID:(NSString *)username;

@end

NS_ASSUME_NONNULL_END
