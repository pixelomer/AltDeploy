//
//  ALTCapabilities.m
//  AltSign
//
//  Created by Riley Testut on 6/25/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTCapabilities.h"

// Entitlements
ALTEntitlement const ALTEntitlementApplicationIdentifier = @"application-identifier";
ALTEntitlement const ALTEntitlementKeychainAccessGroups = @"keychain-access-groups";
ALTEntitlement const ALTEntitlementAppGroups = @"com.apple.security.application-groups";
ALTEntitlement const ALTEntitlementGetTaskAllow = @"get-task-allow";
ALTEntitlement const ALTEntitlementTeamIdentifier = @"com.apple.developer.team-identifier";
ALTEntitlement const ALTEntitlementInterAppAudio = @"inter-app-audio";

// Features
ALTFeature const ALTFeatureGameCenter = @"gameCenter";
ALTFeature const ALTFeatureAppGroups = @"APG3427HIY";
ALTFeature const ALTFeatureInterAppAudio = @"IAD53UNK2F";

_Nullable ALTEntitlement ALTEntitlementForFeature(ALTFeature feature)
{
    if ([feature isEqualToString:ALTFeatureAppGroups])
    {
        return ALTEntitlementAppGroups;
    }
    else if ([feature isEqualToString:ALTFeatureInterAppAudio])
    {
        return ALTEntitlementInterAppAudio;
    }
    
    return nil;
}

_Nullable ALTFeature ALTFeatureForEntitlement(ALTEntitlement entitlement)
{
    if ([entitlement isEqualToString:ALTEntitlementAppGroups])
    {
        return ALTFeatureAppGroups;
    }
    else if ([entitlement isEqualToString:ALTEntitlementInterAppAudio])
    {
        return ALTFeatureInterAppAudio;
    }
    
    return nil;
}
