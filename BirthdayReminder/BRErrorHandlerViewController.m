//
//  BRErrorHandlerViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/12/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRErrorHandlerViewController.h"

@interface BRErrorHandlerViewController ()

@end

@implementation BRErrorHandlerViewController

-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


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


- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex {
    
    NSLog(@"recoveryOptionIndex: %d", recoveryOptionIndex);
    return NO;
}

- (IBAction)fakeNonFatalError:(id)sender
{
    NSString *description = @"Connection Error";
    NSString *failureReason = @"Can't seem to get a connection.";
    NSArray *recoveryOptions = @[@"Retry", @"Retry2"];
    NSString *recoverySuggestion = @"Check your wifi settings and retry.";
    
    NSDictionary *userInfo =
    [NSDictionary dictionaryWithObjects:@[description, failureReason, recoveryOptions, recoverySuggestion, self]
                                forKeys: @[NSLocalizedDescriptionKey,NSLocalizedFailureReasonErrorKey, NSLocalizedRecoveryOptionsErrorKey, NSLocalizedRecoverySuggestionErrorKey, NSRecoveryAttempterErrorKey]];
    
    NSError *error = [[NSError alloc] initWithDomain:@"com.hans-eric.ios6recipesbook"
                                                code:42 userInfo:userInfo];
    
    [ErrorHandler handleError:error fatal:NO];
}

- (IBAction)fakeFatalError:(id)sender
{
    NSString *description = @"Data Error";
    NSString *failureReason = @"Data is corrupt. The app must shut down.";
    NSString *recoverySuggestion = @"Contact support!";
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjects:@[description, failureReason, recoverySuggestion] forKeys:@[NSLocalizedDescriptionKey, NSLocalizedFailureReasonErrorKey, NSLocalizedRecoverySuggestionErrorKey]];
    
    NSError *error = [[NSError alloc] initWithDomain:@"com.hans-eric.ios6recipesbook"
                                                code:22 userInfo:userInfo];
    [ErrorHandler handleError:error fatal:YES];
}

- (IBAction)throwFakeException:(id)sender
{
    NSException *e = [[NSException alloc] initWithName:@"FakeException" reason:@"The developer sucks!" userInfo:[NSDictionary dictionaryWithObject:@"Extra info" forKey:@"Key"]];
    [e raise];
}

@end
