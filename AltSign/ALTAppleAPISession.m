//
//  ALTAppleAPISession.m
//  AltSign
//
//  Created by Riley Testut on 11/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAppleAPISession.h"
#import "ALTAccount.h"
#import "ALTAnisetteData.h"

@implementation ALTAppleAPISession

- (instancetype)initWithDSID:(NSString *)dsid authToken:(NSString *)authToken anisetteData:(ALTAnisetteData *)anisetteData
{
    self = [super init];
    if (self)
    {
        _dsid = [dsid copy];
        _authToken = [authToken copy];
        _anisetteData = [anisetteData copy];
    }
    
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, DSID: %@, Auth Token: %@, Anisette Data: %@>", NSStringFromClass([self class]), self, self.dsid, self.authToken, self.anisetteData];
}

@end
