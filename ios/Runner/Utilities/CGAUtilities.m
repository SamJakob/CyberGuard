//
//  CGAUtilities.m
//  Runner
//
//  Created by Sam M. on 4/9/23.
//

#import <Foundation/Foundation.h>

#import "CGAUtilities.h"

@implementation CGAUtilities : NSObject

+ (NSDictionary* _Nonnull) getBundleInfo {
    return [[NSBundle mainBundle] infoDictionary];
}

+ (NSString* _Nonnull) getBundleIdentifier {
    return [[CGAUtilities getBundleInfo] objectForKey:@"CFBundleIdentifier"];
}

+ (NSString* _Nonnull) getBundleName {
    return [[CGAUtilities getBundleInfo] objectForKey:@"CFBundleDisplayName"];
}

@end
