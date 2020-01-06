//
//  ALTCertificateRequest.m
//  AltSign
//
//  Created by Riley Testut on 5/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTCertificateRequest.h"
#include <openssl/bn.h>
#include <openssl/pem.h>
#include <openssl/x509.h>

@implementation ALTCertificateRequest

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSData *data = nil;
        NSData *privateKey = nil;
        [self generateRequest:&data privateKey:&privateKey];
        
        if (data == nil || privateKey == nil)
        {
            return nil;
        }
        
        _data = [data copy];
        _privateKey = [privateKey copy];
    }
    
    return self;
}

// Based on https://www.codepool.biz/how-to-use-openssl-to-generate-x-509-certificate-request.html
- (void)generateRequest:(NSData **)outputRequest privateKey:(NSData **)outputPrivateKey
{
    BIGNUM *bignum = NULL;
    __block RSA *rsa = NULL;
    
    X509_REQ *request = NULL;
    EVP_PKEY *publicKey = NULL;
    
    BIO *csr = NULL;
    BIO *privateKey = NULL;
    
    void (^finish)(void) = ^{
        if (publicKey != NULL)
        {
            // Also frees rsa, so we check if non-nil to prevent double free.
            EVP_PKEY_free(publicKey);
        }
        else
        {
            RSA_free(rsa);
        }
        
        BN_free(bignum);
        X509_REQ_free(request);
        
        BIO_free_all(csr);
        BIO_free_all(privateKey);
    };
    
    /* Generate RSA Key */
    
    bignum = BN_new();
    if (BN_set_word(bignum, RSA_F4) != 1)
    {
        finish();
        return;
    }
    
    rsa = RSA_new();
    if (RSA_generate_key_ex(rsa, 2048, bignum, NULL) != 1)
    {
        finish();
        return;
    }
    
    /* Generate request */
    
    const char *country = "US";
    const char *state = "CA";
    const char *city = "Los Angeles";
    const char *organization = "AltSign";
    const char *commonName = "AltSign";
    
    request = X509_REQ_new();
    if (X509_REQ_set_version(request, 1) != 1)
    {
        finish();
        return;
    }
    
    // Subject
    X509_NAME *subject = X509_REQ_get_subject_name(request);
    X509_NAME_add_entry_by_txt(subject, "C", MBSTRING_ASC, (const unsigned char *)country, -1, -1, 0);
    X509_NAME_add_entry_by_txt(subject, "ST", MBSTRING_ASC, (const unsigned char*)state, -1, -1, 0);
    X509_NAME_add_entry_by_txt(subject, "L", MBSTRING_ASC, (const unsigned char*)city, -1, -1, 0);
    X509_NAME_add_entry_by_txt(subject, "O", MBSTRING_ASC, (const unsigned char*)organization, -1, -1, 0);
    X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_ASC, (const unsigned char*)commonName, -1, -1, 0);
    
    // Public Key
    publicKey = EVP_PKEY_new();
    EVP_PKEY_assign_RSA(publicKey, rsa);
    
    if (X509_REQ_set_pubkey(request, publicKey) != 1)
    {
        finish();
        return;
    }
    
    // Sign request
    if (X509_REQ_sign(request, publicKey, EVP_sha1()) <= 0)
    {
        finish();
        return;
    }
    
    // Output
    csr = BIO_new(BIO_s_mem());
    if (PEM_write_bio_X509_REQ(csr, request) != 1)
    {
        finish();
        return;
    }
    
    privateKey = BIO_new(BIO_s_mem());
    if (PEM_write_bio_RSAPrivateKey(privateKey, rsa, NULL, NULL, 0, NULL, NULL) != 1)
    {
        finish();
        return;
    }
    
    /* Return values */
    
    char *csrData = NULL;
    long csrLength = BIO_get_mem_data(csr, &csrData);
    *outputRequest = [NSData dataWithBytes:csrData length:csrLength];
    
    char *privateKeyData = NULL;
    long privateKeyLength = BIO_get_mem_data(privateKey, &privateKeyData);
    *outputPrivateKey = [NSData dataWithBytes:privateKeyData length:privateKeyLength];
    
    finish();
}

@end
