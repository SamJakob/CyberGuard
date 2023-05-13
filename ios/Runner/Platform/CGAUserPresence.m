//
//  CGAUserPresence.m
//  Runner
//
//  Created by Sam M. on 5/12/23.
//

#import <Foundation/Foundation.h>

#import "CGAUserPresence.h"

#import "Runner-Swift.h"

// ----

/// The version of the platform channel implementation this service is implementing.
/// Bump only for breaking changes.
#define CHANNEL_IMPL_VERSION 1

// ----

#define METHOD_CALL_NAME call.method
#define METHOD_CALL_IS(name) [name isEqualToString:METHOD_CALL_NAME]

#define METHOD_CHANNEL_HANDLER(name) if (METHOD_CALL_IS(name))
#define BULK_METHOD_CHANNEL_HANDLER(...) if ([@[__VA_ARGS__] containsObject:METHOD_CALL_NAME])


@implementation CGAUserPresencePlatformHandler

+ (CGAUserPresencePlatformHandler* _Nonnull) bind:(FlutterViewController* _Nonnull) controller withName:(NSString* _Nonnull) name {
    // Create a platform channel for secure storage.
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                                  methodChannelWithName:name
                                                  binaryMessenger:controller.binaryMessenger];
    
    // Create a CGASecureStoragePlatformHandler class to handle the incoming platform channel
    // messages.
    CGAUserPresencePlatformHandler* handler = [[CGAUserPresencePlatformHandler alloc] initWithChannel:channel];
    
    // Set the handler to the appropriate method from the handler class.
    [channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [handler handle:call result:result];
    }];
    
    return handler;
}

- (instancetype _Nonnull) initWithChannel:(FlutterMethodChannel* _Nonnull) channel {
    if (self = [super init]) {
        self.channel = channel;
#if !TARGET_OS_SIMULATOR
        self.userPresenceDelegate = [[CGAUserPresenceDelegate alloc] init];
#endif
    }
    
    return self;
}

- (void) handle:(FlutterMethodCall* _Nonnull) call result:(FlutterResult _Nonnull) result {
    
    METHOD_CHANNEL_HANDLER(@"ping") {
        
        // If the device is not a simulator, return early with an error if the
        // delegate indicates one.
        
        // The simulator technically supports the ability to simulate biometric
        // authentication, however this would make testing the app cumbersome to
        // use, so we'll skip it for the simulator only.
#if !TARGET_OS_SIMULATOR
        NSString* _Nullable functionalityError = [self.userPresenceDelegate checkFunctionality];
        
        if (functionalityError) {
            result([FlutterError errorWithCode:@"USER_PRESENCE_FAILURE"
                                       message:functionalityError
                                       details:nil]);
            return;
        }
#endif

        // Otherwise, if the device is a simulator OR if the device supports
        // biometric authentication, reply to the ping to indicate device
        // support.
        result(@{
            @"ping": @"pong",
            @"version": @(CHANNEL_IMPL_VERSION),
            
            @"is_simulator": [NSNumber numberWithBool:TARGET_OS_SIMULATOR == 1],
        });
        
    }
    
    METHOD_CHANNEL_HANDLER(@"cancelVerifyUserPresence") {
#if TARGET_OS_SIMULATOR
        // If the device is a simulator, immediately return with true.
        result([NSNumber numberWithBool:true]);
#else
        [self.userPresenceDelegate cancelVerifyUserPresenceWithCompletionHandler:^(BOOL response) {
            result([NSNumber numberWithBool:response]);
        }];
#endif
    }
    
    METHOD_CHANNEL_HANDLER(@"verifyUserPresence") {
#if TARGET_OS_SIMULATOR
        // If the device is a simulator, immediately return with true.
        result([NSNumber numberWithBool:true]);
#else
        [self.userPresenceDelegate verifyUserPresenceWithCompletionHandler:^(BOOL response) {
            if (response) {
                return result([NSNumber numberWithBool:true]);
            } else {
                return result([FlutterError errorWithCode:@"USER_PRESENCE_FAILURE"
                                                  message:@"There was a problem checking your identity."
                                                  details:nil]);
            }
        }];
#endif
    }
    
}

@end
