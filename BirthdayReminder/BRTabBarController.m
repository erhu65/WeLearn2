//
//  BRTabBarController.m
//  BirthdayReminder
//
//  Created by Peter2 on 1/11/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "BRTabBarController.h"

@interface BRTabBarController ()

@end

@implementation BRTabBarController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // You do not need this method if you are not supporting earlier iOS Versions
    return [self.selectedViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

-(NSUInteger)supportedInterfaceOrientations
{
    if (self.selectedViewController) 
        return [self.selectedViewController supportedInterfaceOrientations];
    
    return UIInterfaceOrientationMaskPortrait;
}

-(BOOL)shouldAutorotate
{
    return YES;
}

@end
