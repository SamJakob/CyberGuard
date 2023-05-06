//
//  SecureStorage.m
//  Runner
//
//  Created by Sam M. on 4/6/23.
//

#import <Foundation/Foundation.h>

#import "CGASecureStorage.h"
#import "CGAUtilities.h"

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

@implementation CGASecureStoragePlatformHandler

+ (CGASecureStoragePlatformHandler* _Nonnull) bind:(FlutterViewController* _Nonnull) controller withName:(NSString* _Nonnull) name {
    // Create a platform channel for secure storage.
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                                  methodChannelWithName:name
                                                  binaryMessenger:controller.binaryMessenger];
    
    // Create a CGASecureStoragePlatformHandler class to handle the incoming platform channel
    // messages.
    CGASecureStoragePlatformHandler* handler = [[CGASecureStoragePlatformHandler alloc] initWithChannel:channel];
    
    // Set the handler to the appropriate method from the handler class.
    [channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [handler handle:call result:result];
    }];
    
    return handler;
}

- (instancetype _Nonnull) initWithChannel:(FlutterMethodChannel* _Nonnull) channel {
    if (self = [super init]) {
        self.channel = channel;
    }
    
    return self;
}

- (void) handle:(FlutterMethodCall* _Nonnull) call result:(FlutterResult _Nonnull) result {
    
    METHOD_CHANNEL_HANDLER(@"ping") {
        result(@{
            @"ping": @"pong",
            
            @"platform": @"Darwin (iOS)",
            @"version": @(CHANNEL_IMPL_VERSION),
            @"is_simulator": [NSNumber numberWithBool:TARGET_OS_SIMULATOR == 1],
            
            @"has_enhanced_security": @([CGASecureStorageDelegate deviceHasSecureEnclave])
        });
    }
    
    /// Returns the storage location for encrypted files.
    METHOD_CHANNEL_HANDLER(@"getStorageLocation") {
        result(NSHomeDirectory());
    }
    
    /// Returns true if enhanced security status is available (i.e., in the presence of a Secure Enclave), otherwise false.
    METHOD_CHANNEL_HANDLER(@"enhancedSecurityStatus") {
        result(@([CGASecureStorageDelegate deviceHasSecureEnclave]));
    }
    
    /// Checks if a key with the specified name exists in the device keychain. Returns true if it does, otherwise false.
    /// Name is optional. It defaults to ``kDefaultPKKey``.
    METHOD_CHANNEL_HANDLER(@"keyExists") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        NSError* error;
        CGAKeyExistsStatusWrapper* wrapper = [CGASecureStorageDelegate checkKeyExistsWithName:name error:&error];
        
        if (error != nil) {
            return result([FlutterError errorWithCode:@"KEY_LOOKUP_FAILURE"
                                              message:@"There was a problem checking if the specified key exists."
                                              details:nil]);
        }
        
        result(@([wrapper status] == CGAKeyExistsStatusFound));
    }
    
    /// Generates a new key with the specified name. If the key already exists, this does nothing unless `overwriteIfExists` is set to true,
    /// in which case it will overwrite the existing entry for the specified name with a new key.
    /// Name is optional. It defaults to ``kDefaultPKKey``.
    METHOD_CHANNEL_HANDLER(@"generateKey") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        // Check if overwriteIfExists has been specified. Use it if it has, otherwise resort to false (i.e., generate
        // a new key, destroying old keys if they exist).
        BOOL overwriteIfExists = false;
        NSNumber* _Nullable overwriteIfExistsRaw = call.arguments[@"overwriteIfExists"];
        if (overwriteIfExistsRaw != (id)[NSNull null]) { overwriteIfExists = overwriteIfExistsRaw; }
        
        // Attempt to make make the method call, handle an error that occurs.
        [CGASecureStorageDelegate generateKeyWithName:name overwriteIfExists:overwriteIfExists completionHandler:^(NSError* error) {
            if (error != nil) {
                return result([FlutterError errorWithCode:@"KEY_GENERATION_FAILURE"
                                                  message:@"There was a problem generating the encryption key."
                                                  details:nil]);
            }
            
            // Otherwise, if it's all good return with no error.
            return result(nil);
        }];
    }
    
    /// Deletes the key with the specified name. Does nothing if the key does not exist.
    /// Name is optional. It defaults to ``kDefaultPKKey``.
    METHOD_CHANNEL_HANDLER(@"deleteKey") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        // Attempt to make make the method call, handle an error that occurs.
        NSError* error;
        [CGASecureStorageDelegate deleteKeyWithName:name error:&error];
        
        if (error != nil) {
            NSLog(@"%@", error);
            return result([FlutterError errorWithCode:@"KEY_GENERATION_FAILURE"
                                              message:@"There was a problem generating the encryption key."
                                              details:nil]);
        }
        
        return result(nil);
    }
    
    /// Performs encryption and decryption with the key specified by `name`.
    /// Name is optional. It defaults to ``kDefaultPKKey``.
    /// The data should be a `Uint8List` stored in `data`.
    BULK_METHOD_CHANNEL_HANDLER(@"encrypt", @"decrypt") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        // Get the payload to decrypt.
        FlutterStandardTypedData* _Nonnull dataParameter = call.arguments[@"data"];
        if (dataParameter == (id)[NSNull null]) {
            return result([FlutterError errorWithCode:@"BAD_ARGUMENT"
                                              message:@"You must specify the 'data' argument."
                                              details:nil]);
        }
        
        // Convert the payload to NSData.
        NSData* data = [dataParameter data];
        
        void (^completionHandler)(NSData* _Nullable, NSError* _Nullable) = ^(NSData* _Nullable response, NSError* _Nullable error) {
            if (error != nil) {
                NSLog(@"%@", error);
                return result([FlutterError errorWithCode:@"DECRYPTION_FAILURE"
                                                  message:[NSString stringWithFormat:@"There was a problem with the %@ operation.", METHOD_CALL_NAME]
                                                  details:nil]);
            }
            
            return result(response != nil ? [FlutterStandardTypedData typedDataWithBytes:response] : nil);
        };
        
        if (METHOD_CALL_IS(@"encrypt")) {
            // Attempt to perform the encryption, returning the encrypted result if successful,
            // otherwise return an error.
            NSError* error;
            
            // Call the Secure Storage delegate to perform the decryption.
            NSData* response = [CGASecureStorageDelegate encryptWithKey:name data:data error:&error];
            
            return completionHandler(response, error);
        } else if (METHOD_CALL_IS(@"decrypt")) {
            return [CGASecureStorageDelegate decryptWithKey:name data:data completionHandler:completionHandler];
        }
    }
    
}

@end
