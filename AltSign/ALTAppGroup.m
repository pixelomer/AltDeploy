//
//  ALTAppGroup.m
//  AltSign
//
//  Created by Riley Testut on 6/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAppGroup.h"

@implementation ALTAppGroup

- (nullable instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    self = [super init];
    if (self)
    {
        NSString *name = responseDictionary[@"name"];
        NSString *identifier = responseDictionary[@"applicationGroup"];
        NSString *groupIdentifier = responseDictionary[@"identifier"];
        
        if (name == nil || identifier == nil || groupIdentifier == nil)
        {
            return nil;
        }
        
        _name = [name copy];
        _identifier = [identifier copy];
        _groupIdentifier = [groupIdentifier copy];
    }
    
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, ID: %@, GroupID: %@>", NSStringFromClass([self class]), self, self.identifier, self.groupIdentifier];
}

- (BOOL)isEqual:(id)object
{
    ALTAppGroup *group = (ALTAppGroup *)object;
    if (![group isKindOfClass:[ALTAppGroup class]])
    {
        return NO;
    }
    
    BOOL isEqual = ([self.identifier isEqualToString:group.identifier] && [self.groupIdentifier isEqualToString:group.groupIdentifier]);
    return isEqual;
}

- (NSUInteger)hash
{
    return self.identifier.hash ^ self.groupIdentifier.hash;
}

@end
