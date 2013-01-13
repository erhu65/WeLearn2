//
//  BRAppDelegate.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 22/06/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "WebViewJavascriptBridge.h"
#import "Utils.h"
@interface BRAppDelegate : UIResponder <UIApplicationDelegate>


@property (strong, nonatomic) UIWindow *window;
@property(strong, nonatomic)NSString* token;

@property (strong, nonatomic) UIWebView *webview;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@end
