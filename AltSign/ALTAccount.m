//
//  ALTAccount.m
//  AltSign
//
//  Created by Riley Testut on 5/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAccount.h"

@implementation ALTAccount

- (nullable instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    self = [super init];
    if (self)
    {
        NSString *appleID = responseDictionary[@"email"];
        NSNumber *identifier = responseDictionary[@"personId"];
        NSString *firstName = responseDictionary[@"firstName"] ?: responseDictionary[@"dsFirstName"];
        NSString *lastName = responseDictionary[@"lastName"] ?: responseDictionary[@"dsLastName"];
        
        if (appleID == nil || identifier == nil || firstName == nil || lastName == nil)
        {
            return nil;
        }
        
        _appleID = [appleID copy];
        _identifier = [identifier.description copy];
        _firstName = [firstName copy];
        _lastName = [lastName copy];
    }
    
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@, Apple ID: %@>", NSStringFromClass([self class]), self, self.name, self.appleID];
}

- (BOOL)isEqual:(id)object
{
    ALTAccount *account = (ALTAccount *)object;
    if (![account isKindOfClass:[ALTAccount class]])
    {
        return NO;
    }
    
    BOOL isEqual = [self.identifier isEqualToString:account.identifier];
    return isEqual;
}

- (NSUInteger)hash
{
    return self.identifier.hash;
}

#pragma mark - Getters/Setters -

- (NSString *)name
{
    NSPersonNameComponents *components = [[NSPersonNameComponents alloc] init];
    components.givenName = self.firstName;
    components.familyName = self.lastName;
    
    NSString *name = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:components style:NSPersonNameComponentsFormatterStyleDefault options:0];
    return name;
}

@end
