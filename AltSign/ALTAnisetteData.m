//
//  ALTAnisetteData.m
//  AltSign
//
//  Created by Riley Testut on 11/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAnisetteData.h"

@implementation ALTAnisetteData

- (instancetype)initWithMachineID:(NSString *)machineID
                  oneTimePassword:(NSString *)oneTimePassword
                      localUserID:(NSString *)localUserID
                      routingInfo:(unsigned long long)routingInfo
           deviceUniqueIdentifier:(NSString *)deviceUniqueIdentifier
               deviceSerialNumber:(NSString *)deviceSerialNumber
                deviceDescription:(NSString *)deviceDescription
                             date:(NSDate *)date
                           locale:(NSLocale *)locale
                         timeZone:(NSTimeZone *)timeZone
{
    self = [super init];
    if (self)
    {
        _machineID = [machineID copy];
        _oneTimePassword = [oneTimePassword copy];
        _localUserID = [localUserID copy];
        _routingInfo = routingInfo;
        
        _deviceUniqueIdentifier = [deviceUniqueIdentifier copy];
        _deviceSerialNumber = [deviceSerialNumber copy];
        _deviceDescription = [deviceDescription copy];
        
        _date = [date copy];
        _locale = [locale copy];
        _timeZone = [timeZone copy];
    }
    
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"Machine ID: %@\nOne-Time Password: %@\nLocal User ID: %@\nRouting Info: %@\nDevice UDID: %@\nDevice Serial Number: %@\nDevice Description: %@\nDate: %@\nLocale: %@\nTime Zone: %@",
            self.machineID, self.oneTimePassword, self.localUserID, @(self.routingInfo), self.deviceUniqueIdentifier, self.deviceSerialNumber, self.deviceDescription, self.date, self.locale.localeIdentifier, self.timeZone];
}

- (BOOL)isEqual:(id)object
{
    ALTAnisetteData *anisetteData = (ALTAnisetteData *)object;
    if (![anisetteData isKindOfClass:[ALTAnisetteData class]])
    {
        return NO;
    }
    
    BOOL isEqual = ([self.machineID isEqualToString:anisetteData.machineID] &&
                    [self.oneTimePassword isEqualToString:anisetteData.oneTimePassword] &&
                    [self.localUserID isEqualToString:anisetteData.localUserID] &&
                    [@(self.routingInfo) isEqualToNumber:@(anisetteData.routingInfo)] &&
                    [self.deviceUniqueIdentifier isEqualToString:anisetteData.deviceUniqueIdentifier] &&
                    [self.deviceSerialNumber isEqualToString:anisetteData.deviceSerialNumber] &&
                    [self.deviceDescription isEqualToString:anisetteData.deviceDescription] &&
                    [self.date isEqualToDate:anisetteData.date] &&
                    [self.locale isEqual:anisetteData.locale] &&
                    [self.timeZone isEqualToTimeZone:anisetteData.timeZone]);
    return isEqual;
}

- (NSUInteger)hash
{
    return (self.machineID.hash ^
            self.oneTimePassword.hash ^
            self.localUserID.hash ^
            @(self.routingInfo).hash ^
            self.deviceUniqueIdentifier.hash ^
            self.deviceSerialNumber.hash ^
            self.deviceDescription.hash ^
            self.date.hash ^
            self.locale.hash ^
            self.timeZone.hash);
    ;
}

#pragma mark - <NSCopying> -

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    ALTAnisetteData *copy = [[ALTAnisetteData alloc] initWithMachineID:self.machineID
                                                       oneTimePassword:self.oneTimePassword
                                                           localUserID:self.localUserID
                                                           routingInfo:self.routingInfo
                                                deviceUniqueIdentifier:self.deviceUniqueIdentifier
                                                    deviceSerialNumber:self.deviceSerialNumber
                                                     deviceDescription:self.deviceDescription
                                                                  date:self.date
                                                                locale:self.locale
                                                              timeZone:self.timeZone];
    
    return copy;
}

#pragma mark - <NSSecureCoding> -

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSString *machineID = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(machineID))];
    NSString *oneTimePassword = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(oneTimePassword))];
    NSString *localUserID = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(localUserID))];
    NSNumber *routingInfo = [decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(routingInfo))];
    
    NSString *deviceUniqueIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(deviceUniqueIdentifier))];
    NSString *deviceSerialNumber = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(deviceSerialNumber))];
    NSString *deviceDescription = [decoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(deviceDescription))];
    
    NSDate *date = [decoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(date))];
    NSLocale *locale = [decoder decodeObjectOfClass:[NSLocale class] forKey:NSStringFromSelector(@selector(locale))];
    NSTimeZone *timeZone = [decoder decodeObjectOfClass:[NSTimeZone class] forKey:NSStringFromSelector(@selector(timeZone))];
    
    self = [self initWithMachineID:machineID
           oneTimePassword:oneTimePassword
               localUserID:localUserID
               routingInfo:[routingInfo unsignedLongLongValue]
    deviceUniqueIdentifier:deviceUniqueIdentifier
        deviceSerialNumber:deviceSerialNumber
                 deviceDescription:deviceDescription
                      date:date
                    locale:locale
                  timeZone:timeZone];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.machineID forKey:NSStringFromSelector(@selector(machineID))];
    [encoder encodeObject:self.oneTimePassword forKey:NSStringFromSelector(@selector(oneTimePassword))];
    [encoder encodeObject:self.localUserID forKey:NSStringFromSelector(@selector(localUserID))];
    [encoder encodeObject:@(self.routingInfo) forKey:NSStringFromSelector(@selector(routingInfo))];
    
    [encoder encodeObject:self.deviceUniqueIdentifier forKey:NSStringFromSelector(@selector(deviceUniqueIdentifier))];
    [encoder encodeObject:self.deviceSerialNumber forKey:NSStringFromSelector(@selector(deviceSerialNumber))];
    [encoder encodeObject:self.deviceDescription forKey:NSStringFromSelector(@selector(deviceDescription))];
    
    [encoder encodeObject:self.date forKey:NSStringFromSelector(@selector(date))];
    [encoder encodeObject:self.locale forKey:NSStringFromSelector(@selector(locale))];
    [encoder encodeObject:self.timeZone forKey:NSStringFromSelector(@selector(timeZone))];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark - JSON -

- (instancetype)initWithJSON:(NSDictionary<NSString *,NSString *> *)json
{
    NSString *machineID = json[@"machineID"];
    NSString *oneTimePassword = json[@"oneTimePassword"];
    NSString *localUserID = json[@"localUserID"];
    NSString *routingInfo = json[@"routingInfo"];
    NSString *deviceUniqueIdentifier = json[@"deviceUniqueIdentifier"];
    NSString *deviceSerialNumber = json[@"deviceSerialNumber"];
    NSString *deviceDescription = json[@"deviceDescription"];
    NSString *dateString = json[@"date"];
    NSString *localeIdentifier = json[@"locale"];
    NSString *timeZoneIdentifier = json[@"timeZone"];
    
    if (machineID == nil || oneTimePassword == nil || localUserID == nil || routingInfo == nil || deviceUniqueIdentifier == nil ||
        deviceSerialNumber == nil || deviceDescription == nil || dateString == nil || localeIdentifier == nil || timeZoneIdentifier == nil)
    {
        return nil;
    }
    
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    NSDate *date = [dateFormatter dateFromString:dateString];
    
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:localeIdentifier];
    
    // There is not a perfect mapping between NSTimeZone's and their identifiers, so it's possible timeZoneWithAbbreviation: will return nil.
    // In this case, we'll default to the local time zone since that's most likely correct, and if not it shouldn't matter regardless.
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:timeZoneIdentifier] ?: [NSTimeZone localTimeZone];
    
    self = [self initWithMachineID:machineID
                   oneTimePassword:oneTimePassword
                       localUserID:localUserID
                       routingInfo:[routingInfo longLongValue]
            deviceUniqueIdentifier:deviceUniqueIdentifier
                deviceSerialNumber:deviceSerialNumber
                 deviceDescription:deviceDescription
                              date:date
                            locale:locale
                          timeZone:timeZone];
    return self;
}

- (NSDictionary<NSString *,NSString *> *)json
{
    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    
    NSDictionary<NSString *,NSString *> *json = @{
        @"machineID": self.machineID,
        @"oneTimePassword": self.oneTimePassword,
        @"localUserID": self.localUserID,
        @"routingInfo": [@(self.routingInfo) description],
        @"deviceUniqueIdentifier": self.deviceUniqueIdentifier,
        @"deviceSerialNumber": self.deviceSerialNumber,
        @"deviceDescription": self.deviceDescription,
        @"date": [dateFormatter stringFromDate:self.date],
        @"locale": self.locale.localeIdentifier,
        
        // NSTimeZone.abbreviation may be nil, so provide defaults.
        @"timeZone": self.timeZone.abbreviation ?: NSTimeZone.localTimeZone.abbreviation ?: @"PST"
    };
    
    return json;
}

@end
