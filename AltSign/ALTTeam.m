//
//  ALTTeam.m
//  AltSign
//
//  Created by Riley Testut on 5/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTTeam.h"

@implementation ALTTeam

- (instancetype)initWithName:(NSString *)name identifier:(NSString *)identifier type:(ALTTeamType)type account:(ALTAccount *)account
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _identifier = [identifier copy];
        _type = type;
        _account = account;
    }
    
    return self;
}

- (nullable instancetype)initWithAccount:(ALTAccount *)account responseDictionary:(NSDictionary *)responseDictionary
{
    NSString *name = responseDictionary[@"name"];
    NSString *identifier = responseDictionary[@"teamId"];
    NSString *teamType = responseDictionary[@"type"];
    
    if (name == nil || identifier == nil || teamType == nil)
    {
        return nil;
    }
    
    ALTTeamType type = ALTTeamTypeUnknown;
    
    if ([teamType isEqualToString:@"Company/Organization"])
    {
        type = ALTTeamTypeOrganization;
    }
    else if ([teamType isEqualToString:@"Individual"])
    {
        NSArray *memberships = responseDictionary[@"memberships"];
        
        NSDictionary *membership = memberships.firstObject;
        NSString *name = membership[@"name"];
        
        if (memberships.count == 1 && [name.lowercaseString containsString:@"free"])
        {
            type = ALTTeamTypeFree;
        }
        else
        {
            type = ALTTeamTypeIndividual;
        }
    }
    else
    {
        type = ALTTeamTypeUnknown;
    }
    
    self = [self initWithName:name identifier:identifier type:type account:account];
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@>", NSStringFromClass([self class]), self, self.name];
}

- (BOOL)isEqual:(id)object
{
    ALTTeam *team = (ALTTeam *)object;
    if (![team isKindOfClass:[ALTTeam class]])
    {
        return NO;
    }
    
    BOOL isEqual = [self.identifier isEqualToString:team.identifier];
    return isEqual;
}

- (NSUInteger)hash
{
    return self.identifier.hash;
}

@end
