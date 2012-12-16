//
//  BRCoreViewController.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 05/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"


@interface BRCoreViewController ()
{
    

}

@end

@implementation BRCoreViewController


-(id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super initWithCoder:aDecoder];
    if(self){
        self.lang = [LangManager sharedManager].dic;
        
    }
    return self;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor grayColor];
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"app-background.png"]];
    [self.view insertSubview:backgroundView atIndex:0];
    
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
   if(HUD!= nil){
      [HUD hide:NO];
    }
}

-(IBAction)cancelAndDismiss:(id)sender
{
    NSLog(@"Cancel");
    [self dismissViewControllerAnimated:YES completion:^{
        //view controller dismiss animation completed
    }];
}

- (IBAction)saveAndDismiss:(id)sender
{
    NSLog(@"Save");
    [self dismissViewControllerAnimated:YES completion:^{
        //view controller dismiss animation completed
    }];
}


-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        
        self.view = nil;
    }
}

-(void)handleErrMsg:(NSString*) errMsg{

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.lang[@"error"] message:errMsg delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
}

-(void)showHud:(BOOL) isAnimation{
    
    if(HUD!= nil){
        [HUD hide:NO];
    }    

    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    [HUD show:isAnimation];
}
-(void)hideHud:(BOOL) isAnimation{
    [HUD hide:isAnimation];
    if(HUD!= nil){
        HUD = nil;
    }   
}
@end
