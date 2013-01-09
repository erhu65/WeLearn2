//
//  BRVideoViewController.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"


@interface BRVideoViewController : BRCoreViewController


@property(nonatomic, strong)NSString* mainCategoriesSelectedUid;
@property(nonatomic, strong)BRRecordMainCategory* currentSelectMainCategory;


@property(nonatomic, strong)NSString* subCategoriesSelectedUid;
@property(nonatomic, strong)BRRecordSubCategory* currentSelectSubCategory;

-(IBAction)unwindBackToBRVideoViewController:(UIStoryboardSegue *)segue;
@end
