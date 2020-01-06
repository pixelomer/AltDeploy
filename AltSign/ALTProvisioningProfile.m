//
//  ALTProvisioningProfile.m
//  AltSign
//
//  Created by Riley Testut on 5/22/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTProvisioningProfile.h"
#import "ALTCertificate.h"

#define ASN1_SEQUENCE 0x30
#define ASN1_CONTAINER 0xA0
#define ASN1_OBJECT_IDENTIFIER 0x06
#define ASN1_OCTET_STRING 0x04

@implementation ALTProvisioningProfile

- (nullable instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    NSString *identifier = responseDictionary[@"provisioningProfileId"];
    if (identifier == nil)
    {
        return nil;
    }
    
    NSData *data = responseDictionary[@"encodedProfile"];
    if (data == nil)
    {
        return nil;
    }
    
    self = [self initWithData:data];
    _identifier = [identifier copy];
    
    return self;
}

- (nullable instancetype)initWithURL:(NSURL *)fileURL
{
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    if (data == nil)
    {
        return nil;
    }
    
    self = [self initWithData:data];
    return self;
}

- (nullable instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self)
    {
        NSDictionary *dictionary = [ALTProvisioningProfile dictionaryFromEncodedData:data];
        if (dictionary == nil)
        {
            return nil;
        }
        
        NSString *name = dictionary[@"Name"];
        NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:dictionary[@"UUID"]];
        
        NSString *teamIdentifier = [dictionary[@"TeamIdentifier"] firstObject];
        
        NSDate *creationDate = dictionary[@"CreationDate"];
        NSDate *expirationDate = dictionary[@"ExpirationDate"];
        
        NSDictionary<ALTEntitlement, id> *entitlements = dictionary[@"Entitlements"];
        NSArray<NSString *> *deviceIDs = dictionary[@"ProvisionedDevices"];
        
        if (name == nil || UUID == nil || teamIdentifier == nil || creationDate == nil || expirationDate == nil || entitlements == nil || deviceIDs == nil)
        {
            return nil;
        }
        
        BOOL isFreeProvisioningProfile = [dictionary[@"LocalProvision"] boolValue];
        
        _data = [data copy];
        
        _name = [name copy];
        _UUID = [UUID copy];
        
        _teamIdentifier = [teamIdentifier copy];
        
        _creationDate = [creationDate copy];
        _expirationDate = [expirationDate copy];
        
        _entitlements = [entitlements copy];
        _deviceIDs = [deviceIDs copy];
        
        _isFreeProvisioningProfile = isFreeProvisioningProfile;
        
        [entitlements enumerateKeysAndObjectsUsingBlock:^(ALTEntitlement entitlement, id value, BOOL *stop) {
            if (![entitlement isEqualToString:ALTEntitlementApplicationIdentifier])
            {
                return;
            }
            
            NSUInteger location = [(NSString *)value rangeOfString:@"."].location;
            if (location == NSNotFound)
            {
                return;
            }
            
            NSString *bundleIdentifier = [value substringFromIndex:location + 1];
            self->_bundleIdentifier = [bundleIdentifier copy];
            
            *stop = YES;
        }];
        
        if (_bundleIdentifier == nil)
        {
            return nil;
        }
        
        NSMutableArray<ALTCertificate *> *certificates = [NSMutableArray array];
        
        NSArray *certificatesArray = dictionary[@"DeveloperCertificates"];
        for (NSData *data in certificatesArray)
        {
            ALTCertificate *certificate = [[ALTCertificate alloc] initWithData:data];
            if (certificate != nil)
            {
                [certificates addObject:certificate];
            }
        }
        
        _certificates = [certificates copy];
    }
    
    return self;
}

// Heavily inspired by libimobiledevice/ideviceprovision.c
// https://github.com/libimobiledevice/libimobiledevice/blob/ddba0b5efbcab483e80be10130c5c797f9ac8d08/tools/ideviceprovision.c#L98
+ (nullable NSDictionary<NSString *, id> *)dictionaryFromEncodedData:(NSData *)encodedData
{
    // Helper blocks
    size_t (^itemSize)(unsigned char *) = ^size_t(unsigned char *pointer) {
        size_t size = -1;

        char bsize = *(pointer + 1);
        if (bsize & 0x80)
        {
            switch (bsize & 0xF)
            {
                case 2:
                {
                    uint16_t value = *(uint16_t *)(pointer + 2);
                    size = ntohs(value);
                    break;
                }

                case 3:
                {
                    uint32_t value = *(uint32_t *)(pointer + 2);
                    size = ntohl(value) >> 8;
                    break;
                }

                case 4:
                {
                    uint32_t value = *(uint32_t *)(pointer + 2);
                    size = ntohl(value);
                    break;
                }

                default:
                    break;
            }
        }
        else
        {
            size = (size_t)bsize;
        }

        return size;
    };
    
    unsigned char * (^advanceToNextItem)(unsigned char *) = ^unsigned char *(unsigned char *pointer) {
        unsigned char *nextItem = pointer;

        char bsize = *(pointer + 1);
        if (bsize & 0x80)
        {
            nextItem += 2 + (bsize & 0xF);
        }
        else
        {
            nextItem += 3;
        }

        return nextItem;
    };
    
    unsigned char * (^skipNextItem)(unsigned char *) = ^unsigned char *(unsigned char *pointer) {
        size_t size = itemSize(pointer);
        
        unsigned char *nextItem = pointer + 2 + size;
        return nextItem;
    };
    

    /* Start parsing */
    unsigned char *pointer = (unsigned char *)encodedData.bytes;
    if (*pointer != ASN1_SEQUENCE)
    {
        return nil;
    }
    
    pointer = advanceToNextItem(pointer);
    if (*pointer != ASN1_OBJECT_IDENTIFIER)
    {
        return nil;
    }
    
    pointer = skipNextItem(pointer);
    if (*pointer != ASN1_CONTAINER)
    {
        return nil;
    }
    
    pointer = advanceToNextItem(pointer);
    if (*pointer != ASN1_SEQUENCE)
    {
        return nil;
    }
    
    pointer = advanceToNextItem(pointer);
    
    // Skip 2 items.
    for (int i = 0; i < 2; i++)
    {
        pointer = skipNextItem(pointer);
    }
    
    if (*pointer != ASN1_SEQUENCE)
    {
        return nil;
    }
    
    pointer = advanceToNextItem(pointer);
    if (*pointer != ASN1_OBJECT_IDENTIFIER)
    {
        return nil;
    }
    
    pointer = skipNextItem(pointer);
    if (*pointer != ASN1_CONTAINER)
    {
        return nil;
    }
    
    pointer = advanceToNextItem(pointer);
    if (*pointer != ASN1_OCTET_STRING)
    {
        return nil;
    }
    
    size_t length = itemSize(pointer);
    pointer = advanceToNextItem(pointer);
    
    NSData *data = [NSData dataWithBytes:(const void *)pointer length:length];
    
    NSError *error = nil;
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&error];
    if (dictionary == nil)
    {
        NSLog(@"Failed to parse provisioning profile from data. %@", error);
    }
    
    return dictionary;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@, UUID: %@, App BundleID: %@>", NSStringFromClass([self class]), self, self.name, self.UUID, self.bundleIdentifier];
}

- (BOOL)isEqual:(id)object
{
    ALTProvisioningProfile *profile = (ALTProvisioningProfile *)object;
    if (![profile isKindOfClass:[ALTProvisioningProfile class]])
    {
        return NO;
    }
    
    BOOL isEqual = ([self.UUID isEqual:profile.UUID] && [self.data isEqualToData:profile.data]);
    return isEqual;
}

- (NSUInteger)hash
{
    return self.UUID.hash ^ self.data.hash;
}

@end
