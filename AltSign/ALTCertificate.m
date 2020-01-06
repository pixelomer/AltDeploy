//
//  ALTCertificate.m
//  AltSign
//
//  Created by Riley Testut on 5/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTCertificate.h"

#include <openssl/pem.h>
#include <openssl/pkcs12.h>

NSString *ALTCertificatePEMPrefix = @"-----BEGIN CERTIFICATE-----";
NSString *ALTCertificatePEMSuffix = @"-----END CERTIFICATE-----";

@implementation ALTCertificate

- (instancetype)initWithName:(NSString *)name serialNumber:(NSString *)serialNumber data:(nullable NSData *)data
{
    self = [super init];
    if (self)
    {
        _name = [name copy];
        _serialNumber = [serialNumber copy];
        _data = [data copy];
    }
    
    return self;
}

- (instancetype)initWithResponseDictionary:(NSDictionary *)responseDictionary
{
    NSString *identifier = responseDictionary[@"id"];
    
    NSDictionary *attributesDictionary = responseDictionary[@"attributes"] ?: responseDictionary;
                                              
    NSData *data = nil;
    if (attributesDictionary[@"certContent"] != nil)
    {
        data = attributesDictionary[@"certContent"];
    }
    else if (attributesDictionary[@"certificateContent"] != nil)
    {
        NSString *encodedData = attributesDictionary[@"certificateContent"];
        data = [[NSData alloc] initWithBase64EncodedString:encodedData options:0];
    }
    
    NSString *machineName = attributesDictionary[@"machineName"];
    NSString *machineIdentifier = attributesDictionary[@"machineId"];
    
    if (data != nil)
    {
        self = [self initWithData:data];
    }
    else
    {
        NSString *name = attributesDictionary[@"name"];
        NSString *serialNumber = attributesDictionary[@"serialNumber"] ?: attributesDictionary[@"serialNum"];
        
        self = [self initWithName:name serialNumber:serialNumber data:nil];
    }
    
    if (self)
    {
        _machineName = [machineName copy];
        _machineIdentifier = [machineIdentifier copy];
        _identifier = [identifier copy];
    }
    
    return self;
}

- (nullable instancetype)initWithP12Data:(NSData *)p12Data password:(nullable NSString *)password
{
    BIO *inputP12Buffer = BIO_new(BIO_s_mem());
    BIO_write(inputP12Buffer, p12Data.bytes, (int)p12Data.length);
    
    PKCS12 *inputP12 = d2i_PKCS12_bio(inputP12Buffer, NULL);
    
    // Extract key + certificate from .p12.
    EVP_PKEY *key;
    X509 *certificate;
    PKCS12_parse(inputP12, password.UTF8String, &key, &certificate, NULL);
    
    if (key == nil || certificate == nil)
    {
        return nil;
    }
    
    BIO *pemBuffer = BIO_new(BIO_s_mem());
    PEM_write_bio_X509(pemBuffer, certificate);
    
    BIO *privateKeyBuffer = BIO_new(BIO_s_mem());
    PEM_write_bio_PrivateKey(privateKeyBuffer, key, NULL, NULL, 0, NULL, NULL);
    
    char *pemBytes = NULL;
    NSUInteger pemSize = BIO_get_mem_data(pemBuffer, &pemBytes);
    
    char *privateKeyBytes = NULL;
    NSUInteger privateKeySize = BIO_get_mem_data(privateKeyBuffer, &privateKeyBytes);
    
    NSData *pemData = [NSData dataWithBytes:pemBytes length:pemSize];
    NSData *privateKey = [NSData dataWithBytes:privateKeyBytes length:privateKeySize];
    
    self = [self initWithData:pemData];
    if (self)
    {
        _privateKey = [privateKey copy];
    }
    
    return self;
}

- (nullable instancetype)initWithData:(NSData *)data
{
    NSData *pemData = data;
    
    NSData *prefixData = [data subdataWithRange:NSMakeRange(0, MIN(data.length, ALTCertificatePEMPrefix.length))];
    NSString *prefix = [[NSString alloc] initWithData:prefixData encoding:NSUTF8StringEncoding];
    
    if (![prefix isEqualToString:ALTCertificatePEMPrefix])
    {
        // Convert to proper PEM format before storing.
        NSString *base64Data = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        
        NSString *content = [NSString stringWithFormat:@"%@\n%@\n%@", ALTCertificatePEMPrefix, base64Data, ALTCertificatePEMSuffix];
        pemData = [content dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    BIO *certificateBuffer = BIO_new(BIO_s_mem());
    BIO_write(certificateBuffer, pemData.bytes, (int)pemData.length);
    
    X509 *certificate = nil;
    PEM_read_bio_X509(certificateBuffer, &certificate, 0, 0);
    if (certificate == nil)
    {
        return nil;
    }
    
    /* Certificate Common Name */
    X509_NAME *subject = X509_get_subject_name(certificate);
    int index = X509_NAME_get_index_by_NID(subject, NID_commonName, -1);
    if (index == -1)
    {
        return nil;
    }
    
    X509_NAME_ENTRY *nameEntry = X509_NAME_get_entry(subject, index);
    ASN1_STRING *nameData = X509_NAME_ENTRY_get_data(nameEntry);
    unsigned char *cName = ASN1_STRING_data(nameData);
    
    
    /* Serial Number */
    ASN1_INTEGER *serialNumberData = X509_get_serialNumber(certificate);
    BIGNUM *number = ASN1_INTEGER_to_BN(serialNumberData, NULL);
    if (number == nil)
    {
        return nil;
    }
    
    char *cSerialNumber = BN_bn2hex(number);
    
    if (cName == nil || cSerialNumber == nil)
    {
        return nil;
    }
    
    NSString *name = [NSString stringWithFormat:@"%s", cName];
    NSString *serialNumber = [NSString stringWithFormat:@"%s", cSerialNumber];
    
    NSInteger location = NSNotFound;
    for (int i = 0; i < serialNumber.length; i++)
    {
        if ([serialNumber characterAtIndex:i] != '0')
        {
            location = i;
            break;
        }
    }

    if (location == NSNotFound)
    {
        return nil;
    }
    
    // Remove leading zeros.
    NSString *trimmedSerialNumber = [serialNumber substringFromIndex:location];
    
    self = [self initWithName:name serialNumber:trimmedSerialNumber data:pemData];
    return self;
}

#pragma mark - NSObject -

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, Name: %@, SN: %@>", NSStringFromClass([self class]), self, self.name, self.serialNumber];
}

- (BOOL)isEqual:(id)object
{
    ALTCertificate *certificate = (ALTCertificate *)object;
    if (![certificate isKindOfClass:[ALTCertificate class]])
    {
        return NO;
    }
    
    BOOL isEqual = [self.serialNumber isEqualToString:certificate.serialNumber];
    return isEqual;
}

- (NSUInteger)hash
{
    return self.serialNumber.hash;
}

#pragma mark - ALTCertificate -

- (nullable NSData *)p12Data
{
    return [self encryptedP12DataWithPassword:@""];
}

- (nullable NSData *)encryptedP12DataWithPassword:(NSString *)password
{
    BIO *certificateBuffer = BIO_new(BIO_s_mem());
    BIO *privateKeyBuffer = BIO_new(BIO_s_mem());
    
    BIO_write(certificateBuffer, self.data.bytes, (int)self.data.length);
    BIO_write(privateKeyBuffer, self.privateKey.bytes, (int)self.privateKey.length);
    
    X509 *certificate = nil;
    PEM_read_bio_X509(certificateBuffer, &certificate, 0, 0);
    
    EVP_PKEY *privateKey = nil;
    PEM_read_bio_PrivateKey(privateKeyBuffer, &privateKey, 0, 0);
    
    char emptyString[] = "";
    PKCS12 *outputP12 = PKCS12_create((char *)password.UTF8String, emptyString, privateKey, certificate, NULL, 0, 0, 0, 0, 0);
    
    BIO *p12Buffer = BIO_new(BIO_s_mem());
    i2d_PKCS12_bio(p12Buffer, outputP12);
    
    char *buffer = NULL;
    NSUInteger size = BIO_get_mem_data(p12Buffer, &buffer);
    
    NSData *p12Data = [NSData dataWithBytes:buffer length:size];
    
    BIO_free(p12Buffer);
    PKCS12_free(outputP12);
    
    EVP_PKEY_free(privateKey);
    X509_free(certificate);
    
    BIO_free(privateKeyBuffer);
    BIO_free(certificateBuffer);
    
    return p12Data;
}

@end
