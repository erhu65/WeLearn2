//
//  Tab3NavigationController.m
//  BirthdayReminder
//
//  Created by Peter2 on 1/9/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "Tab3NavigationController.h"
#import "MyUnwindSegue.h"

@interface Tab3NavigationController ()

@end

@implementation Tab3NavigationController


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
}@end
