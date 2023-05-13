#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"

#import "Platform/CGASecureStorage.h"
#import "Platform/CGAUserPresence.h"

// ---

#define CHANNEL_PREFIX "com.samjakob.cyberguard"
#define SECURE_STORAGE_CHANNEL  (CHANNEL_PREFIX "/secure_storage")
#define USER_PRESENCE_CHANNEL   (CHANNEL_PREFIX "/user_presence")

// ---

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FlutterViewController* controller = (FlutterViewController*) self.window.rootViewController;
    
    // Bind to secure platform storage handler.
    [CGASecureStoragePlatformHandler bind:controller withName:@SECURE_STORAGE_CHANNEL];
    [CGAUserPresencePlatformHandler bind:controller withName:@USER_PRESENCE_CHANNEL];
    
    // Override point for customization after application launch.
    [GeneratedPluginRegistrant registerWithRegistry:self];
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
