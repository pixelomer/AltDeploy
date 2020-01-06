//
//  ALTAppleAPI.m
//  AltSign
//
//  Created by Riley Testut on 5/22/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAppleAPI_Private.h"
#import "ALTAppleAPISession.h"

#import "ALTAnisetteData.h"

#import "ALTModel+Internal.h"

#import <AltSign/NSError+ALTErrors.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const ALTAuthenticationProtocolVersion = @"A1234";
NSString *const ALTProtocolVersion = @"QH65B2";
NSString *const ALTAppIDKey = @"ba2ec180e6ca6e6c6a542255453b24d6e6e5b2be0cc48bc1b0d8ad64cfe0228f";
NSString *const ALTClientID = @"XABBG36SBA";

NS_ASSUME_NONNULL_END

@implementation ALTAppleAPI

+ (instancetype)sharedAPI
{
    static ALTAppleAPI *_appleAPI = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appleAPI = [[self alloc] init];
    });
    
    return _appleAPI;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        _dateFormatter = [[NSISO8601DateFormatter alloc] init];
        
        _baseURL = [[NSURL URLWithString:[NSString stringWithFormat:@"https://developerservices2.apple.com/services/%@/", ALTProtocolVersion]] copy];
        _servicesBaseURL = [[NSURL URLWithString:@"https://developerservices2.apple.com/services/v1/"] copy];
    }
    
    return self;
}

#pragma mark - Teams -

- (void)fetchTeamsForAccount:(ALTAccount *)account session:(ALTAppleAPISession *)session completionHandler:(void (^)(NSArray<ALTTeam *> *teams, NSError *error))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"listTeams.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:nil session:session team:nil completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        NSArray *teams = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSArray *array = responseDictionary[@"teams"];
            if (array == nil)
            {
                return nil;
            }
            
            NSMutableArray *teams = [NSMutableArray array];
            for (NSDictionary *dictionary in array)
            {
                ALTTeam *team = [[ALTTeam alloc] initWithAccount:account responseDictionary:dictionary];
                if (team == nil)
                {
                    return nil;
                }
                
                [teams addObject:team];
            }
            return teams;
        } resultCodeHandler:nil error:&error];
        
        if (teams != nil && teams.count == 0)
        {
            completionHandler(nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorNoTeams userInfo:nil]);
        }
        else
        {
            completionHandler(teams, error);
        }        
    }];
}

#pragma mark - Devices -

- (void)fetchDevicesForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(NSArray<ALTDevice *> * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/listDevices.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:nil session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        NSArray *devices = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSArray *array = responseDictionary[@"devices"];
            if (array == nil)
            {
                return nil;
            }
            
            NSMutableArray *devices = [NSMutableArray array];
            for (NSDictionary *dictionary in array)
            {
                ALTDevice *device = [[ALTDevice alloc] initWithResponseDictionary:dictionary];
                if (device == nil)
                {
                    return nil;
                }
                
                [devices addObject:device];
            }
            return devices;
        } resultCodeHandler:nil error:&error];
        
        completionHandler(devices, error);
    }];
}

- (void)registerDeviceWithName:(NSString *)name identifier:(NSString *)identifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTDevice * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/addDevice.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"deviceNumber": identifier, @"name": name} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        ALTDevice *device = [self processResponse:responseDictionary parseHandler:^id () {
            NSDictionary *dictionary = responseDictionary[@"device"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTDevice *device = [[ALTDevice alloc] initWithResponseDictionary:dictionary];
            return device;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 35:
                    if ([[[responseDictionary objectForKey:@"userString"] lowercaseString] containsString:@"already exists"])
                    {
                        return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorDeviceAlreadyRegistered userInfo:nil];
                    }
                    else
                    {
                        return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidDeviceID userInfo:nil];
                    }
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(device, error);
    }];
}

#pragma mark - Certificates -

- (void)fetchCertificatesForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(NSArray<ALTCertificate *> * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"certificates" relativeToURL:self.servicesBaseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    [self sendServicesRequest:request additionalParameters:@{@"filter[certificateType]": @"IOS_DEVELOPMENT"} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        NSArray *certificates = [self processResponse:responseDictionary parseHandler:^id {
            NSArray *array = responseDictionary[@"data"];
            if (array == nil)
            {
                return nil;
            }
            
            NSMutableArray *certificates = [NSMutableArray array];
            for (NSDictionary *dictionary in array)
            {
                ALTCertificate *certificate = [[ALTCertificate alloc] initWithResponseDictionary:dictionary];
                if (certificate == nil)
                {
                    return nil;
                }
                
                [certificates addObject:certificate];
            }
            return certificates;
        } resultCodeHandler:nil error:&error];
        
        completionHandler(certificates, error);
    }];
}

- (void)addCertificateWithMachineName:(NSString *)machineName toTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTCertificate * _Nullable, NSError * _Nullable))completionHandler
{
    ALTCertificateRequest *request = [[ALTCertificateRequest alloc] init];
    if (request == nil)
    {
        NSError *error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidCertificateRequest userInfo:nil];
        completionHandler(nil, error);
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:@"ios/submitDevelopmentCSR.action" relativeToURL:self.baseURL];
    NSString *encodedCSR = [[NSString alloc] initWithData:request.data encoding:NSUTF8StringEncoding];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"csrContent": encodedCSR,
                                                        @"machineId": [[NSUUID UUID] UUIDString],
                                                        @"machineName": machineName}
                     session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
                         if (responseDictionary == nil)
                         {
                             completionHandler(nil, requestError);
                             return;
                         }
                         
                         NSError *error = nil;
                         ALTCertificate *certificate = [self processResponse:responseDictionary parseHandler:^id _Nullable{
                             NSDictionary *dictionary = responseDictionary[@"certRequest"];
                             if (dictionary == nil)
                             {
                                 return nil;
                             }
                             
                             ALTCertificate *certificate = [[ALTCertificate alloc] initWithResponseDictionary:dictionary];
                             certificate.privateKey = request.privateKey;
                             return certificate;
                         } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
                             switch (resultCode)
                             {
                                 case 3250:
                                     return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidCertificateRequest userInfo:nil];
                                     
                                 default: return nil;
                             }
                         } error:&error];
                         
                         completionHandler(certificate, error);
                     }];
}

- (void)revokeCertificate:(ALTCertificate *)certificate forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"certificates/%@", certificate.identifier] relativeToURL:self.servicesBaseURL];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    
    [self sendServicesRequest:request additionalParameters:nil session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(NO, requestError);
            return;
        }
        
        NSError *error = nil;
        id result = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            return responseDictionary;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 7252: return nil;
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorCertificateDoesNotExist userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(result != nil, error);
    }];
}

#pragma mark - App IDs -

- (void)fetchAppIDsForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(NSArray<ALTAppID *> * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/listAppIds.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:nil session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        NSArray *appIDs = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSArray *array = responseDictionary[@"appIds"];
            if (array == nil)
            {
                return nil;
            }
            
            NSMutableArray *appIDs = [NSMutableArray array];
            for (NSDictionary *dictionary in array)
            {
                ALTAppID *appID = [[ALTAppID alloc] initWithResponseDictionary:dictionary];
                if (appID == nil)
                {
                    return nil;
                }
                
                [appIDs addObject:appID];
            }
            return appIDs;
        } resultCodeHandler:nil error:&error];
        
        completionHandler(appIDs, error);
    }];
}

- (void)addAppIDWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session
       completionHandler:(void (^)(ALTAppID *_Nullable appID, NSError *_Nullable error))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/addAppId.action" relativeToURL:self.baseURL];
    
    NSMutableCharacterSet *allowedCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowedCharacters formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSString *sanitizedName = [name stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:nil];
    sanitizedName = [[sanitizedName componentsSeparatedByCharactersInSet:[allowedCharacters invertedSet]] componentsJoinedByString:@""];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"identifier": bundleIdentifier, @"name": sanitizedName} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        ALTAppID *appID = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSDictionary *dictionary = responseDictionary[@"appId"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTAppID *appID = [[ALTAppID alloc] initWithResponseDictionary:dictionary];
            return appID;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 35:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidAppIDName userInfo:nil];
                    
                case 9401:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorBundleIdentifierUnavailable userInfo:nil];
                    
                case 9412:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidBundleIdentifier userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(appID, error);
    }];
}

- (void)updateAppID:(ALTAppID *)appID team:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTAppID * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/updateAppId.action" relativeToURL:self.baseURL];
    
    NSMutableDictionary *parameters = [@{@"appIdId": appID.identifier} mutableCopy];
    
    for (ALTFeature feature in appID.features)
    {
        parameters[feature] = appID.features[feature];
    }
    
    [self sendRequestWithURL:URL additionalParameters:parameters
                     session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        ALTAppID *appID = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSDictionary *dictionary = responseDictionary[@"appId"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTAppID *appID = [[ALTAppID alloc] initWithResponseDictionary:dictionary];
            return appID;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 35:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidAppIDName userInfo:nil];
                    
                case 9100:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAppIDDoesNotExist userInfo:nil];
                    
                case 9412:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidBundleIdentifier userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(appID, error);
    }];
}

- (void)deleteAppID:(ALTAppID *)appID forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/deleteAppId.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"appIdId": appID.identifier} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(NO, requestError);
            return;
        }
        
        NSError *error = nil;
        id value = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSNumber *result = responseDictionary[@"resultCode"];
            return [result integerValue] == 0 ? result : nil;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 9100:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAppIDDoesNotExist userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(value != nil, error);
    }];
}

#pragma mark - App Groups -

- (void)fetchAppGroupsForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(NSArray<ALTAppGroup *> *_Nullable appIDs, NSError *_Nullable error))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/listApplicationGroups.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:nil session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        NSArray *groups = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSArray *array = responseDictionary[@"applicationGroupList"];
            if (array == nil)
            {
                return nil;
            }
            
            NSMutableArray *groups = [NSMutableArray array];
            for (NSDictionary *dictionary in array)
            {
                ALTAppGroup *group = [[ALTAppGroup alloc] initWithResponseDictionary:dictionary];
                if (group == nil)
                {
                    return nil;
                }
                
                [groups addObject:group];
            }
            return groups;
        } resultCodeHandler:nil error:&error];
        
        completionHandler(groups, error);
    }];
}

- (void)addAppGroupWithName:(NSString *)name groupIdentifier:(NSString *)groupIdentifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTAppGroup * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/addApplicationGroup.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"identifier": groupIdentifier, @"name": name} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        ALTAppGroup *group = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSDictionary *dictionary = responseDictionary[@"applicationGroup"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTAppGroup *group = [[ALTAppGroup alloc] initWithResponseDictionary:dictionary];
            return group;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 35:
                    // Doesn't distinguish between different validation failures via resultCode unfortunately.
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidAppGroup userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(group, error);
    }];
}

- (void)addAppID:(ALTAppID *)appID toGroup:(ALTAppGroup *)group team:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/assignApplicationGroupToAppId.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"appIdId": appID.identifier, @"applicationGroups": group.identifier}
                     session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(NO, requestError);
            return;
        }
        
        NSError *error = nil;
        id value = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSNumber *result = responseDictionary[@"resultCode"];
            return [result integerValue] == 0 ? result : nil;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 9115:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAppIDDoesNotExist userInfo:nil];
                    
                case 35:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAppGroupDoesNotExist userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(value != nil, error);
    }];
}

#pragma mark - Provisioning Profiles -

- (void)fetchProvisioningProfileForAppID:(ALTAppID *)appID team:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTProvisioningProfile * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/downloadTeamProvisioningProfile.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"appIdId": appID.identifier} session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSError *error = nil;
        ALTProvisioningProfile *provisioningProfile = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSDictionary *dictionary = responseDictionary[@"provisioningProfile"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTProvisioningProfile *provisioningProfile = [[ALTProvisioningProfile alloc] initWithResponseDictionary:dictionary];
            return provisioningProfile;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 8201:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAppIDDoesNotExist userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(provisioningProfile, error);
    }];
}

- (void)deleteProvisioningProfile:(ALTProvisioningProfile *)provisioningProfile forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"ios/deleteProvisioningProfile.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:@{@"provisioningProfileId": provisioningProfile.identifier,
                                                        @"teamId": team.identifier}
                     session:session team:team completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(NO, requestError);
            return;
        }
        
        NSError *error = nil;
        id value = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSNumber *result = responseDictionary[@"resultCode"];
            return [result integerValue] == 0 ? result : nil;
        } resultCodeHandler:^NSError * _Nullable(NSInteger resultCode) {
            switch (resultCode)
            {
                case 35:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidProvisioningProfileIdentifier userInfo:nil];
                    
                case 8101:
                    return [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorProvisioningProfileDoesNotExist userInfo:nil];
                    
                default: return nil;
            }
        } error:&error];
        
        completionHandler(value != nil, error);
    }];
}

#pragma mark - Requests -

- (void)sendRequestWithURL:(NSURL *)requestURL additionalParameters:(nullable NSDictionary *)additionalParameters session:(ALTAppleAPISession *)session team:(nullable ALTTeam *)team completionHandler:(void (^)(NSDictionary *responseDictionary, NSError *error))completionHandler
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [@{
                                                                 @"clientId": ALTClientID,
                                                                 @"protocolVersion": ALTProtocolVersion,
                                                                 @"requestId": [[[NSUUID UUID] UUIDString] uppercaseString],
                                                                 } mutableCopy];
    
    if (team != nil)
    {
        parameters[@"teamId"] = team.identifier;
    }
    
    [additionalParameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        parameters[key] = value;
    }];
    
    NSError *serializationError = nil;
    NSData *bodyData = [NSPropertyListSerialization dataWithPropertyList:parameters format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializationError];
    if (bodyData == nil)
    {
        NSError *error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidParameters userInfo:@{NSUnderlyingErrorKey: serializationError}];
        completionHandler(nil, error);
        return;
    }
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?clientId=%@", requestURL.absoluteString, ALTClientID]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"Xcode",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-Apple-I-Identity-Id": session.dsid,
        @"X-Apple-GS-Token": session.authToken,
        @"X-Apple-I-MD-M": session.anisetteData.machineID,
        @"X-Apple-I-MD": session.anisetteData.oneTimePassword,
        @"X-Apple-I-MD-LU": session.anisetteData.localUserID,
        @"X-Apple-I-MD-RINFO": [@(session.anisetteData.routingInfo) description],
        @"X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
        @"X-MMe-Client-Info": session.anisetteData.deviceDescription,
        @"X-Apple-I-Client-Time": [self.dateFormatter stringFromDate:session.anisetteData.date],
        @"X-Apple-Locale": session.anisetteData.locale.localeIdentifier,
        @"X-Apple-I-Locale": session.anisetteData.locale.localeIdentifier,
        @"X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation
    };
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data == nil)
        {
            completionHandler(nil, error);
            return;
        }
        
        NSError *parseError = nil;
        NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
        
        if (responseDictionary == nil)
        {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSUnderlyingErrorKey: parseError}];
            completionHandler(nil, error);
            return;
        }
        
        completionHandler(responseDictionary, nil);
    }];
    
    [dataTask resume];
}

- (void)sendServicesRequest:(NSURLRequest *)originalRequest additionalParameters:(nullable NSDictionary *)additionalParameters session:(ALTAppleAPISession *)session team:(ALTTeam *)team completionHandler:(void (^)(NSDictionary *responseDictionary, NSError *error))completionHandler
{
    NSMutableURLRequest *request = [originalRequest mutableCopy];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [@[[NSURLQueryItem queryItemWithName:@"teamId" value:team.identifier]] mutableCopy];
    [additionalParameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:key value:value]];
    }];
    
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.queryItems = queryItems;
    
    NSString *queryString = components.query ?: @"";
    
    NSError *serializationError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:@{@"urlEncodedQueryParams": queryString} options:0 error:&serializationError];
    if (bodyData == nil)
    {
        NSError *error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidParameters userInfo:@{NSUnderlyingErrorKey: serializationError}];
        completionHandler(nil, error);
        return;
    }
        
    request.HTTPBody = bodyData;
    
    NSString *HTTPMethodOverride = request.HTTPMethod;
    request.HTTPMethod = @"POST";
    
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
        @"Content-Type": @"application/vnd.api+json",
        @"User-Agent": @"Xcode",
        @"Accept": @"application/vnd.api+json",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-HTTP-Method-Override": HTTPMethodOverride,
        @"X-Apple-I-Identity-Id": session.dsid,
        @"X-Apple-GS-Token": session.authToken,
        @"X-Apple-I-MD-M": session.anisetteData.machineID,
        @"X-Apple-I-MD": session.anisetteData.oneTimePassword,
        @"X-Apple-I-MD-LU": session.anisetteData.localUserID,
        @"X-Apple-I-MD-RINFO": [@(session.anisetteData.routingInfo) description],
        @"X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
        @"X-MMe-Client-Info": session.anisetteData.deviceDescription,
        @"X-Apple-I-Client-Time": [self.dateFormatter stringFromDate:session.anisetteData.date],
        @"X-Apple-Locale": session.anisetteData.locale.localeIdentifier,
        @"X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation
    };
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data == nil)
        {
            completionHandler(nil, error);
            return;
        }
        
        NSDictionary *responseDictionary = nil;
        
        if (data.length == 0)
        {
            responseDictionary = @{};
        }
        else
        {
            NSError *parseError = nil;
            responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            if (responseDictionary == nil)
            {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSUnderlyingErrorKey: parseError}];
                completionHandler(nil, error);
                return;
            }
        }        
        
        completionHandler(responseDictionary, nil);
    }];
    
    [dataTask resume];
}

- (nullable id)processResponse:(NSDictionary *)responseDictionary
                         parseHandler:(id _Nullable (^_Nullable)(void))parseHandler
                    resultCodeHandler:(NSError *_Nullable (^_Nullable)(NSInteger resultCode))resultCodeHandler
                         error:(NSError **)error
{
    if (parseHandler != nil)
    {
        id value = parseHandler();
        if (value != nil)
        {
            return value;
        }
    }
    
    id result = responseDictionary[@"resultCode"];
    if (result == nil)
    {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
        return nil;
    }
    
    NSInteger resultCode = [result integerValue]; // Works wether result is NSNumber or NSString.
    if (resultCode == 0)
    {
        return nil;
    }
    else
    {
        NSError *tempError = nil;
        if (resultCodeHandler)
        {
            tempError = resultCodeHandler(resultCode);
        }
        
        if (tempError == nil)
        {
            NSString *errorDescription = [responseDictionary objectForKey:@"userString"] ?: [responseDictionary objectForKey:@"resultString"];
            NSString *localizedDescription = [NSString stringWithFormat:@"%@ (%@)", errorDescription, @(resultCode)];
            
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = localizedDescription;
            tempError = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorUnknown userInfo:userInfo];
        }
        
        *error = tempError;
        
        return nil;
    }
}

@end
