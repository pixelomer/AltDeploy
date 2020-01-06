//
//  ALTSigner.m
//  AltSign
//
//  Created by Riley Testut on 5/22/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTSigner.h"
#import "ALTAppID.h"
#import "ALTTeam.h"
#import "ALTCertificate.h"
#import "ALTProvisioningProfile.h"
#import "ALTApplication.h"

#import "NSFileManager+Apps.h"
#import "NSError+ALTErrors.h"

#include "ldid.hpp"

#include <string>

#include <openssl/pkcs12.h>
#include <openssl/pem.h>

std::string CertificatesContent(ALTCertificate *altCertificate)
{
    NSURL *pemURL = [NSBundle.mainBundle URLForResource:@"apple" withExtension:@"pem"];
    NSLog(@"pem: %@", pemURL);
    
    NSData *altCertificateP12Data = [altCertificate p12Data];
    
    BIO *inputP12Buffer = BIO_new(BIO_s_mem());
    BIO_write(inputP12Buffer, altCertificateP12Data.bytes, (int)altCertificateP12Data.length);
    
    auto inputP12 = d2i_PKCS12_bio(inputP12Buffer, NULL);
    
    // Extract key + certificate from .p12.
    EVP_PKEY *key;
    X509 *certificate;
    PKCS12_parse(inputP12, "", &key, &certificate, NULL);
    
    // Open .pem from file.
    auto pemFile = fopen(pemURL.path.fileSystemRepresentation, "r");
    
    // Extract certificates from .pem.
    auto *certificates = sk_X509_new(NULL);
    while (auto certificate = PEM_read_X509(pemFile, NULL, NULL, NULL))
    {
        sk_X509_push(certificates, certificate);
    }
    
    // Create new .p12 in memory with private key and certificate chain.
    char emptyString[] = "";
    auto outputP12 = PKCS12_create(emptyString, emptyString, key, certificate, certificates, 0, 0, 0, 0, 0);
    
    BIO *outputP12Buffer = BIO_new(BIO_s_mem());
    i2d_PKCS12_bio(outputP12Buffer, outputP12);
    
    char *buffer = NULL;
    NSUInteger size = BIO_get_mem_data(outputP12Buffer, &buffer);
    
    NSData *p12Data = [NSData dataWithBytes:buffer length:size];
    
    // Free .p12 structures
    PKCS12_free(inputP12);
    PKCS12_free(outputP12);
    
    BIO_free(inputP12Buffer);
    BIO_free(outputP12Buffer);
    
    // Close files
    fclose(pemFile);
    
    std::string output((const char *)p12Data.bytes, (size_t)p12Data.length);
    return output;
}

@implementation ALTSigner

+ (void)load
{
    OpenSSL_add_all_algorithms();
}

- (instancetype)initWithTeam:(ALTTeam *)team certificate:(ALTCertificate *)certificate
{
    self = [super init];
    if (self)
    {
        _team = team;
        _certificate = certificate;
    }
    
    return self;
}

- (NSProgress *)signAppAtURL:(NSURL *)appURL provisioningProfiles:(NSArray<ALTProvisioningProfile *> *)profiles completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    NSProgress *progress = [NSProgress discreteProgressWithTotalUnitCount:1];
    
    NSURL *ipaURL = nil;
    NSURL *appBundleURL = nil;
    
    void (^finish)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        if (ipaURL != nil)
        {
            NSError *removeError = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:[ipaURL URLByDeletingLastPathComponent] error:&removeError])
            {
                NSLog(@"Failed to clean up after resigning. %@", removeError);
            }
        }
        
        completionHandler(success, error);
    };
    
    __block NSError *error = nil;
    
    if ([appURL.pathExtension.lowercaseString isEqualToString:@"ipa"])
    {
        ipaURL = appURL;
        
        NSURL *outputDirectoryURL = [[appURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[[NSUUID UUID] UUIDString] isDirectory:YES];
        if (![[NSFileManager defaultManager] createDirectoryAtURL:outputDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error])
        {
            finish(NO, error);
            return progress;
        }
        
        appBundleURL = [[NSFileManager defaultManager] unzipAppBundleAtURL:appURL toDirectory:outputDirectoryURL error:&error];
        if (appBundleURL == nil)
        {
            finish(NO, [NSError errorWithDomain:AltSignErrorDomain code:ALTErrorMissingAppBundle userInfo:@{NSUnderlyingErrorKey: error}]);
            return progress;
        }
    }
    else
    {
        appBundleURL = appURL;
    }
    
    NSBundle *appBundle = [NSBundle bundleWithURL:appBundleURL];
    if (appBundle == nil)
    {
        finish(NO, [NSError errorWithDomain:AltSignErrorDomain code:ALTErrorInvalidApp userInfo:nil]);
        return progress;
    }
    
    ALTApplication *application = [[ALTApplication alloc] initWithFileURL:appBundleURL];
    if (application == nil)
    {
        finish(NO, [NSError errorWithDomain:AltSignErrorDomain code:ALTErrorInvalidApp userInfo:nil]);
        return progress;
    }
    
    NSDirectoryEnumerator *countEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:appURL
                                                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                     options:0
                                                                                errorHandler:^BOOL(NSURL * _Nonnull url, NSError * _Nonnull error) {
                                                                                    if (error) {
                                                                                        NSLog(@"[Error] %@ (%@)", error, url);
                                                                                        return NO;
                                                                                    }
                                                                                    
                                                                                    return YES;
                                                                                }];
        
    NSInteger totalCount = 0;
    for (NSURL *__unused fileURL in countEnumerator)
    {
        NSNumber *isDirectory = nil;
        if (![fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil] || [isDirectory boolValue])
        {
            continue;
        }
        
        // Ignore CodeResources files.
        if ([[fileURL lastPathComponent] isEqualToString:@"CodeResources"])
        {
            continue;
        }
        
        totalCount++;
    }
    
    progress.totalUnitCount = totalCount;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableDictionary<NSURL *, NSString *> *entitlementsByFileURL = [NSMutableDictionary dictionary];
        
        ALTProvisioningProfile *(^profileForApp)(ALTApplication *) = ^ALTProvisioningProfile *(ALTApplication *app) {
            // Assume for now that apps don't have 100s of app extensions 🤷‍♂️
			for (ALTProvisioningProfile *profile in profiles)
            {
                if ([profile.bundleIdentifier isEqualToString:app.bundleIdentifier])
                {
                    return profile;
                }
            }
            
            return profiles.firstObject;
        };
        
        NSError * (^prepareApp)(ALTApplication *) = ^NSError *(ALTApplication *app) {
            ALTProvisioningProfile *profile = profileForApp(app);
            if (profile == nil)
            {
                return [NSError errorWithDomain:AltSignErrorDomain code:ALTErrorMissingProvisioningProfile userInfo:nil];
            }
            
            NSURL *profileURL = [app.fileURL URLByAppendingPathComponent:@"embedded.mobileprovision"];
            [profile.data writeToURL:profileURL atomically:YES];
            
            NSData *entitlementsData = [NSPropertyListSerialization dataWithPropertyList:profile.entitlements format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
            if (entitlementsData == nil)
            {
                return error;
            }
            
            NSString *entitlements = [[NSString alloc] initWithData:entitlementsData encoding:NSUTF8StringEncoding];
            entitlementsByFileURL[app.fileURL] = entitlements;
            
            return nil;
        };
        
        NSError *prepareError = prepareApp(application);
        if (prepareError != nil)
        {
            finish(NO, prepareError);
            return;
        }
        
        NSURL *pluginsURL = [appBundle builtInPlugInsURL];
        
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:pluginsURL
                                                                 includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
        
        for (NSURL *extensionURL in enumerator)
        {
            ALTApplication *appExtension = [[ALTApplication alloc] initWithFileURL:extensionURL];
            if (appExtension == nil)
            {
                prepareError = [NSError errorWithDomain:AltSignErrorDomain code:ALTErrorInvalidApp userInfo:nil];
                break;
            }
            
            NSError *error = prepareApp(appExtension);
            if (error != nil)
            {
                prepareError = error;
                break;
            }
        }
        
        if (prepareError != nil)
        {
            finish(NO, prepareError);
            return;
        }
        
        
        // Sign application
        ldid::DiskFolder appBundle(application.fileURL.fileSystemRepresentation);
        std::string key = CertificatesContent(self.certificate);
        
        ldid::Sign("", appBundle, key, "",
                   ldid::fun([&](const std::string &path, const std::string &binaryEntitlements) -> std::string {
            NSString *filename = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];
            
            NSURL *fileURL = nil;
            
            if (filename.length == 0)
            {
                fileURL = application.fileURL;
            }
            else
            {
                fileURL = [application.fileURL URLByAppendingPathComponent:filename isDirectory:YES];
            }
            
            NSString *entitlements = entitlementsByFileURL[fileURL];
            return entitlements.UTF8String;
        }),
                   ldid::fun([&](const std::string &string) {
            progress.completedUnitCount += 1;
        }),
                   ldid::fun([&](const double signingProgress) {
        }));
        
        
        // Dispatch after to allow time to finish signing binary.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (ipaURL != nil)
            {
                NSURL *resignedIPAURL = [[NSFileManager defaultManager] zipAppBundleAtURL:appBundleURL error:&error];
                
                if (![[NSFileManager defaultManager] replaceItemAtURL:ipaURL withItemAtURL:resignedIPAURL backupItemName:nil options:0 resultingItemURL:nil error:&error])
                {
                    finish(NO, error);
                }
            }
            
            finish(YES, nil);
        });
    });

    return progress;
}

@end
