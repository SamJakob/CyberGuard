//
//  CGAUtilities.m
//  Runner
//
//  Created by Sam M. on 4/9/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

+ (NSString* _Nonnull) getSystemName {
    return [UIDevice currentDevice].systemName;
}

+ (NSString* _Nonnull) getSystemVersion {
    return [UIDevice currentDevice].systemVersion;
}

@end
