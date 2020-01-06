//
//  ALTAppID.m
//  AltSign
//
//  Created by Riley Testut on 5/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAppID.h"

@implementation ALTAppID

- (instancetype)initWithName:(NSString *)name identifier:(NSString *)identifier bundleIdentifier:(NSString *)bundleIdentifier features:(NSDictionary<ALTFeature, id> *)features
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _identifier = [identifier copy];
        _bundleIdentifier = [bundleIdentifier copy];
        _features = [features copy];
    }
    
    return self;
}

- (nullable instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    NSString *name = responseDictionary[@"name"];
    NSString *identifier = responseDictionary[@"appIdId"];
    NSString *bundleIdentifier = responseDictionary[@"identifier"];
    
    NSDictionary *allFeatures = responseDictionary[@"features"] ?: @{};
    NSArray *enabledFeatures = responseDictionary[@"enabledFeatures"] ?: @[];
    
    if (name == nil || identifier == nil || bundleIdentifier == nil)
    {
        return nil;
    }
    
    NSMutableDictionary *features = [NSMutableDictionary dictionary];
    for (ALTFeature feature in enabledFeatures)
    {
        id value = allFeatures[feature];
        features[feature] = value;
    }

    self = [self initWithName:name identifier:identifier bundleIdentifier:bundleIdentifier features:features];
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@, ID: %@, BundleID: %@>", NSStringFromClass([self class]), self, self.name, self.identifier, self.bundleIdentifier];
}

- (BOOL)isEqual:(id)object
{
    ALTAppID *appID = (ALTAppID *)object;
    if (![appID isKindOfClass:[ALTAppID class]])
    {
        return NO;
    }
    
    BOOL isEqual = ([self.identifier isEqualToString:appID.identifier] && [self.bundleIdentifier isEqualToString:appID.bundleIdentifier]);
    return isEqual;
}

- (NSUInteger)hash
{
    return self.identifier.hash ^ self.bundleIdentifier.hash;
}

#pragma mark - <NSCopying> -

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    ALTAppID *appID = [[ALTAppID alloc] initWithName:self.name identifier:self.identifier bundleIdentifier:self.bundleIdentifier features:self.features];
    return appID;
}

@end
