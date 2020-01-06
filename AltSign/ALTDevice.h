//
//  ALTDevice.h
//  AltSign
//
//  Created by Riley Testut on 5/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTDevice : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithName:(NSString *)name identifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
