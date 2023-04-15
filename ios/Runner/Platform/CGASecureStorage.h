//
//  SecureStorage.h
//  Runner
//
//  Created by Sam M. on 4/9/23.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

#pragma once

@interface CGASecureStoragePlatformHandler : NSObject

@property (nonatomic, retain) FlutterMethodChannel* _Nonnull channel;

/**
 * Allocates a FlutterMethodChannel
 */
+ (CGASecureStoragePlatformHandler* _Nonnull) bind:(FlutterViewController* _Nonnull) controller withName:(NSString* _Nonnull) name;

- (instancetype _Nonnull) init NS_UNAVAILABLE __attribute__((unavailable("Use -initWithChannel instead.")));

- (instancetype _Nonnull) initWithChannel:(FlutterMethodChannel* _Nonnull) channel;

- (void) handle:(FlutterMethodCall* _Nonnull) call result:(FlutterResult _Nonnull) result;

@end
