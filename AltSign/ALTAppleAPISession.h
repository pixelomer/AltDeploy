//
//  ALTAppleAPISession.h
//  AltSign
//
//  Created by Riley Testut on 11/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALTAnisetteData;

NS_ASSUME_NONNULL_BEGIN

@interface ALTAppleAPISession : NSObject

@property (nonatomic, copy) NSString *dsid;
@property (nonatomic, copy) NSString *authToken;
@property (nonatomic, copy) ALTAnisetteData *anisetteData;

- (instancetype)initWithDSID:(NSString *)dsid authToken:(NSString *)authToken anisetteData:(ALTAnisetteData *)anisetteData;

@end

NS_ASSUME_NONNULL_END
