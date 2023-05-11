//
//  CGAUtilities.h
//  Runner
//
//  Created by Sam M. on 4/9/23.
//

#import <Foundation/Foundation.h>

#pragma once

@interface CGAUtilities : NSObject

/**
 * Abstraction over mainBundle to get the info dictionary.
 */
+ (NSDictionary* _Nonnull) getBundleInfo;

/**
 * Wrapper around +getBundleInfo to get NSString CFBundleIdentifier.
 */
+ (NSString* _Nonnull) getBundleIdentifier;

/**
 * Wrapper around +getBundleInfo to get NSString CFBundleDisplayName.
 */
+ (NSString* _Nonnull) getBundleName;

/**
 * Wrapper around UIKit to get the system name.
 */
+ (NSString* _Nonnull) getSystemName;

/**
 * Wrapper around UIKit to get the system version.
 */
+ (NSString* _Nonnull) getSystemVersion;

@end
