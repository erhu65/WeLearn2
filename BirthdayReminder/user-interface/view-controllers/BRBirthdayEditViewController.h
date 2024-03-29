//
//  BRBirthdayEditViewController.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 05/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRCoreViewController.h"
@class BRDBirthday;


typedef void(^BRBirthdayEditViewControllerCompletionBlock)(BOOL isSuccess, NSString* str);

@interface BRBirthdayEditViewController : BRCoreViewController <UITextFieldDelegate,UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property(nonatomic,strong) BRDBirthday *birthday;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UILabel *includeYearLabel;
@property (weak, nonatomic) IBOutlet UISwitch *includeYearSwitch;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker;
@property (weak, nonatomic) IBOutlet UIView *photoContainerView;
@property (weak, nonatomic) IBOutlet UILabel *picPhotoLabel;
@property (weak, nonatomic) IBOutlet UIImageView *photoView;
@property(nonatomic, copy)BRBirthdayEditViewControllerCompletionBlock complectionBlock;


- (IBAction)didChangeNameText:(id)sender;
- (IBAction)didToggleSwitch:(id)sender;
- (IBAction)didChangeDatePicker:(id)sender;
- (IBAction)didTapPhoto:(id)sender;

@end
