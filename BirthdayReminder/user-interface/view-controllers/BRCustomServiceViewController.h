//
//  BRCustomServiceViewController.h
//  BirthdayReminder
//
//  Created by Peter2 on 1/15/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"
#import "V8HorizontalPickerView.h"

@class BRRecordFriend;
@class V8HorizontalPickerView;

@interface BRCustomServiceViewController : BRCoreViewController
@property(nonatomic, strong)BRRecordFriend* fbFriend;

@end
