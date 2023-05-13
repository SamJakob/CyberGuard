//
//  CGAUserPresence.h
//  Runner
//
//  Created by Sam M. on 5/12/23.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

#import <Runner-Swift.h>

#pragma once

@interface CGAUserPresencePlatformHandler : NSObject

@property (nonatomic, retain) FlutterMethodChannel* _Nonnull channel;
@property CGAUserPresenceDelegate* _Nonnull userPresenceDelegate;

/**
 * Allocates a ``CGAUserPresencePlatformHandler`` implementation for the Platform Channel interface.
 */
+ (CGAUserPresencePlatformHandler* _Nonnull) bind:(FlutterViewController* _Nonnull) controller withName:(NSString* _Nonnull) name;

- (instancetype _Nonnull) init NS_UNAVAILABLE __attribute__((unavailable("Use -initWithChannel instead.")));

- (instancetype _Nonnull) initWithChannel:(FlutterMethodChannel* _Nonnull) channel;

- (void) handle:(FlutterMethodCall* _Nonnull) call result:(FlutterResult _Nonnull) result;

@end
