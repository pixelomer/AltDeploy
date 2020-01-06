//
//  ALTAppleAPI+Authentication.m
//  AltSign
//
//  Created by Riley Testut on 11/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//
//  Heavily based on sample code provided by Kabir Oberai (https://github.com/kabiroberai)
//

#import "ALTAppleAPI+Authentication.h"
#import "ALTAppleAPI_Private.h"

#import "ALTModel+Internal.h"

// Core Crypto
#import <corecrypto/ccsrp.h>
#import <corecrypto/ccdrbg.h>
#import <corecrypto/ccsrp_gp.h>
#import <corecrypto/ccdigest.h>
#import <corecrypto/ccsha2.h>
#import <corecrypto/ccpbkdf2.h>
#import <corecrypto/cchmac.h>
#import <corecrypto/ccaes.h>
#import <corecrypto/ccpad.h>

static const char ALTHexCharacters[] = "0123456789abcdef";

struct ccrng_state *ccDRBGGetRngState(void);

void ALTDigestUpdateString(const struct ccdigest_info *di_info, struct ccdigest_ctx *di_ctx, NSString *string)
{
    ccdigest_update(di_info, di_ctx, string.length, string.UTF8String);
}

void ALTDigestUpdateData(const struct ccdigest_info *di_info, struct ccdigest_ctx *di_ctx, NSData *data)
{
    uint32_t data_len = (uint32_t)data.length; // 4 bytes for length
    ccdigest_update(di_info, di_ctx, sizeof(data_len), &data_len);
    ccdigest_update(di_info, di_ctx, data_len, data.bytes);
}

NSData *ALTPBKDF2SRP(const struct ccdigest_info *di_info, BOOL isS2k, NSString *password, NSData *salt, int iterations)
{
    const struct ccdigest_info *password_di_info = ccsha256_di();
    char *digest_raw = (char *)malloc(password_di_info->output_size);
    const char *passwordUTF8 = password.UTF8String;
    ccdigest(password_di_info, strlen(passwordUTF8), passwordUTF8, digest_raw);

    size_t final_digest_len = password_di_info->output_size * (isS2k ? 1 : 2);
    char *digest = (char *)malloc(final_digest_len);

    if (isS2k)
    {
        memcpy(digest, digest_raw, final_digest_len);
    }
    else
    {
        for (int i = 0; i < password_di_info->output_size; i++)
        {
            char byte = digest_raw[i];
            digest[i * 2 + 0] = ALTHexCharacters[(byte >> 4) & 0x0F];
            digest[i * 2 + 1] = ALTHexCharacters[(byte >> 0) & 0x0F];
        }
    }

    NSMutableData *data = [NSMutableData dataWithLength:di_info->output_size];
    
    if (ccpbkdf2_hmac(di_info, final_digest_len, digest, salt.length, salt.bytes, iterations, di_info->output_size, data.mutableBytes) != 0)
    {
        return nil;
    }
    
    return data;
}

NSData *ALTCreateSessionKey(ccsrp_ctx_t srp_ctx, const char *key_name)
{
    size_t key_len;
    const void *session_key = ccsrp_get_session_key(srp_ctx, &key_len);
    
    const struct ccdigest_info *di_info = ccsha256_di();
    
    size_t hmac_len = di_info->output_size;
    unsigned char *hmac_bytes = (unsigned char *)malloc(hmac_len);
    cchmac(di_info, key_len, session_key, strlen(key_name), key_name, hmac_bytes);
    
    NSData *sessionKey = [NSData dataWithBytes:hmac_bytes length:hmac_len];
    return sessionKey;
}

NSData *ALTDecryptDataCBC(ccsrp_ctx_t srp_ctx, NSData *spd)
{
    NSData *extraDataKey = ALTCreateSessionKey(srp_ctx, "extra data key:");
    NSData *extraDataIV = ALTCreateSessionKey(srp_ctx, "extra data iv:");

    NSMutableData *decryptedData = [NSMutableData dataWithLength:spd.length];

    const struct ccmode_cbc *decrypt_mode = ccaes_cbc_decrypt_mode();
    
    cccbc_iv *iv = (cccbc_iv *)malloc(decrypt_mode->block_size);
    if (extraDataIV.bytes)
    {
        memcpy(iv, extraDataIV.bytes, decrypt_mode->block_size);
    }
    else
    {
        bzero(iv, decrypt_mode->block_size);
    }

    cccbc_ctx *ctx_buf = (cccbc_ctx *)malloc(decrypt_mode->size);
    decrypt_mode->init(decrypt_mode, ctx_buf, extraDataKey.length, extraDataKey.bytes);

    size_t length = ccpad_pkcs7_decrypt(decrypt_mode, ctx_buf, iv, spd.length, spd.bytes, decryptedData.mutableBytes);
    if (length > spd.length)
    {
        return nil;
    }

    return decryptedData;
}

NSData *ALTDecryptDataGCM(NSData *sk, NSData *encryptedData)
{
    const struct ccmode_gcm *decrypt_mode = ccaes_gcm_decrypt_mode();
    
    ccgcm_ctx *gcm_ctx = (ccgcm_ctx *)malloc(decrypt_mode->size);
    decrypt_mode->init(decrypt_mode, gcm_ctx, sk.length, sk.bytes);
    
    if (encryptedData.length < 35)
    {
        NSLog(@"ERROR: Encrypted token too short.");
        return nil;
    }
    
    if (cc_cmp_safe(3, encryptedData.bytes, "XYZ"))
    {
        NSLog(@"ERROR: Encrypted token wrong version!");
        return nil;
    }
    
    decrypt_mode->set_iv(gcm_ctx, 16, encryptedData.bytes + 3);
    decrypt_mode->gmac(gcm_ctx, 3, encryptedData.bytes);

    size_t decrypted_len = encryptedData.length - 35;
    NSMutableData *decryptedData = [NSMutableData dataWithLength:decrypted_len];
    
    decrypt_mode->gcm(gcm_ctx, decrypted_len, encryptedData.bytes + 16 + 3, decryptedData.mutableBytes);

    char tag[16];
    decrypt_mode->finalize(gcm_ctx, 16, tag);
    
    if (cc_cmp_safe(16, encryptedData.bytes + decrypted_len + 19, tag))
    {
        NSLog(@"Invalid tag version");
        return nil;
    }

    return decryptedData;
}

NSData *ALTCreateAppTokensChecksum(NSData *sk, NSString *adsid, NSArray<NSString *> *apps)
{
    const struct ccdigest_info *di_info = ccsha256_di();
    size_t hmac_size = cchmac_di_size(di_info);
    struct cchmac_ctx *hmac_ctx = (struct cchmac_ctx *)malloc(hmac_size);
    cchmac_init(di_info, hmac_ctx, sk.length, sk.bytes);

    const char *key = "apptokens";
    cchmac_update(di_info, hmac_ctx, strlen(key), key);

    const char *adsidUTF8 = adsid.UTF8String;
    cchmac_update(di_info, hmac_ctx, strlen(adsidUTF8), adsidUTF8);

    for (NSString *app in apps)
    {
        cchmac_update(di_info, hmac_ctx, app.length, app.UTF8String);
    }
    
    NSMutableData *checksum = [NSMutableData dataWithLength:di_info->output_size];
    cchmac_final(di_info, hmac_ctx, checksum.mutableBytes);

    return checksum;
}

@implementation ALTAppleAPI (Authentication)

- (void)authenticateWithAppleID:(NSString *)appleID
                       password:(NSString *)password
                   anisetteData:(ALTAnisetteData *)anisetteData
            verificationHandler:(void (^)(void (^ _Nonnull)(NSString * _Nullable)))verificationHandler
              completionHandler:(void (^)(ALTAccount * _Nullable, ALTAppleAPISession * _Nullable, NSError * _Nullable))completionHandler
{
    NSMutableDictionary *clientDictionary = [@{
        @"bootstrap": @YES,
        @"icscrec": @YES,
        @"loc": NSLocale.currentLocale.localeIdentifier,
        @"pbe": @NO,
        @"prkgen": @YES,
        @"svct": @"iCloud",
        @"X-Apple-I-Client-Time": [self.dateFormatter stringFromDate:anisetteData.date],
        @"X-Apple-Locale": NSLocale.currentLocale.localeIdentifier,
        @"X-Apple-I-TimeZone": NSTimeZone.localTimeZone.abbreviation,
        @"X-Apple-I-MD": anisetteData.oneTimePassword,
        @"X-Apple-I-MD-LU": anisetteData.localUserID,
        @"X-Apple-I-MD-M": anisetteData.machineID,
        @"X-Apple-I-MD-RINFO": @(anisetteData.routingInfo),
        @"X-Mme-Device-Id": anisetteData.deviceUniqueIdentifier,
        @"X-Apple-I-SRL-NO": anisetteData.deviceSerialNumber,
    } mutableCopy];
    
    /* Begin CoreCrypto Logic */
    ccsrp_const_gp_t gp = ccsrp_gp_rfc5054_2048();
    
    const struct ccdigest_info *di_info = ccsha256_di();
    struct ccdigest_ctx *di_ctx = (struct ccdigest_ctx *)malloc(ccdigest_di_size(di_info));
    ccdigest_init(di_info, di_ctx);
    
    const struct ccdigest_info *srp_di = ccsha256_di();
    struct ccsrp_ctx_body *srp_ctx = (struct ccsrp_ctx_body *)malloc(ccsrp_sizeof_srp(di_info, gp));
    ccsrp_ctx_init(srp_ctx, srp_di, gp);
    
    srp_ctx->hdr.blinding_rng = ccrng(NULL);
    srp_ctx->hdr.flags.noUsernameInX = true;
    
    NSArray<NSString *> *ps = @[@"s2k", @"s2k_fo"];
    ALTDigestUpdateString(di_info, di_ctx, ps[0]);
    ALTDigestUpdateString(di_info, di_ctx, @",");
    ALTDigestUpdateString(di_info, di_ctx, ps[1]);
    
    size_t A_size = ccsrp_exchange_size(srp_ctx);
    char *A_bytes = (char *)malloc(A_size);
    ccsrp_client_start_authentication(srp_ctx, ccDRBGGetRngState(), A_bytes);
    
    NSData *A_data = [NSData dataWithBytes:A_bytes length:A_size];
    
    ALTDigestUpdateString(di_info, di_ctx, @"|");
    
    NSDictionary *parameters = @{
        @"A2k": A_data,
        @"ps": ps,
        @"cpd": clientDictionary,
        @"u": appleID,
        @"o": @"init"
    };
    
    // 1st Request
    [self sendAuthenticationRequestWithParameters:parameters anisetteData:anisetteData completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, nil, requestError);
            return;
        }
        
        size_t M_size = ccsrp_get_session_key_length(srp_ctx);
        char *M_bytes = (char *)malloc(A_size);
        NSData *M_data = [NSData dataWithBytes:M_bytes length:M_size];
        
        NSString *sp = responseDictionary[@"sp"];
        BOOL isS2K = [sp isEqualToString:@"s2k"];
        
        ALTDigestUpdateString(di_info, di_ctx, @"|");
        
        if (sp)
        {
            ALTDigestUpdateString(di_info, di_ctx, sp);
        }

        NSString *c = responseDictionary[@"c"];
        NSData *salt = responseDictionary[@"s"];
        NSNumber *iterations = responseDictionary[@"i"];
        NSData *B_data = responseDictionary[@"B"];
        
        if (c == nil || salt == nil || iterations == nil || B_data == nil)
        {
            completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
            return;
        }
        
        NSData *passwordKey = ALTPBKDF2SRP(di_info, isS2K, password, salt, [iterations intValue]);
        if (passwordKey == nil)
        {
            completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
            return;
        }
        
        int result = ccsrp_client_process_challenge(srp_ctx, appleID.UTF8String, passwordKey.length, passwordKey.bytes,
                                                    salt.length, salt.bytes, B_data.bytes, (void *)M_data.bytes);
        if (result != 0)
        {
            completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
            return;
        }
        
        NSDictionary *parameters = @{
            @"c": c,
            @"M1": M_data,
            @"cpd": clientDictionary,
            @"u": appleID,
            @"o": @"complete"
        };
        
        // 2nd Request
        [self sendAuthenticationRequestWithParameters:parameters anisetteData:anisetteData completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
            if (responseDictionary == nil)
            {
                completionHandler(nil, nil, requestError);
                return;
            }
            
            NSData *M2_data = responseDictionary[@"M2"];
            if (M2_data == nil)
            {
                NSLog(@"ERROR: M2 data not found!");
                
                completionHandler(nil, nil,  [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
                return;
            }
            
            if (!ccsrp_client_verify_session(srp_ctx, M2_data.bytes))
            {
                NSLog(@"ERROR: Failed to verify session.");
                
                completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
                return;
            }

            ALTDigestUpdateString(di_info, di_ctx, @"|");
            
            NSData *spd = responseDictionary[@"spd"];
            if (spd)
            {
                ALTDigestUpdateData(di_info, di_ctx, spd);
            }
            
            ALTDigestUpdateString(di_info, di_ctx, @"|");
            
            NSData *sc = responseDictionary[@"sc"];
            if (sc)
            {
                ALTDigestUpdateData(di_info, di_ctx, sc);
            }
            
            ALTDigestUpdateString(di_info, di_ctx, @"|");
            
            NSData *np = responseDictionary[@"np"];
            if (np == nil)
            {
                NSLog(@"ERROR: Missing np dictionary.");
                
                completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
                return;
            }
            
            size_t digest_len = di_info->output_size;
            if (np.length != digest_len)
            {
                NSLog(@"ERROR: Neg proto hash is too short.");
                
                completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
                return;
            }
            
            unsigned char *digest = (unsigned char *)malloc(digest_len);
            di_info->final(di_info, di_ctx, digest);

            NSData *hmacKey = ALTCreateSessionKey(srp_ctx, "HMAC key:");
            unsigned char *hmac_out = (unsigned char *)malloc(digest_len);
            cchmac(di_info, hmacKey.length, hmacKey.bytes, digest_len, digest, hmac_out);
            
            if (cc_cmp_safe(digest_len, hmac_out, np.bytes))
            {
                NSLog(@"ERROR: Invalid neg prot hmac.");
                
                completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
                return;
            }
            
            NSData *decryptedData = ALTDecryptDataCBC(srp_ctx, spd);
            if (decryptedData == nil)
            {
                NSLog(@"ERROR: Could not decrypt login response.");
                
                completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorAuthenticationHandshakeFailed userInfo:nil]);
                return;
            }
            
            NSError *parseError = nil;
            NSDictionary *decryptedDictionary = [NSPropertyListSerialization propertyListWithData:decryptedData options:0 format:nil error:&parseError];
            if (decryptedDictionary == nil)
            {
                NSLog(@"ERROR: Could not parse decrypted login response plist!");
                
                completionHandler(nil, nil, parseError);
                return;
            }
                        
            NSString *adsid = decryptedDictionary[@"adsid"];
            NSString *idmsToken = decryptedDictionary[@"GsIdmsToken"];
            
            if (adsid == nil || idmsToken == nil)
            {
                NSLog(@"ERROR: adsid and/or idmsToken is nil. adsid: %@. idmsToken: %@", adsid, idmsToken);
                
                completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
                return;
            }
            
            NSDictionary *statusDictionary = responseDictionary[@"Status"];
            
            NSString *authType = statusDictionary[@"au"];
            if ([authType isEqualToString:@"trustedDeviceSecondaryAuth"])
            {
                // Handle Two-Factor
                
                if (verificationHandler != nil)
                {
                    [self requestTwoFactorCodeForDSID:adsid idmsToken:idmsToken anisetteData:anisetteData verificationHandler:verificationHandler completionHandler:^(BOOL success, NSError *error) {
                        if (success)
                        {
                            // We've successfully signed-in with two-factor, so restart authentication (which will now succeed).
                            [self authenticateWithAppleID:appleID password:password anisetteData:anisetteData verificationHandler:verificationHandler completionHandler:completionHandler];
                        }
                        else
                        {
                            completionHandler(nil, nil, error);
                        }
                    }];
                }
                else
                {
                    completionHandler(nil, nil, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorRequiresTwoFactorAuthentication userInfo:nil]);
                }
            }
            else
            {
                // Fetch Auth Token
                
                NSData *sk = decryptedDictionary[@"sk"];
                NSData *c = decryptedDictionary[@"c"];
                
                if (sk == nil || c == nil)
                {
                    NSLog(@"ERROR: No ak and/or c data.");
                    
                    completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
                    return;
                }
                
                NSArray *apps = @[@"com.apple.gs.xcode.auth"];
                NSData *checksum = ALTCreateAppTokensChecksum(sk, adsid, apps);
                
                NSDictionary *parameters = @{
                    @"u": adsid,
                    @"app": apps,
                    @"c": c,
                    @"t": idmsToken,
                    @"checksum": checksum,
                    @"cpd": clientDictionary,
                    @"o": @"apptokens"
                };
                
                [self fetchAuthTokenWithParameters:parameters sk:sk anisetteData:anisetteData completionHandler:^(NSString *authToken, NSError *error) {
                    if (authToken == nil)
                    {
                        completionHandler(nil, nil, error);
                        return;
                    }
                    
                    ALTAppleAPISession *session = [[ALTAppleAPISession alloc] initWithDSID:adsid authToken:authToken anisetteData:anisetteData];
                    [self fetchAccountForSession:session completionHandler:^(ALTAccount *account, NSError *error) {
                        if (account == nil)
                        {
                            completionHandler(nil, nil, error);
                        }
                        else
                        {
                            completionHandler(account, session, nil);
                        }
                    }];
                }];
            }
        }];
    }];
}

- (void)fetchAuthTokenWithParameters:(NSDictionary *)parameters sk:(NSData *)sk anisetteData:(ALTAnisetteData *)anisetteData completionHandler:(void (^)(NSString *authToken, NSError *error))completionHandler
{
    [self sendAuthenticationRequestWithParameters:parameters anisetteData:anisetteData completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }
        
        NSData *encryptedToken = responseDictionary[@"et"];
        NSData *decryptedToken = ALTDecryptDataGCM(sk, encryptedToken);
        
        if (decryptedToken == nil)
        {
            NSLog(@"ERROR: Failed to decrypt apptoken.");
            
            completionHandler(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
            return;
        }
        
        NSError *parseError = nil;
        NSDictionary *decryptedTokenDictionary = [NSPropertyListSerialization propertyListWithData:decryptedToken options:0 format:nil error:&parseError];
        if (decryptedTokenDictionary == nil)
        {
            NSLog(@"ERROR: Could not parse decrypted apptoken plist.");
            
            completionHandler(nil, parseError);
            return;
        }
                
        NSString *app = [parameters[@"app"] firstObject];
        
        NSDictionary *tokenDictionary = decryptedTokenDictionary[@"t"][app];
        NSString *token = tokenDictionary[@"token"];
        NSNumber *expirationDataMS = tokenDictionary[@"expiry"];
        
        if (token == nil)
        {
            completionHandler(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]);
            return;
        }
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSince1970:(double)expirationDataMS.integerValue / 1000];
        NSLog(@"Got token for %@!\nExpires: %@\nValue: %@\n", app, expirationDate, token);
        
        completionHandler(token, nil);
    }];
}

- (void)requestTwoFactorCodeForDSID:(NSString *)dsid idmsToken:(NSString *)idmsToken anisetteData:(ALTAnisetteData *)anisetteData
                verificationHandler:(nonnull void (^)(void (^ _Nonnull)(NSString * _Nonnull)))verificationHandler
                  completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"https://gsa.apple.com/auth/verify/trusteddevice"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSString *identityToken = [NSString stringWithFormat:@"%@:%@", dsid, idmsToken];
    
    NSData *identityTokenData = [identityToken dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedIdentityToken = [identityTokenData base64EncodedStringWithOptions:0];
    
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
        @"Content-Type": @"text/x-xml-plist",
        @"User-Agent": @"Xcode",
        @"Accept": @"text/x-xml-plist",
        @"Accept-Language": @"en-us",
        @"X-Apple-App-Info": @"com.apple.gs.xcode.auth",
        @"X-Xcode-Version": @"11.2 (11B41)",
        @"X-Apple-Identity-Token": encodedIdentityToken,
        @"X-Apple-I-MD-M": anisetteData.machineID,
        @"X-Apple-I-MD": anisetteData.oneTimePassword,
        @"X-Apple-I-MD-LU": anisetteData.localUserID,
        @"X-Apple-I-MD-RINFO": [@(anisetteData.routingInfo) description],
        @"X-Mme-Device-Id": anisetteData.deviceUniqueIdentifier,
        @"X-MMe-Client-Info": anisetteData.deviceDescription,
        @"X-Apple-I-Client-Time": [self.dateFormatter stringFromDate:anisetteData.date],
        @"X-Apple-Locale": anisetteData.locale.localeIdentifier,
        @"X-Apple-I-TimeZone": anisetteData.timeZone.abbreviation
    };
    
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
    
    NSURLSessionDataTask *requestCodeTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data == nil || error != nil)
        {
            completionHandler(NO, error);
            return;
        }
        
        void (^responseHandler)(NSString *) = ^(NSString *_Nullable verificationCode) {
            if (verificationCode == nil)
            {
                completionHandler(NO, [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorRequiresTwoFactorAuthentication userInfo:nil]);
                return;
            }

            NSMutableDictionary<NSString *, NSString *> *headers = [httpHeaders mutableCopy];
            headers[@"security-code"] = verificationCode;
            
            NSURL *URL = [NSURL URLWithString:@"https://gsa.apple.com/grandslam/GsService2/validate"];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
            
            [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
                [request setValue:value forHTTPHeaderField:key];
            }];
            
            NSURLSessionDataTask *verifyCodeTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (data == nil || error != nil)
                {
                    completionHandler(NO, error);
                    return;
                }
                
                NSError *parseError = nil;
                NSDictionary *responseDictionary = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&parseError];
                
                if (responseDictionary == nil)
                {
                    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSUnderlyingErrorKey: parseError}];
                    completionHandler(NO, error);
                    return;
                }
                
                NSInteger errorCode = [responseDictionary[@"ec"] integerValue]; // Same for NSString or NSNumber.
                if (errorCode != 0)
                {
                    NSError *error = nil;
                    switch (errorCode)
                    {
                        case -21669:
                            error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorIncorrectVerificationCode userInfo:nil];
                            break;
                            
                        default:
                            break;
                    }
                    
                    if (error == nil)
                    {
                        NSString *errorDescription = responseDictionary[@"em"];
                        NSString *localizedDescription = [NSString stringWithFormat:@"%@ (%@)", errorDescription, @(errorCode)];
                        
                        error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
                    }
                    
                    completionHandler(NO, error);
                }
                else
                {
                    completionHandler(YES, nil);
                }
            }];
            
            [verifyCodeTask resume];
        };
        
        verificationHandler(responseHandler);
    }];
    
    [requestCodeTask resume];
}

- (void)fetchAccountForSession:(ALTAppleAPISession *)session completionHandler:(void (^)(ALTAccount *account, NSError *error))completionHandler
{
    NSURL *URL = [NSURL URLWithString:@"viewDeveloper.action" relativeToURL:self.baseURL];
    
    [self sendRequestWithURL:URL additionalParameters:nil session:session team:nil completionHandler:^(NSDictionary *responseDictionary, NSError *requestError) {
        if (responseDictionary == nil)
        {
            completionHandler(nil, requestError);
            return;
        }

        NSError *error = nil;
        ALTAccount *account = [self processResponse:responseDictionary parseHandler:^id _Nullable{
            NSDictionary *dictionary = responseDictionary[@"developer"];
            if (dictionary == nil)
            {
                return nil;
            }
            
            ALTAccount *account = [[ALTAccount alloc] initWithResponseDictionary:dictionary];
            return account;
        } resultCodeHandler:nil error:&error];
        
        completionHandler(account, error);
    }];
}

- (void)sendAuthenticationRequestWithParameters:(NSDictionary *)requestDictionary anisetteData:(ALTAnisetteData *)anisetteData completionHandler:(void (^)(NSDictionary *responseDictionary, NSError *error))completionHandler
{
    NSURL *requestURL = [NSURL URLWithString:@"https://gsa.apple.com/grandslam/GsService2"];
    
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *parameters = @{
        @"Header": @{ @"Version": @"1.0.1" },
        @"Request": requestDictionary
    };
    
    NSError *serializationError = nil;
    NSData *bodyData = [NSPropertyListSerialization dataWithPropertyList:parameters format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializationError];
    if (bodyData == nil)
    {
        NSError *error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorInvalidParameters userInfo:@{NSUnderlyingErrorKey: serializationError}];
        completionHandler(nil, error);
        return;
    }
    
    NSDictionary<NSString *, NSString *> *httpHeaders = @{
        @"Content-Type": @"text/x-xml-plist",
        @"X-MMe-Client-Info": anisetteData.deviceDescription,
        @"Accept": @"*/*",
        @"User-Agent": @"akd/1.0 CFNetwork/978.0.7 Darwin/18.7.0"
    };
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
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
        
        NSDictionary *dictionary = responseDictionary[@"Response"];
        
        NSDictionary *status = dictionary[@"Status"];
        
        NSInteger errorCode = [status[@"ec"] integerValue];
        if (errorCode != 0)
        {
            NSError *error = nil;
            switch (errorCode)
            {
                case -22406:
                    error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorIncorrectCredentials userInfo:nil];
                    break;
                    
                default:
                    break;
            }
            
            if (error == nil)
            {
                NSString *errorDescription = status[@"em"];
                NSString *localizedDescription = [NSString stringWithFormat:@"%@ (%@)", errorDescription, @(errorCode)];
                
                error = [NSError errorWithDomain:ALTAppleAPIErrorDomain code:ALTAppleAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
            }
            
            completionHandler(nil, error);
        }
        else
        {
            completionHandler(dictionary, nil);
        }
    }];
    
    [dataTask resume];
}

@end
