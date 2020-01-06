//
//  ALTAppleAPI.h
//  AltSign
//
//  Created by Riley Testut on 5/22/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ALTCapabilities.h"

@class ALTAppleAPISession;

@class ALTAccount;
@class ALTAnisetteData;
@class ALTTeam;
@class ALTDevice;
@class ALTCertificate;
@class ALTAppID;
@class ALTAppGroup;
@class ALTProvisioningProfile;

NS_ASSUME_NONNULL_BEGIN

@interface ALTAppleAPI : NSObject

@property (class, nonatomic, readonly) ALTAppleAPI *sharedAPI;

/* Teams */
- (void)fetchTeamsForAccount:(ALTAccount *)account session:(ALTAppleAPISession *)session
           completionHandler:(void (^)(NSArray<ALTTeam *> *_Nullable teams, NSError *_Nullable error))completionHandler;

/* Devices */
- (void)fetchDevicesForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
          completionHandler:(void (^)(NSArray<ALTDevice *> *_Nullable devices, NSError *_Nullable error))completionHandler;

- (void)registerDeviceWithName:(NSString *)name identifier:(NSString *)identifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session
             completionHandler:(void (^)(ALTDevice *_Nullable device, NSError *_Nullable error))completionHandler
NS_SWIFT_NAME(registerDevice(name:identifier:team:session:completionHandler:));

/* Certificates */
- (void)fetchCertificatesForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
               completionHandler:(void (^)(NSArray<ALTCertificate *> *_Nullable certificates, NSError *_Nullable error))completionHandler;

- (void)addCertificateWithMachineName:(NSString *)name toTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
                    completionHandler:(void (^)(ALTCertificate *_Nullable certificate, NSError *_Nullable error))completionHandler
NS_SWIFT_NAME(addCertificate(machineName:to:session:completionHandler:));

- (void)revokeCertificate:(ALTCertificate *)certificate forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
        completionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler
NS_SWIFT_NAME(revoke(_:for:session:completionHandler:));

/* App IDs */
- (void)fetchAppIDsForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
         completionHandler:(void (^)(NSArray<ALTAppID *> *_Nullable appIDs, NSError *_Nullable error))completionHandler;

- (void)addAppIDWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session
       completionHandler:(void (^)(ALTAppID *_Nullable appID, NSError *_Nullable error))completionHandler;

- (void)updateAppID:(ALTAppID *)appID team:(ALTTeam *)team session:(ALTAppleAPISession *)session
  completionHandler:(void (^)(ALTAppID * _Nullable appID, NSError * _Nullable error))completionHandler;

- (void)deleteAppID:(ALTAppID *)appID forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
  completionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler;

/* App Groups */
- (void)fetchAppGroupsForTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
            completionHandler:(void (^)(NSArray<ALTAppGroup *> *_Nullable groups, NSError *_Nullable error))completionHandler;

- (void)addAppGroupWithName:(NSString *)name groupIdentifier:(NSString *)groupIdentifier team:(ALTTeam *)team session:(ALTAppleAPISession *)session
       completionHandler:(void (^)(ALTAppGroup *_Nullable group, NSError *_Nullable error))completionHandler;

- (void)addAppID:(ALTAppID *)appID toGroup:(ALTAppGroup *)group team:(ALTTeam *)team session:(ALTAppleAPISession *)session
completionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler;

/* Provisioning Profiles */
- (void)fetchProvisioningProfileForAppID:(ALTAppID *)appID team:(ALTTeam *)team session:(ALTAppleAPISession *)session
                       completionHandler:(void (^)(ALTProvisioningProfile *_Nullable provisioningProfile, NSError *_Nullable error))completionHandler;

- (void)deleteProvisioningProfile:(ALTProvisioningProfile *)provisioningProfile forTeam:(ALTTeam *)team session:(ALTAppleAPISession *)session
  completionHandler:(void (^)(BOOL success, NSError *_Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
