#include <sys/types.h>
#include <sys/sysctl.h>

#import "AppDelegate+FCMPlugin.h"

#import <Cordova/CDV.h>
#import "FCMPlugin.h"
#import "Firebase.h"

@interface FCMPlugin () {}
@end

@implementation FCMPlugin

@synthesize token;
static BOOL notificatorReceptorReady = NO;
static BOOL appInForeground = YES;

static NSString *notificationCallback = @"FCMPlugin.onNotificationReceived";
static NSString *tokenRefreshCallback = @"FCMPlugin.onTokenRefreshReceived";
static FCMPlugin *fcmPluginInstance;

+ (FCMPlugin *) fcmPlugin {
    return fcmPluginInstance;
}

- (void) ready:(CDVInvokedUrlCommand *)command
{
    fcmPluginInstance = self;
    [self.commandDelegate runInBackground:^{
        
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    
}

// GET TOKEN //
- (void) getToken:(CDVInvokedUrlCommand *)command
{
    NSLog(@"getToken");
    [self.commandDelegate runInBackground:^{
        [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult * _Nullable result,
                                                            NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Error fetching remote instance ID: %@", error);
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                NSLog(@"Remote instance ID token: %@", result.token);
				[self setToken:result.token];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:result.token];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    }];
}

// UN/SUBSCRIBE TOPIC //
- (void) subscribeToTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"subscribeToTopic %@", topic);
    [self.commandDelegate runInBackground:^{
        @try {
            [[FIRMessaging messaging] subscribeToTopic:[NSString stringWithFormat:@"%@", topic]];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } @catch (NSException *ex) {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:ex.debugDescription]
                                        callbackId:command.callbackId];
        }
    }];
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT messageAsString:NULL]
                                callbackId:command.callbackId];
}

- (void) unsubscribeFromTopic:(CDVInvokedUrlCommand *)command 
{
    NSString* topic = [command.arguments objectAtIndex:0];
    NSLog(@"unsubscribeFromTopic %@", topic);
    [self.commandDelegate runInBackground:^{
        if(topic != nil)
            [[FIRMessaging messaging] unsubscribeFromTopic:[NSString stringWithFormat:@"%@", topic]];
        CDVPluginResult* pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:topic];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) registerNotification:(CDVInvokedUrlCommand *)command
{
    NSLog(@"registerNotification");
    
    notificatorReceptorReady = YES;
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    
    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) notifyOfMessage:(NSData *)payload
{
    NSString *JSONString = [[NSString alloc] initWithBytes:[payload bytes] length:[payload length] encoding:NSUTF8StringEncoding];
    NSString * notifyJS = [NSString stringWithFormat:@"%@(%@);", notificationCallback, JSONString];
    NSLog(@"notifyOfMessage %@", notifyJS);
    
    if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:notifyJS];
    } else {
        [self.webViewEngine evaluateJavaScript:notifyJS completionHandler:nil];
    }
}

-(void) notifyOfTokenRefresh:(NSString *)token
{
    NSString * notifyJS = [NSString stringWithFormat:@"%@('%@');", tokenRefreshCallback, token];
    NSLog(@"notifyOfTokenRefresh %@", notifyJS);
    
    if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:notifyJS];
    } else {
        [self.webViewEngine evaluateJavaScript:notifyJS completionHandler:nil];
    }
}

-(void) appEnterBackground
{
    NSLog(@"Set state background");
    appInForeground = NO;
}

-(void) appEnterForeground
{
    NSLog(@"Set state foreground");
    NSData* lastPush = [AppDelegate getLastPush];
    if (lastPush != nil) {
        [FCMPlugin.fcmPlugin notifyOfMessage:lastPush];
    }
    appInForeground = YES;
}

@end
