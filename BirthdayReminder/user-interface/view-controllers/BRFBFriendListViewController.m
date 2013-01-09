//
//  BRImportFacebookViewController.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 12/08/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRFBFriendListViewController.h"
#import "BRVideoViewController.h"
#import "BRCellFriend.h"
@interface BRFBFriendListViewController ()

@end

@implementation BRFBFriendListViewController

-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(handleFacebookBirthdaysDidUpdate:) 
     name:BRNotificationFacebookBirthdaysDidUpdate 
     object:[BRDModel sharedInstance]];
    if(kSharedModel.mArrFriends.count == 0){
     [kSharedModel fetchFacebookBirthdays];
    }
    self.title = kSharedModel.lang[@"titleFriendsFavoriteVideos"];

}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] 
     removeObserver:self 
     name:BRNotificationFacebookBirthdaysDidUpdate 
     object:[BRDModel sharedInstance]];
}

-(void)handleFacebookBirthdaysDidUpdate:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    self.birthdays = userInfo[@"birthdays"];
    [self.tableView reloadData];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
    //prevent toggle the select record, we don't need it here
    return;
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}


#pragma mark Segues
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *identifier = segue.identifier;
    
    if ([identifier isEqualToString:@"segueVideos"]) {

        BRCellFriend *cell =  (BRCellFriend *)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        BRDBirthday* record =  self.birthdays[indexPath.row];
        BRVideoViewController* BRVideoViewController = segue.destinationViewController;
        BRVideoViewController.fbFriend = record;
//        
//        BRVideoViewController *BRVideoViewController = segue.destinationViewController;
//        BRVideoViewController.currentSelectSubCategory = record;
//        BRVideoViewController.subCategoriesSelectedUid = record.uid;
//        BRVideoViewController.currentSelectMainCategory = self.currentSelectMainCategory;
//        BRVideoViewController.mainCategoriesSelectedUid = self.mainCategoriesSelectedUid;
        
    }
}


@end
