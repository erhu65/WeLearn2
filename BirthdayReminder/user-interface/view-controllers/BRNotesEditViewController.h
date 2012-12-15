//
//  BRNotesEditViewController.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 05/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRCoreViewController.h"
@class BRDBirthday;

typedef void(^BRNotesEditViewControllerCompletionBlock)(BOOL isSuccess, NSString* str);

@interface BRNotesEditViewController : BRCoreViewController <UITextViewDelegate>

@property(nonatomic,strong) BRDBirthday *birthday;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property(nonatomic, copy)BRNotesEditViewControllerCompletionBlock complectionBlock;
@end
