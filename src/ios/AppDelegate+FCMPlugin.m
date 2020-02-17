//
//  AppDelegate+FCMPlugin.m
//  TestApp
//
//  Created by felipe on 12/06/16.
//
//
#import "AppDelegate+FCMPlugin.h"
#import "FCMPlugin.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "Firebase.h"

@import UserNotifications;
@import FirebaseInstanceID;
@import FirebaseMessaging;

// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>

@end

@implementation AppDelegate (FCMPlugin)

static NSData *lastPush;
NSString *const kGCMMessageIDKey = @"gcm.message_id";

//Method swizzling
+ (void)load {
    Method original =  class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method custom =    class_getInstanceMethod(self, @selector(application:customDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, custom);
}

- (BOOL)application:(UIApplication *)application customDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [self application:application customDidFinishLaunchingWithOptions:launchOptions];

    NSLog(@"DidFinishLaunchingWithOptions");
 
	if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or later display notification (sent via APNS)
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:authOptions
        completionHandler:^(BOOL granted, NSError * _Nullable error) {
            // Nothing to do
            NSLog(@"UNUserNotificationCenter ready");
        }];
        [FIRMessaging messaging].delegate = self;
	} else {
        // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
        NSLog(@"UNUserNotificationCenter ready");
	}

	[FIRApp configure];
	
	[[UIApplication sharedApplication] registerForRemoteNotifications];

    // Add observer for InstanceID token refresh callback.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:kFIRInstanceIDTokenRefreshNotification object:nil];
    return YES;
}

// Receive displayed notifications for iOS 10 devices.
// Handle incoming notification messages while app is in the foreground.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {

    NSDictionary *userInfo = notification.request.content.userInfo;
    // Print full message.
    NSLog(@"willPresentNotification: %@", userInfo);
    
    NSError *error;
    NSDictionary *userInfoMutable = [userInfo mutableCopy];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfoMutable
                                                       options:0
                                                         error:&error];
    [FCMPlugin.fcmPlugin notifyOfMessage:jsonData];
    
    // Change this to your preferred presentation option
    completionHandler(UNNotificationPresentationOptionNone);
}

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void)) completionHandler {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    // Print full message.
    NSLog(@"didReeceiveNotification: %@", userInfo);
    
    NSError *error;
    NSDictionary *userInfoMutable = [userInfo mutableCopy];
    [userInfoMutable setValue:@(YES) forKey:@"wasTapped"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfoMutable
                                                        options:0
                                                        error:&error];
    lastPush = jsonData;
    completionHandler();
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"didReceiveRemoteNotification: %@", userInfo);
    
    NSError *error;
    NSDictionary *userInfoMutable = [userInfo mutableCopy];
    
    if (application.applicationState != UIApplicationStateActive) {
        [userInfoMutable setValue:@(YES) forKey:@"wasTapped"];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfoMutable
                                                           options:0
                                                             error:&error];
		NSLog(@"App not Active - saved data: %@", jsonData);
        lastPush = jsonData;
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.

    // Pring full message.
    NSLog(@"didReceiveRemoteNotification: %@", userInfo);
    NSError *error;
    
    NSDictionary *userInfoMutable = [userInfo mutableCopy];
    
	//USER NOT TAPPED NOTIFICATION
    if (application.applicationState == UIApplicationStateActive) {
        [userInfoMutable setValue:@(NO) forKey:@"wasTapped"];
        NSLog(@"App active");
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfoMutable
                                                           options:0
                                                             error:&error];
        [FCMPlugin.fcmPlugin notifyOfMessage:jsonData];
    // app is in background or in stand by (NOTIFICATION WILL BE TAPPED)
    } else {
		[userInfoMutable setValue:@(YES) forKey:@"wasTapped"];
		NSLog(@"App not active - enable wasTapped");
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfoMutable
														   options:0
															 error:&error];
		[FCMPlugin.fcmPlugin notifyOfMessage:jsonData];
	}

    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)tokenRefreshNotification:(NSNotification *)notification
{
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
	[[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult * _Nullable result,
														NSError * _Nullable error) {
		if (error != nil) {
			NSLog(@"tokenRefreshNotification Error: %@", error);
		} else {
			[FCMPlugin.fcmPlugin setToken:result.token];
			NSLog(@"tokenRefreshNotification: %@", result.token);
			[FCMPlugin.fcmPlugin notifyOfTokenRefresh:result.token];
			// Connect to FCM since connection may have failed when attempted before having a token.
			[self connectToFcm];
		}
	}];

}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FCM registration token: %@", fcmToken);
    // Notify about received token.
	[FCMPlugin.fcmPlugin setToken:fcmToken];
    NSDictionary *dataDict = [NSDictionary dictionaryWithObject:fcmToken forKey:@"token"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FCMToken" object:nil userInfo:dataDict];
    [self connectToFcm];
    // If necessary send token to application server.
}

- (void)connectToFcm {
    if ([FCMPlugin.fcmPlugin token] == nil)
        return; // Won't connect since there is no token

	[[FIRMessaging messaging] setShouldEstablishDirectChannel:TRUE];
	
	if ([[FIRMessaging messaging] isDirectChannelEstablished]) {
		NSLog(@"Connected to FCM");
		[[FIRMessaging messaging] subscribeToTopic:@"ios"];
		[[FIRMessaging messaging] subscribeToTopic:@"all"];
	}
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive");
    [FCMPlugin.fcmPlugin appEnterForeground];
    [self connectToFcm];
}

// [START disconnect_from_fcm]
- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSLog(@"applicationDidEnterBackground");
	[[FIRMessaging messaging] setShouldEstablishDirectChannel:FALSE];
    [FCMPlugin.fcmPlugin appEnterBackground];
}
// [END disconnect_from_fcm]

+(NSData*)getLastPush {
    NSData* returnValue = lastPush;
    lastPush = nil;
    return returnValue;
}

@end
