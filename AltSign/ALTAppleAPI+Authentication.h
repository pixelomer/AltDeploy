//
//  ALTAppleAPI+Authentication.h
//  AltSign
//
//  Created by Riley Testut on 11/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@class ALTAppleAPISession;

#import <AltSign/AltSign.h>

@class ALTAppleAPISession;

NS_ASSUME_NONNULL_BEGIN

@interface ALTAppleAPI (Authentication)

- (void)authenticateWithAppleID:(NSString *)appleID
                       password:(NSString *)password
                   anisetteData:(ALTAnisetteData *)anisetteData
              verificationHandler:(nullable void (^)(void (^completionHandler)(NSString *_Nullable verificationCode)))verificationHandler
              completionHandler:(void (^)(ALTAccount *_Nullable account, ALTAppleAPISession *_Nullable session, NSError *_Nullable error))completionHandler
NS_SWIFT_NAME(authenticate(appleID:password:anisetteData:verificationHandler:completionHandler:));

@end

NS_ASSUME_NONNULL_END
