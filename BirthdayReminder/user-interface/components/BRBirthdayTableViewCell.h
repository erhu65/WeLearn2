//
//  BRBirthdayTableViewCell.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 27/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//


@class BRDBirthday;
@class BRDBirthdayImport;

@interface BRBirthdayTableViewCell : UITableViewCell

@property(nonatomic,strong) BRDBirthday *birthday;
@property(nonatomic,strong) BRDBirthdayImport *birthdayImport;
@property(nonatomic, strong) NSIndexPath* indexPath;
@property BOOL isSelected;
@property (nonatomic, weak) IBOutlet UIImageView* iconView;
@property (nonatomic, weak) IBOutlet UIImageView* remainingDaysImageView;
@property (nonatomic, weak) IBOutlet UILabel* nameLabel;
@property (nonatomic, weak) IBOutlet UILabel* birthdayLabel;
@property (nonatomic, weak) IBOutlet UILabel* remainingDaysLabel;
@property (nonatomic, weak) IBOutlet UILabel* remainingDaysSubTextLabel;

@end
