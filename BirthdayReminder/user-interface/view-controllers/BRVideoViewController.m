//
//  BRVideoViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRVideoViewController.h"
#import "BRVideoDetailViewController.h"
#import "BRCellVideo.h"
#import "BRRecordVideo.h"

#import "BRRecordMainCategory.h"
#import "BRRecordSubCategory.h"

#import "BRDModel.h"
#import "NSMutableArray+Shuffling.h"
#import "MyUnwindSegue.h"

typedef enum videoFilterMode {
    videoFilterFilterModeAll = 0,
    videoFilterFilterModeFavorite = 1,
    videoFilterFilterModeVideoFavorite = 2,
    videoFilterFilterModeVideoFavoriteFriends = 3
} videoFilterMode;

@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRVideoViewController ()
<UITableViewDelegate, 
UITableViewDataSource,
UIScrollViewDelegate,
UISearchBarDelegate,
UIAlertViewDelegate>

@property videoFilterMode mode;
@property(nonatomic, strong)NSMutableArray* docs;
@property(nonatomic, strong)NSMutableArray* docsTemp;
@property(nonatomic, strong)NSNumber* page;
@property(nonatomic, strong)NSNumber* lastPage;
@property (weak, nonatomic) IBOutlet UIButton *sortBtn;

@property(nonatomic, weak)IBOutlet UITableView* tb;

@property (weak, nonatomic) IBOutlet UILabel *sortLb;

@property (nonatomic, strong)  NSString *strSearch;
@property (nonatomic, weak) IBOutlet UIView *filterBar;
@property (nonatomic, strong)  UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *spaceBetweenFilterBarAndMainTable;
@property(nonatomic, strong)UIAlertView* av;
@end

@implementation BRVideoViewController
{
    BOOL addItemsTrigger;
    BOOL _isSearchBarOpen;
    BOOL _isConfirmToDeleteFavorite;
    
    NSArray *verticalConstraintsBeforeAnimation; 
    NSArray *verticalConstraintsAfterAnimation;
    
}

-(NSMutableArray*)docs{
    
    if(nil == _docs){
        _docs = [[NSMutableArray alloc] init];
    }
    return _docs;
}
-(NSMutableArray*)docsTemp{
    
    if(nil == _docsTemp){
        _docsTemp = [[NSMutableArray alloc] init];
    }
    return _docsTemp;
}

-(NSNumber*)page{
    if(_page == nil){
        _page = [[NSNumber alloc] initWithInt:0];
    }
    return _page;
}

-(NSNumber*)lastPage{
    if(_lastPage == nil){
        _lastPage = [[NSNumber alloc] initWithInt:0];
    }
    return _lastPage;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        self.searchBar = nil;
        self.strSearch = nil;
        self.view = nil;
    }
}


-(id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super initWithCoder:aDecoder];
    if(self){
        
        _isConfirmToDeleteFavorite = NO;
        _isSearchBarOpen = FALSE;
         self.strSearch = @"";
        
    }
    return self;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.tb.autoresizesSubviews = YES;
    
    self.sortLb.text = self.lang[@"actionSearch"];
 
    UIBarButtonItem *btnBack = [[UIBarButtonItem alloc]
                                initWithTitle:self.lang[@"actionBack"] 
                                style:UIBarButtonItemStyleBordered
                                target:self
                                action:@selector(navigationBack:)];
    self.navigationItem.leftBarButtonItem = btnBack;
    self.mode = self.tabBarController.selectedIndex;
    if(self.mode == videoFilterFilterModeVideoFavorite){
        self.title =  kSharedModel.lang[@"titleFavoriteVideos"];
        self.navigationItem.leftBarButtonItem = nil;
    } else if (self.mode == videoFilterFilterModeVideoFavoriteFriends) {
        self.title = [NSString stringWithFormat:@"%@ %@", self.fbFriend.fbName, kSharedModel.lang[@"titleWhosFavoriteVideos"]];
        
        
        
    }else {
        self.title = [NSString stringWithFormat:@"%@~%@",  self.currentSelectSubCategory.name, self.currentSelectMainCategory.name];
    }

}

-(void)navigationBack:(id)sender  {
    
//    [[BRDModel sharedInstance].videos removeAllObjects];
//    [[BRDModel sharedInstance].videosTemp removeAllObjects];
//    [BRDModel sharedInstance].currentSelectedVideo = nil;
    [super navigationBack:sender];
}
 
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVideosDidUpdate:) name:BRNotificationVideosDidUpdate object:[BRDModel sharedInstance]];
    
    if([self.docsTemp count] == 0 
       || (self.mode == videoFilterFilterModeVideoFavorite && kSharedModel.isUserVideoFavoriteNeedUpdate
           )
       || self.mode == videoFilterFilterModeVideoFavoriteFriends
       ){
        [self _handleRefreshFromFirstPage:nil];
    }
}
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationVideosDidUpdate object:[BRDModel sharedInstance]];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    PRPLog(@"%@-[%@ , %@]",
           [[UIWindow keyWindow] _autolayoutTrace],
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}
- (void)didRotateFromInterfaceOrientation: (UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:
     fromInterfaceOrientation];
    
    PRPLog(@"%@-[%@ , %@]",
           [[UIWindow keyWindow] _autolayoutTrace],
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}
-(void)_handleFacebookMeDidUpdate:(NSNotification *)notification
{
    [super _handleFacebookMeDidUpdate:notification];
    NSDictionary* userInfo = [notification userInfo];
    NSString* error = userInfo[@"error"];
    if(nil != error) return;
    
    [self _handleRefreshFromFirstPage:nil];
}
-(IBAction)_handleRefreshFromFirstPage:(id)sender{
    
    self.docs = nil;
    self.docsTemp = nil;
    
    self.page = @0;
    self.lastPage = @0;
    [self _handleRefresh];
}

-(void)_handleRefresh{
    
    [self showHud:YES];    
    __weak __block BRVideoViewController *weakSelf = self;
    if(self.mode == videoFilterFilterModeVideoFavorite
       || self.mode == videoFilterFilterModeVideoFavoriteFriends
       ){
        NSString* fbId;
        if(self.mode == videoFilterFilterModeVideoFavorite){
            fbId = kSharedModel.fbId;
        } else if(self.mode == videoFilterFilterModeVideoFavoriteFriends) {
            fbId = self.fbFriend.fbId;
        }
    
        [kSharedModel fetchUserFavoriteVideosWithPage:self.page fbId:fbId withBlock:^(NSDictionary* res){
            kSharedModel.isUserVideoFavoriteNeedUpdate = NO;
            [weakSelf hideHud:YES];
            
            NSString* error = res[@"error"];
            if(nil != error){
                [self handleErrMsg:error];
            } else {
                
                NSMutableArray* mTempArr =(NSMutableArray*)res[@"mTempArr"];
                NSRange range = NSMakeRange(0, mTempArr.count); 
                NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:range];
                [weakSelf.docsTemp insertObjects:mTempArr atIndexes:indexes];
                
                weakSelf.page = res[@"page"];
                weakSelf.lastPage = res[@"lastPage"];
                weakSelf.docs = weakSelf.docsTemp;
                if(self.docs.count > 0){
                    PRPLog(@"self.docs.count: %d-[%@ , %@]",
                           weakSelf.docs.count,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    [weakSelf.tb reloadData];
                } else {
                    [self showMsg:self.lang[@"infoNoData"] type:msgLevelInfo];
                    self.sortBtn.enabled = NO;
                }
            }
        }];
        
    } else {
    
        [kSharedModel fetchVideosWithPage:self.page withSubCategoryId:self.subCategoriesSelectedUid withBlock:^(NSDictionary* res){
            [weakSelf hideHud:YES];
            
            NSString* error = res[@"error"];
            
            if(nil != error){
                [self handleErrMsg:error];
            } else {
                NSMutableArray* mTempArr =(NSMutableArray*)res[@"mTempArr"];
                NSRange range = NSMakeRange(0, mTempArr.count); 
                NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:range];
                [weakSelf.docsTemp insertObjects:mTempArr atIndexes:indexes];
                
                weakSelf.page = res[@"page"];
                weakSelf.lastPage = res[@"lastPage"];
                weakSelf.docs = weakSelf.docsTemp;
                if(self.docs.count > 0){
                    PRPLog(@"self.docs.count: %d-[%@ , %@]",
                           weakSelf.docs.count,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    [weakSelf.tb reloadData];
                } else {
                    [self showMsg:self.lang[@"infoNoData"] type:msgLevelInfo];
                    self.sortBtn.enabled = NO;
                }
            }
        }];

    }
}

//-(void)_handleVideosDidUpdate:(NSNotification *)notification
//{
//    [self hideHud:YES];
//    NSDictionary *userInfo = [notification userInfo];
//    NSString* errMsg = userInfo[@"errMsg"];
//    self.page = userInfo[@"page"];
//    self.lastPage = userInfo[@"lastPage"];
//    
//    if(errMsg!= nil && [errMsg length] > 0){
//        
//        [self showMsg:errMsg type:msgLevelError];
//    } else {
//        PRPLog(@"[BRDModel sharedInstance].videos: %d-[%@ , %@]",
//               [BRDModel sharedInstance].videos.count,
//               NSStringFromClass([self class]),
//               NSStringFromSelector(_cmd));
//        if([BRDModel sharedInstance].videos.count > 0){
//            [self.tb reloadData];
//            self.sortBtn.enabled = YES;
//        } else {
//            [self showMsg:self.lang[@"infoNoData"] type:msgLevelInfo];
//            self.sortBtn.enabled = NO;
//        }
//    }
//}

#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.tb)
		return self.docs.count;
    else 
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"BRCellVideo";
    
	BRCellVideo *cell = (BRCellVideo*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];    
    BRRecordVideo *record = self.docs[indexPath.row];
    cell.indexPath = indexPath;
    cell.record = record; 
    [cell.btnFavorite addTarget:self action:@selector(_toggleFavoriteHandler:) forControlEvents:UIControlEventTouchUpInside]; 
    if(self.mode == videoFilterFilterModeVideoFavoriteFriends){
        cell.btnFavorite.enabled = NO;
        cell.btnFavorite.hidden = YES;
    }
    
//    
//    if(self.mode == videoFilterFilterModeAll){
//
//
//    } else {
//        cell.btnFavorite.hidden = YES;
//        cell.btnFavorite.enabled = NO;
//    }
    
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    //BRRecordVideo *record = [BRDModel sharedInstance].videos[indexPath.row];
}

-(void)_toggleFavoriteHandler:(UIButton*)sender{
    
    int selectedRow = sender.tag;
    __block BRRecordVideo *record = self.docs[selectedRow];
    
    if(record.isUserFavorite && !_isConfirmToDeleteFavorite){
        
        self.av = [[UIAlertView alloc] initWithTitle:kSharedModel.lang[@"warn"]
                                             message:kSharedModel.lang[@"warnAreYouSoreRemoveFavoriteVideo"]
                                            delegate:self
                                   cancelButtonTitle:kSharedModel.lang[@"actionOK"]
                                   otherButtonTitles:kSharedModel.lang[@"actionCancel"], nil];
        self.av.tag = selectedRow;
        
        [self.av show];
        return;
    }
    _isConfirmToDeleteFavorite = NO;
    
    [kSharedModel toggleFavoriteVideo:record.uid
                                      byFbid:kSharedModel.fbId 
                                 withBool:record.isUserFavorite 
                             inSelectedIndex:selectedRow WithBlock:^(NSDictionary* userinfo){
                                 NSString* error = userinfo[@"error"];
                                 if(nil != error){
                                     [self showMsg:error type:msgLevelWarn];
                                     return;
                                 }
                                 NSString* msg = userinfo[@"msg"];
                                 [self showMsg:kSharedModel.lang[msg] type:msgLevelInfo];
                                 
                                 NSNumber* updedIndex = (NSNumber*)userinfo[@"updedIndex"];
                                 if(nil != updedIndex){
                                     
                                     record.isUserFavorite = !record.isUserFavorite;
                                     NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[updedIndex integerValue] inSection:0];
                                     
                                     BRCellVideo *cell = (BRCellVideo *) [self.tb cellForRowAtIndexPath:indexPath];
                                     
                                     if(self.mode == videoFilterFilterModeAll
                                        || self.mode == videoFilterFilterModeFavorite
                                        ){
                                         kSharedModel.isUserVideoFavoriteNeedUpdate =YES;
                                         [cell toggleBtnFavoriteTitle:record.isUserFavorite];

                                     } else {
                                         if(self.mode == videoFilterFilterModeVideoFavorite){
                                             [self _handleRefreshFromFirstPage:nil];
                                         }
                                     }

                                     
                                     PRPLog(@"updedIndex: %d, record.isUserFavorite:%d you can upd the btn title-[%@ , %@]",
                                            [updedIndex integerValue],
                                            record.isUserFavorite,
                                            NSStringFromClass([self class]),
                                            NSStringFromSelector(_cmd));
                                 }
                             }];
}

#pragma mark UIAlertViewDelegate 
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
    if(alertView == self.av){
        
        if([title isEqualToString:kSharedModel.lang[@"actionOK"]]){
            
            int selectedRow = self.av.tag;
            
            UIButton* btn = [[UIButton alloc] init];
            btn.tag = selectedRow;
            _isConfirmToDeleteFavorite = YES;
            [self _toggleFavoriteHandler:btn];
            
        }
    }
}


#pragma mark UIScrollViewDelegate 
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	// Detect if the trigger has been set, if so add new items
	if (addItemsTrigger)
	{
        BOOL isLastPage = [self.lastPage boolValue];
        if(!isLastPage){
            int page_ = [self.page intValue];
            page_++;
            self.page = [[NSNumber alloc] initWithInt:page_];
            [self _handleRefresh];
        }
	}
    
	// Reset the trigger
	addItemsTrigger = NO;
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
	// Trigger the offset if the user has pulled back more than 50 pixels
	if (scrollView.contentOffset.y < -80.0f)
		addItemsTrigger = YES;
}

#pragma mark show or hide order table view
- (IBAction)filterButtonPressed:(id)sender {
    
    UIButton* btn = ( UIButton*)sender;
    btn.enabled = NO;
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        btn.enabled = YES;
    });
    
    if (!_isSearchBarOpen) [self showFilterTable];
    else [self hideFilterTable];
}

- (void)hideFilterTable {
    
    _isSearchBarOpen = FALSE;
    UIImage* img_ =  [UIImage imageNamed:@"Arrow.png"]; 
    [self.sortBtn setBackgroundImage:img_ forState:UIControlStateNormal];
    
    [self.view removeConstraints: verticalConstraintsAfterAnimation];
    [self.view addConstraints: verticalConstraintsBeforeAnimation];
    
    [UIView animateWithDuration:0.3f animations:^ {
        [self.view layoutIfNeeded]; }
                     completion:^(BOOL finished) {
                         
                         [self.searchBar removeFromSuperview]; 
                         self.searchBar = nil;
                         [self.view addConstraint: self.spaceBetweenFilterBarAndMainTable];                         
//                         if([BRDModel sharedInstance].subCategoriesSortType == subCategoriesSortTypeNoSort){
//                             
//                             [self.docs shuffle];
//                         } else {
//                             //[[BRDModel sharedInstance] subCategoriesSort];
//                         }
                         
//                         [self.tb reloadData];
                         
                     }];
    
}

- (void)showFilterTable
{
    _isSearchBarOpen = TRUE;
    UIImage* img_ =  [UIImage imageNamed:@"ArrowAsc.png"]; 
    [self.sortBtn setBackgroundImage:img_ forState:UIControlStateNormal];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.backgroundColor = [UIColor blackColor]; 
    self.searchBar.showsCancelButton = YES;
    self.searchBar.tintColor = BR_STYLE_COLOR;
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.searchBar.keyboardType = UIKeyboardTypeAlphabet;
    
    //self.searchBar.showsSearchResultsButton = YES;
    self.searchBar.delegate = self;
    [self.view addSubview:self.searchBar];
    self.searchBar.text = self.strSearch;
    
    NSDictionary *viewsDictionary = viewsDictionary = 
    @{@"searchBar": self.searchBar};
    
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[searchBar]|" options:0
                                                                   metrics:nil
                                                                     views:viewsDictionary];
    [self.view addConstraints:constraints];
    [self.view removeConstraint: self.spaceBetweenFilterBarAndMainTable];
    
    viewsDictionary = @{@"filterBar": self.filterBar,
                        @"searchBar": self.searchBar,
                        @"mainTableView": self.tb};
    
    /// this is new
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:
                   @"V:[filterBar][searchBar(0)][mainTableView]"
                                                          options:0
                                                          metrics:nil views:viewsDictionary];
    verticalConstraintsBeforeAnimation = constraints;
    [self.view addConstraints:constraints]; 
    [self.view layoutIfNeeded];
    [self.view removeConstraints:constraints]; /// until here
    
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:
                   @"V:[filterBar][searchBar(72)][mainTableView]"
                                                          options:0
                                                          metrics:nil views:viewsDictionary];
    verticalConstraintsAfterAnimation = constraints;
    [self.view addConstraints:constraints];
    
    [UIView animateWithDuration:0.3f animations:^ {
        [self.view layoutIfNeeded];

    }];
    
}

- (void)filterVideoByNameOrDesc:(NSString*)searchFor
{
    __block NSMutableArray* arrayTemp = [[NSMutableArray alloc] init];
    self.docs = nil;
    [self.docsTemp enumerateObjectsUsingBlock:^(id obj , NSUInteger idx, BOOL *stop){
        BRRecordVideo* record = (BRRecordVideo*)obj;
        if ([record.name rangeOfString:searchFor].location != NSNotFound
            ||[record.desc rangeOfString:searchFor].location != NSNotFound
            ) {
            
            [arrayTemp insertObject:record atIndex:0];
        }
        
    }];
    
    if([searchFor length]>0){
        self.docs = arrayTemp;
    } else {
        self.docs = self.docsTemp;
    }
    
}


#pragma mark UISearchBarDelegate
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchFor{
    
    PRPLog(@"searchFor: %@-[%@ , %@]",
           searchFor,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
//    [BRDModel sharedInstance].videos = nil;
//	[BRDModel sharedInstance].videos = [[BRDModel sharedInstance].videosTemp mutableCopy];
//	
    self.strSearch  = searchFor;
    [self filterVideoByNameOrDesc:self.strSearch];
    [self.tb reloadData];	
    
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    PRPLog(@" searchBar.text: %@-[%@ , %@]",
           searchBar.text,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}
//get called after  clacel button being pressed
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = NO;
    [searchBar resignFirstResponder];
    self.strSearch  = @"";
    PRPLog(@" searchBar.text: %@-[%@ , %@]",
           searchBar.text,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    [self hideFilterTable];
    self.docs = self.docsTemp;
    [self.tb reloadData];	
}
//get called after keyboard Search key being pressed
-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    PRPLog(@" searchBar.text: %@-[%@ , %@]",
           searchBar.text,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    [self hideFilterTable];
}

#pragma mark Segues
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *identifier = segue.identifier;
    
    if ([identifier isEqualToString:@"segueVideo"]) {
                
        BRCellVideo *cell =  (BRCellVideo*)sender;
        NSIndexPath *indexPath = [self.tb indexPathForCell:cell];
        BRRecordVideo* record =  self.docs[indexPath.row];
        BRVideoDetailViewController *BRVideoDetailViewController = segue.destinationViewController;
        BRVideoDetailViewController.videoSelectedUid = record.uid;
        BRVideoDetailViewController.currentSelectedVideo = record;
        BRVideoDetailViewController.docs = self.docsTemp;
        if(nil != self.currentSelectSubCategory){
            
            BRVideoDetailViewController.videoSelecteSubCategoryId = self.currentSelectSubCategory.uid;
        }
        
        //come from facebook's friends favorite videos
        if(nil !=  self.fbFriend){
            BRVideoDetailViewController.fbFriend = self.fbFriend;
        }
        //[BRDModel sharedInstance].currentSelectedVideo = record;
        
//        [BRDModel sharedInstance].videoSelectedUid = record.uid;
//        PRPLog(@"\n [BRDModel sharedInstance].videoSelectedUid %@ \n-[%@ , %@]",
//               [BRDModel sharedInstance].subCategoriesSelectedUid,
//               NSStringFromClass([self class]),
//               NSStringFromSelector(_cmd));   
        //        UINavigationController *navigationController = segue.destinationViewController;
        
        //        BRSubCategoryViewController *BRSubCategoryViewController_ = (BRSubCategoryViewController *) navigationController.topViewController; 
        //        BRSubCategoryViewController_.m = self.birthday;
        
    }
}

-(IBAction)unwindBackToBRVideoViewController:(UIStoryboardSegue *)segue
{
    //    BRBirthdayEditViewController* sourceVC = (BRBirthdayEditViewController*) segue.sourceViewController;
    //[[BRDModel sharedInstance] cancelChanges];
    PRPLog(@"%unwindBackToBRVideoViewController-[%@ , %@]",
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}




@end
