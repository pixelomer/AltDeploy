//
//  ALTAppleIDManager.m
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import "ALTAppleIDManager.h"
#import <SAMKeychain/SAMKeychain.h>

@implementation ALTAppleIDManager

+ (instancetype)sharedManager {
    static ALTAppleIDManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ALTAppleIDManager alloc] init];
    });
    return manager;
}

- (BOOL)getLastAppleID:(NSString **)usernamePt {
    NSDictionary *account = [SAMKeychain accountsForService:NSBundle.mainBundle.bundleIdentifier].lastObject;
    if (!account) return NO;
    if (usernamePt) *usernamePt = [account[kSAMKeychainAccountKey] copy];
    return YES;
}

- (BOOL)addAppleID:(NSString *)username password:(NSString *)password {
    for (NSDictionary *account in [SAMKeychain accountsForService:NSBundle.mainBundle.bundleIdentifier]) {
        if ([account[kSAMKeychainAccountKey] isEqualToString:username]) {
            [SAMKeychain deletePasswordForService:NSBundle.mainBundle.bundleIdentifier account:account[kSAMKeychainAccountKey]];
            break;
        }
    }
    return [SAMKeychain setPassword:password forService:NSBundle.mainBundle.bundleIdentifier account:username error:nil];
}

- (NSArray <NSDictionary *> *)getAllAppleIDs {
    return [SAMKeychain accountsForService:NSBundle.mainBundle.bundleIdentifier];
}

- (NSString *)passwordOfAppleID:(NSString *)username {
    return [SAMKeychain passwordForService:NSBundle.mainBundle.bundleIdentifier account:username];
}

@end
