//
//  BRCellSubCategory.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/17/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

@class BRRecordSubCategory;

@interface BRCellSubCategory : UITableViewCell

@property(nonatomic, strong)BRRecordSubCategory* record;
@property(nonatomic, strong)NSIndexPath* indexPath;
@property(nonatomic, weak)IBOutlet UILabel* nameLb;
@property(nonatomic, weak)IBOutlet UILabel* descLb;

@end
