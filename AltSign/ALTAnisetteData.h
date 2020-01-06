//
//  ALTAnisetteData.h
//  AltSign
//
//  Created by Riley Testut on 11/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTAnisetteData : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, copy) NSString *machineID;
@property (nonatomic, copy) NSString *oneTimePassword;
@property (nonatomic, copy) NSString *localUserID;
@property (nonatomic) unsigned long long routingInfo;

@property (nonatomic, copy) NSString *deviceUniqueIdentifier;
@property (nonatomic, copy) NSString *deviceSerialNumber;
@property (nonatomic, copy) NSString *deviceDescription;

@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSLocale *locale;
@property (nonatomic, copy) NSTimeZone *timeZone;

- (instancetype)initWithMachineID:(NSString *)machineID
                  oneTimePassword:(NSString *)oneTimePassword
                      localUserID:(NSString *)localUserID
                      routingInfo:(unsigned long long)routingInfo
           deviceUniqueIdentifier:(NSString *)deviceUniqueIdentifier
               deviceSerialNumber:(NSString *)deviceSerialNumber
                deviceDescription:(NSString *)deviceDescription
                             date:(NSDate *)date
                           locale:(NSLocale *)locale
                         timeZone:(NSTimeZone *)timeZone;

- (nullable instancetype)initWithJSON:(NSDictionary<NSString *, NSString *> *)json;
- (NSDictionary<NSString *, NSString *> *)json;

@end

NS_ASSUME_NONNULL_END
