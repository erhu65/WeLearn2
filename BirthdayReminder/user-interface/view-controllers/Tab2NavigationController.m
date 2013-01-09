//
//  Tab2NavigationController.m
//  BirthdayReminder
//
//  Created by Peter2 on 1/8/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "Tab2NavigationController.h"
#import "MyUnwindSegue.h"

@interface Tab2NavigationController ()

@end

@implementation Tab2NavigationController


- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController fromViewController:(UIViewController *)fromViewController identifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"segueBackTovideos"])
		return [[MyUnwindSegue alloc] initWithIdentifier:identifier source:fromViewController destination:toViewController];
	else
		return [super segueForUnwindingToViewController:toViewController fromViewController:fromViewController identifier:identifier];
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

@end
