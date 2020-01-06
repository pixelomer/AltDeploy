//
//  ALTAppleAPI+Private.h
//  AltSign
//
//  Created by Riley Testut on 11/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "ALTAppleAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface ALTAppleAPI ()

@property (nonatomic, readonly) NSURLSession *session;
@property (nonatomic, readonly) NSISO8601DateFormatter *dateFormatter;

@property (nonatomic, copy, readonly) NSURL *baseURL;
@property (nonatomic, copy, readonly) NSURL *servicesBaseURL;

- (void)sendRequestWithURL:(NSURL *)requestURL
      additionalParameters:(nullable NSDictionary *)additionalParameters
                   session:(ALTAppleAPISession *)session
                      team:(nullable ALTTeam *)team
         completionHandler:(void (^)(NSDictionary *responseDictionary, NSError *error))completionHandler;

- (nullable id)processResponse:(NSDictionary *)responseDictionary
                  parseHandler:(id _Nullable (^_Nullable)(void))parseHandler
             resultCodeHandler:(NSError *_Nullable (^_Nullable)(NSInteger resultCode))resultCodeHandler
                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
