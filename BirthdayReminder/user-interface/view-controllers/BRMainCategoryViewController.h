//
//  BRMainCategoryViewController.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/16/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"

@interface BRMainCategoryViewController : BRCoreViewController
<UITableViewDelegate, UITableViewDataSource,UIScrollViewDelegate>


@property(nonatomic, strong)NSNumber* page;
@property(nonatomic, strong)NSNumber* lastPage;

@property(nonatomic, weak)IBOutlet UITableView* tb;


@end
