//
//  BRImportFacebookViewController.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 12/08/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

//
//  BRImportViewController.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 09/08/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRFBFriendListViewController.h"
#import "BRPostToFacebookWallViewController.h"
#import "BRVideoViewController.h"
#import "BRRecordFriend.h"
#import "BRCellFriend.h"
#import "BRDBirthdayImport.h"

@interface BRFBFriendListViewController ()
<UITableViewDelegate, UITableViewDataSource,
UIAlertViewDelegate>
//Keeps track of selected rows
@property(nonatomic, strong)NSMutableArray* docs;
@property (nonatomic, strong) NSMutableDictionary *selectedIndexPathToBirthday;
@property(nonatomic, strong)UIAlertView* avInviteFriend;
@property(nonatomic, weak)BRRecordFriend* selectedRecord;
@end

@implementation BRFBFriendListViewController



-(NSMutableArray*)docs{
    
    if(nil == _docs){
        _docs = [[NSMutableArray alloc] init];
    }
    return _docs;
}



-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(handleFacebookBirthdaysDidUpdate:) 
     name:BRNotificationFacebookBirthdaysDidUpdate 
     object:[BRDModel sharedInstance]];
    
    if(self.docs.count == 0 
       || nil == kSharedModel.facebookAccount
       ){
        [self showHud:YES];
        [kSharedModel fetchFacebookBirthdays];//fetch friends list form ios SDK first,
        //then to get the access_token to get another list form node.js server
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

#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.docs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCellFriend *brTableCell =  (BRCellFriend *)[self.tableView dequeueReusableCellWithIdentifier:@"CellFriend"];
    
    BRRecordFriend *record = self.docs[indexPath.row];
    brTableCell.indexPath = indexPath;
    brTableCell.record = record;
    
    return brTableCell;
}

#pragma mark UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //prevent toggle the select record, we don't need it here
    return;
}

-(void)handleFacebookBirthdaysDidUpdate:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString* error = userInfo[@"error"];
    if(nil != error){
        [self showMsg:error type:msgLevelError];
        return;
    }
    
    NSMutableArray* birthdays = userInfo[@"birthdays"];
    if(birthdays.count == 0) {
    
        
        [self hideHud:YES];
        return;
    }
    __weak __block BRFBFriendListViewController *weakSelf = self;
    [kSharedModel fetchFbFriendsWithVideosCount:kSharedModel.access_token fbId:kSharedModel.fbId withBlock:^(NSDictionary* res){
        NSString* errMsg = res[@"error"];
        if(nil != errMsg){
            [self handleErrMsg:errMsg];
        } else  {
            NSMutableArray* mArrTemp =(NSMutableArray*)res[@"mArrTemp"];
            NSRange range = NSMakeRange(0, mArrTemp.count); 
            NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:range];
            [weakSelf.docs removeAllObjects];
            [weakSelf.docs insertObjects:mArrTemp atIndexes:indexes];
            [weakSelf.tableView reloadData];
            [weakSelf hideHud:YES];
        }     

    }];
}
#pragma mark UIAlertViewDelegate 
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
    if(alertView == self.avInviteFriend){
        
        if([title isEqualToString:kSharedModel.lang[@"actionOK"]]){
            
            UINavigationController *navigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"PostToFacebookWall"];
            BRPostToFacebookWallViewController *facebookWallViewController  = (BRPostToFacebookWallViewController *) navigationController.topViewController;
            facebookWallViewController.facebookID = self.selectedRecord.fbId;
            facebookWallViewController.initialPostText = kSharedModel.lang[@"actionCheckOutWeLearnApp"];
            [self.navigationController presentViewController:navigationController animated:YES completion:nil];
            
        }
    }
}

#pragma mark Segues
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
	if ([identifier isEqualToString:@"segueVideos"])
	{
        BRCellFriend *cell =  (BRCellFriend *)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        BRRecordFriend* record =  self.docs[indexPath.row];
        
        if([record.count integerValue] == 0){
            self.selectedRecord = record;
            self.avInviteFriend = [[UIAlertView alloc]
              initWithTitle:kSharedModel.lang[@"info"]
              message:kSharedModel.lang[@"actionInviteFriend"]
              delegate:self
              cancelButtonTitle:kSharedModel.lang[@"actionOK"]
              otherButtonTitles:kSharedModel.lang[@"actionCancel"], nil];
            [self.avInviteFriend show];
            
            return NO;
        }
		
	}
	return YES;
}
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *identifier = segue.identifier;
    
    if ([identifier isEqualToString:@"segueVideos"]) {
        
        BRCellFriend *cell =  (BRCellFriend *)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        BRRecordFriend* record =  self.docs[indexPath.row];
        BRVideoViewController* BRVideoViewController = segue.destinationViewController;
        BRVideoViewController.fbFriend = record;

    }
}



@end
