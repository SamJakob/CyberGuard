//
//  SecureStorage.m
//  Runner
//
//  Created by Sam M. on 4/6/23.
//

#import "CGASecureStorage.h"
#import "CGAUtilities.h"

#import "Runner-Swift.h"

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
    
    METHOD_CHANNEL_HANDLER(@"enhancedSecurityStatus") {
        result(@([CGASecureStorageCKDelegate deviceHasSecureEnclave]));
    }
    
    METHOD_CHANNEL_HANDLER(@"generateKey") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        // Attempt to make make the method call, handle an error that occurs.
        NSError* error;
        [CGASecureStorageCKDelegate generateKeyWithName:name error:&error completionHandler:^(NSString * _Nullable publicKey) {
            if (error != nil) {
                NSLog(@"%@", error);
                return result([FlutterError errorWithCode:@"KEY_GENERATION_FAILURE"
                                                  message:@"There was a problem generating the encryption key."
                                                  details:nil]);
            }
            
            // Otherwise, if it's all good return the base-64 encoded public key.
            return result(publicKey);
        }];
    }
    
    METHOD_CHANNEL_HANDLER(@"deleteKey") {
        // Get the name from the method call arguments, however if it is NSNull (the ObjC boxed null type)
        // set it to nil instead.
        NSString* _Nullable name = call.arguments[@"name"];
        if (name == (id)[NSNull null]) {
            name = nil;
        }
        
        // Attempt to make make the method call, handle an error that occurs.
        NSError* error;
        [CGASecureStorageCKDelegate deleteKeyWithName:name error:&error];
        
        if (error != nil) {
            NSLog(@"%@", error);
            return result([FlutterError errorWithCode:@"KEY_GENERATION_FAILURE"
                                              message:@"There was a problem generating the encryption key."
                                              details:nil]);
        }
        
        return result(nil);
    }
    
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
        
        // Attempt to perform the decryption, returning the decrypted result if successful,
        // otherwise return an error.
        NSError* error;
        
        // Call the CryptoKit delegate to perform the decryption.
        NSData* response;
        
        void (^completionHandler)(NSData* _Nullable) = ^(NSData* _Nullable response) {
            if (error != nil) {
                NSLog(@"%@", error);
                return result([FlutterError errorWithCode:@"DECRYPTION_FAILURE"
                                                  message:[NSString stringWithFormat:@"There was a problem with the %@ operation.", METHOD_CALL_NAME]
                                                  details:nil]);
            }
            
            return result(response != nil ? [FlutterStandardTypedData typedDataWithBytes:response] : nil);
        };
        
        if (METHOD_CALL_IS(@"encrypt")) {
            response = [CGASecureStorageCKDelegate encryptWithKey:name data:data error:&error];
            return completionHandler(response);
        } else if (METHOD_CALL_IS(@"decrypt")) {
            return [CGASecureStorageCKDelegate decryptWithKey:name data:data error:&error completionHandler:completionHandler];
        }
    }
    
}

@end
