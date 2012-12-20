//
//  BRVideoViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRVideoViewController.h"
#import "BRCellVideo.h"
#import "BRRecordVideo.h"

#import "BRRecordMainCategory.h"
#import "BRRecordSubCategory.h"

#import "BRDModel.h"
#import "NSMutableArray+Shuffling.h"

@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRVideoViewController ()
<UITableViewDelegate, 
UITableViewDataSource,
UIScrollViewDelegate,
UISearchBarDelegate>
@property(nonatomic, strong)NSNumber* page;
@property(nonatomic, strong)NSNumber* lastPage;
@property (weak, nonatomic) IBOutlet UIButton *sortBtn;

@property(nonatomic, weak)IBOutlet UITableView* tb;

@property (weak, nonatomic) IBOutlet UILabel *sortLb;

@property (nonatomic, strong)  NSString *strSearch;
@property (nonatomic, weak) IBOutlet UIView *filterBar;
@property (nonatomic, strong)  UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *spaceBetweenFilterBarAndMainTable;
@end

@implementation BRVideoViewController
{
    BOOL addItemsTrigger;
    BOOL _isSearchBarOpen;
    
    NSArray *verticalConstraintsBeforeAnimation; 
    NSArray *verticalConstraintsAfterAnimation;
    
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
    self.title = [NSString stringWithFormat:@"%@~%@",  [BRDModel sharedInstance].currentSelectMainCategory.name,  [BRDModel sharedInstance].currentSelectSubCategory.name];
   
    self.sortLb.text = self.lang[@"actionSearch"];
 
    UIBarButtonItem *btnBack = [[UIBarButtonItem alloc]
                                initWithTitle:self.lang[@"actionBack"] 
                                style:UIBarButtonItemStyleBordered
                                target:self
                                action:@selector(navigationBack:)];
    self.navigationItem.leftBarButtonItem = btnBack;
}

-(void)navigationBack:(id)sender  {
    
    [[BRDModel sharedInstance].videos removeAllObjects];
    [[BRDModel sharedInstance].videosTemp removeAllObjects];
    [BRDModel sharedInstance].subCategoriesSelectedUid = nil;
    [BRDModel sharedInstance].currentSelectedVideo = nil;
    [super navigationBack:sender];
}
 
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVideosDidUpdate:) name:BRNotificationVideosDidUpdate object:[BRDModel sharedInstance]];
    
    if([[BRDModel sharedInstance].videosTemp count] ==0){
        [self _handleRefresh];
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


-(void)_handleRefresh{
    
    [self showHud:YES];    
    [[BRDModel sharedInstance] fetchVideosWithPage:self.page];
}
-(void)_handleVideosDidUpdate:(NSNotification *)notification
{
    [self hideHud:YES];
    NSDictionary *userInfo = [notification userInfo];
    NSString* errMsg = userInfo[@"errMsg"];
    self.page = userInfo[@"page"];
    self.lastPage = userInfo[@"lastPage"];
    
    if(errMsg!= nil && [errMsg length] > 0){
        
        [self showMsg:errMsg type:msgLevelError];
    } else {
        PRPLog(@"[BRDModel sharedInstance].videos: %d-[%@ , %@]",
               [BRDModel sharedInstance].videos.count,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        if([BRDModel sharedInstance].videos.count > 0){
            [self.tb reloadData];
            self.sortBtn.enabled = YES;
        } else {
            [self showMsg:self.lang[@"infoNoData"] type:msgLevelInfo];
            self.sortBtn.enabled = NO;
        }
        
    }
    
}

#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.tb)
		return [[BRDModel sharedInstance].videos count];
    else 
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"BRCellVideo";
    
	BRCellVideo *cell = (BRCellVideo*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];    
    BRRecordVideo *record = [BRDModel sharedInstance].videos[indexPath.row];
    cell.indexPath = indexPath;
    cell.record = record; 
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    //BRRecordVideo *record = [BRDModel sharedInstance].videos[indexPath.row];
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
                         if([BRDModel sharedInstance].subCategoriesSortType == subCategoriesSortTypeNoSort){
                             
                             [[BRDModel sharedInstance].subCategories shuffle];
                         } else {
                             [[BRDModel sharedInstance] subCategoriesSort];
                         }
                         [self.tb reloadData];
                         
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
    
    viewsDictionary = @{ @"filterBar": self.filterBar,
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
    [[BRDModel sharedInstance] filterVideoByNameOrDesc:self.strSearch];
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
    [searchBar resignFirstResponder];
    self.strSearch  = @"";
    
    PRPLog(@" searchBar.text: %@-[%@ , %@]",
           searchBar.text,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    [self hideFilterTable];
    [BRDModel sharedInstance].videos = [BRDModel sharedInstance].videosTemp;
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
        BRRecordVideo* record =  [[BRDModel sharedInstance].videos objectAtIndex:[indexPath row]];
        [BRDModel sharedInstance].currentSelectedVideo = record;
        
        [BRDModel sharedInstance].videoSelectedUid = record.uid;
        PRPLog(@"\n [BRDModel sharedInstance].videoSelectedUid %@ \n-[%@ , %@]",
               [BRDModel sharedInstance].subCategoriesSelectedUid,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));   
        //        UINavigationController *navigationController = segue.destinationViewController;
        
        //        BRSubCategoryViewController *BRSubCategoryViewController_ = (BRSubCategoryViewController *) navigationController.topViewController; 
        //        BRSubCategoryViewController_.m = self.birthday;
        
    }
}



@end
