//
//  ALTDevice.m
//  AltSign
//
//  Created by Riley Testut on 5/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTDevice.h"

@implementation ALTDevice

- (instancetype)initWithName:(NSString *)name identifier:(NSString *)identifier
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _identifier = [identifier copy];
    }
    
    return self;
}

- (nullable instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    NSString *name = responseDictionary[@"name"];
    NSString *identifier = responseDictionary[@"deviceNumber"];
    
    if (name == nil || identifier == nil)
    {
        return nil;
    }
    
    self = [self initWithName:name identifier:identifier];
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@, UDID: %@>", NSStringFromClass([self class]), self, self.name, self.identifier];
}

- (BOOL)isEqual:(id)object
{
    ALTDevice *device = (ALTDevice *)object;
    if (![device isKindOfClass:[ALTDevice class]])
    {
        return NO;
    }
    
    BOOL isEqual = [self.identifier isEqualToString:device.identifier];
    return isEqual;
}

- (NSUInteger)hash
{
    return self.identifier.hash;
}

@end
