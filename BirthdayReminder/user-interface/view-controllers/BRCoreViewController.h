//
//  BRCoreViewController.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 05/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "LangManager.h"

#import "MBProgressHUD.h"

@interface BRCoreViewController : UIViewController
{
    MBProgressHUD *HUD;
}
@property(nonatomic, strong)NSDictionary* lang;
- (IBAction)cancelAndDismiss:(id)sender;
- (IBAction)saveAndDismiss:(id)sender;
-(void)handleErrMsg:(NSString*) errMsg;
-(void)showHud:(BOOL) isAnimation;
-(void)hideHud:(BOOL) isAnimation;
@end
