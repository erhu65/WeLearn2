//
//  BRCoreViewController.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 05/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"

typedef enum videosFilterMode {
    videosFilterModeAll = 0,
    videosFilterModeFavorite = 1
} videosFilterMode;


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
-(void)viewWillAppear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleFacebookMeDidUpdate:) name:BRNotificationFacebookMeDidUpdate object:[BRDModel sharedInstance]];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationFacebookMeDidUpdate object:[BRDModel sharedInstance]];
    
   if(nil != HUD){
      [HUD hide:NO];
    }
    [self _findAndResignFirstResponder:self.view];
    //prevent crash when clicking tab veray quickly...
    
}

-(BOOL) _findAndResignFirstResponder:(UIView *)theView{
    if([theView isFirstResponder]){
        [theView resignFirstResponder];
        return YES;
    }
    for(UIView *subView in theView.subviews){
        if([self _findAndResignFirstResponder:subView]){
            return YES;
        }
    }
    return NO;
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

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.lang[@"error"] message:errMsg delegate:nil cancelButtonTitle:self.lang[@"actionDimiss"]  otherButtonTitles:nil];
    [alert show];
}
-(void)showMsg:(NSString*)msg type:(msgLevel)level{

    NSString* levelStr;
    switch (level) {
        case msgLevelInfo:
            levelStr = self.lang[@"info"];
            break;
        case msgLevelWarn:
            levelStr = self.lang[@"warn"];
            break;
        case msgLevelError:
            levelStr = self.lang[@"error"];
            break;
        default:
            levelStr = self.lang[@"info"];
            break;
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:levelStr message:msg delegate:nil cancelButtonTitle:self.lang[@"actionDimiss"]  otherButtonTitles:nil];
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

-(void)navigationBack:(id)sender  {
    [self.navigationController popViewControllerAnimated:YES];

}


-(void)_handleFacebookMeDidUpdate:(NSNotification *)notification
{
    [self hideHud:YES];  
    NSDictionary *userInfo = [notification userInfo];
    NSString* error = userInfo[@"error"];
    NSString* msg = userInfo[@"msg"];
    if(nil != error){
        [self showMsg:error type:msgLevelWarn]; 
        
        return;
    }
    
    if(nil != msg){
        [self showMsg:msg type:msgLevelInfo]; 
        return;
    } 

    
    
}


@end
