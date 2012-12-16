//
//  BRCellMainCategory.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/16/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import <UIKit/UIKit.h>
@class BRRecordMainCategory;

@interface BRCellMainCategory : UITableViewCell


@property(nonatomic, strong)BRRecordMainCategory* record;
@property(nonatomic, strong)NSIndexPath* indexPath;
@property(nonatomic, weak)IBOutlet UILabel* nameLb;
@property(nonatomic, weak)IBOutlet UILabel* descLb;

@end
