//
//  BRSubCategoryViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/17/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.

#import "BRSubCategoryViewController.h"
#import "BRCellSubCategory.h"
#import "BRRecordSubCategory.h"
#import "BRDModel.h"
#import "NSMutableArray+Shuffling.h"

@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRSubCategoryViewController ()
<UITableViewDelegate, 
UITableViewDataSource,
UIScrollViewDelegate>
@property(nonatomic, strong)NSNumber* page;
@property(nonatomic, strong)NSNumber* lastPage;
@property (weak, nonatomic) IBOutlet UIButton *sortBtn;

@property(nonatomic, weak)IBOutlet UITableView* tb;

@property (weak, nonatomic) IBOutlet UILabel *sortLb;

@property (nonatomic, weak) IBOutlet UILabel *filterNameLabel;
@property (nonatomic, weak) IBOutlet UIView *filterBar; 
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *spaceBetweenFilterBarAndMainTable;

@end

@implementation BRSubCategoryViewController
{
    BOOL addItemsTrigger;
    
	NSArray *filterNames;
	NSUInteger activeFilterIndex;
	UITableView *filterTableView;
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
    // Dispose of any resources that can be recreated.
}


-(id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super initWithCoder:aDecoder];
    if(self){

        filterNames = @[self.lang[@"noSort"], self.lang[@"byName"], self.lang[@"byDate"]];
        activeFilterIndex = mainCategoriesSortTypeNoSort;
        [BRDModel sharedInstance].mainCategoriesSortType = activeFilterIndex;
        [BRDModel sharedInstance].mainCategoriesSortIsDesc = FALSE;

        
    }
    return self;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    // Add self as scroll view delegate to catch scroll events
    self.tb.autoresizesSubviews = YES;
    // Add the "Pull to Load" above the table
	UIView *pullView = [[[NSBundle mainBundle] loadNibNamed:@"HiddenHeaderView" owner:self options:nil] lastObject]; 
	pullView.frame = CGRectOffset(pullView.frame, 0.0f, -pullView.frame.size.height);
	[self.tb addSubview:pullView];
    
    self.filterNameLabel.text = filterNames[activeFilterIndex];
    
    self.title = self.lang[@"titleSubCategories"];
    self.sortLb.text = self.lang[@"sort"];
    self.filterNameLabel.text = @"";
    UIBarButtonItem *btnBack = [[UIBarButtonItem alloc]
                                initWithTitle:self.lang[@"actionBack"] 
                                style:UIBarButtonItemStyleBordered
                                target:self
                                action:@selector(navigationBack:)];
    self.navigationItem.leftBarButtonItem = btnBack;
	// Do any additional setup after loading the view.
}

-(void)navigationBack:(id)sender  {
    
    [[BRDModel sharedInstance].subCategories removeAllObjects];
    [BRDModel sharedInstance].mainCategoriesSelectedUid = nil;
     
    [super navigationBack:sender];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSubCategoriesDidUpdate:) name:BRNotificationSubCategoriesDidUpdate object:[BRDModel sharedInstance]];
    
    if( [[BRDModel sharedInstance].subCategories count] ==0){
        [self _handleRefresh];
    }
}
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationSubCategoriesDidUpdate object:[BRDModel sharedInstance]];
}



-(void)_handleRefresh{
    
    [self showHud:YES];    
    [[BRDModel sharedInstance] fetchSubCategoriesWithPage:self.page];
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

-(void)handleSubCategoriesDidUpdate:(NSNotification *)notification
{
    [self hideHud:YES];
    NSDictionary *userInfo = [notification userInfo];
    NSString* errMsg = userInfo[@"errMsg"];
    self.page = userInfo[@"page"];
    self.lastPage = userInfo[@"lastPage"];
    
    if(errMsg!= nil && [errMsg length] > 0){
 
        [self showMsg:errMsg type:msgLevelError];
    } else {
        PRPLog(@"[BRDModel sharedInstance].subCategories.count: %d-[%@ , %@]",
               [BRDModel sharedInstance].subCategories.count,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        if([BRDModel sharedInstance].subCategories.count > 0){
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
		return [[BRDModel sharedInstance].subCategories count];
    else 
        return [filterNames count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
    
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    if(tableView == self.tb){
        cell = nil;
        static NSString *CellIdentifier = @"BRSublCategory";
        BRCellSubCategory *cell =  (BRCellSubCategory *)[self.tb dequeueReusableCellWithIdentifier:CellIdentifier];
        
        BRRecordSubCategory *record = [BRDModel sharedInstance].subCategories[indexPath.row];
        cell.indexPath = indexPath;
        cell.record = record; 
        return cell;
    } else {
		cell.textLabel.text = filterNames[indexPath.row];
        //		cell.accessoryType = (activeFilterIndex == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        if([BRDModel sharedInstance].subCategoriesSortType == indexPath.row){
            UIImage* img_;
            if([BRDModel sharedInstance].subCategoriesSortIsDesc){
                img_ = [UIImage imageNamed:@"Arrow.png"]; 
            } else{
                img_ = [UIImage imageNamed:@"ArrowAsc.png"]; 
            }
            
            UIImageView* ascOrDescImv =[[UIImageView alloc] initWithImage:img_];
            cell.accessoryView = ascOrDescImv;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        
        cell.textLabel.font = [UIFont systemFontOfSize:14.0f]; 
        cell.textLabel.textColor = [UIColor whiteColor];
    }
    
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (tableView == filterTableView) {
        if(activeFilterIndex == indexPath.row){
            [BRDModel sharedInstance].subCategoriesSortIsDesc =  ![BRDModel sharedInstance].subCategoriesSortIsDesc;
        } else {
            [BRDModel sharedInstance].subCategoriesSortIsDesc = FALSE;
        }
        
        activeFilterIndex = indexPath.row; 
        [BRDModel sharedInstance].subCategoriesSortType = activeFilterIndex;
        self.filterNameLabel.text =filterNames[activeFilterIndex];
        [self hideFilterTable];
        
    } else {
//        
//        BRRecordSubCategory *record = [BRDModel sharedInstance].subCategories[indexPath.row];
    }
}


#pragma mark UIScrollViewDelegate 
//- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
//{
//	// Detect if the trigger has been set, if so add new items
//	if (addItemsTrigger)
//	{
//        
//        BOOL isLastPage = [self.lastPage boolValue];
//        if(!isLastPage){
//            int page_ = [self.page intValue];
//            page_++;
//            self.page = [[NSNumber alloc] initWithInt:page_];
//            [self _handleRefresh];
//        }
//        
//	}
//	// Reset the trigger
//	addItemsTrigger = NO;
//}
//
//- (void) scrollViewDidScroll:(UIScrollView *)scrollView
//{
//	// Trigger the offset if the user has pulled back more than 50 pixels
//	if (scrollView.contentOffset.y < -80.0f)
//		addItemsTrigger = YES;
//}
//
#pragma mark show or hide order table view
- (IBAction)filterButtonPressed:(id)sender {
    
    if (filterTableView == nil) [self showFilterTable];
    else [self hideFilterTable];
}

- (void)hideFilterTable {
    
    PRPLog(@"\n sort type: %d  \n ascOrDesc %d \n-[%@ , %@]",
           [BRDModel sharedInstance].subCategoriesSortType,
           [BRDModel sharedInstance].subCategoriesSortIsDesc,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    UIImage* img_;
    if([BRDModel sharedInstance].subCategoriesSortIsDesc){
        img_ = [UIImage imageNamed:@"Arrow.png"]; 
    } else{
        img_ = [UIImage imageNamed:@"ArrowAsc.png"]; 
    }
    [self.sortBtn setBackgroundImage:img_ forState:UIControlStateNormal];
    
    [self.view removeConstraints: verticalConstraintsAfterAnimation];
    [self.view addConstraints: verticalConstraintsBeforeAnimation];
    
    [UIView animateWithDuration:0.3f animations:^ {
        [self.view layoutIfNeeded]; }
                     completion:^(BOOL finished) {
                         
                         [filterTableView removeFromSuperview]; 
                         filterTableView = nil;
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
    filterTableView = [[UITableView alloc]
                       initWithFrame:CGRectZero style:UITableViewStylePlain];
    filterTableView.translatesAutoresizingMaskIntoConstraints = NO;
    filterTableView.dataSource = self; 
    filterTableView.delegate = self;
    
    filterTableView.rowHeight = 24.0f; 
    filterTableView.backgroundColor = [UIColor blackColor]; 
    filterTableView.separatorColor = [UIColor darkGrayColor];
    
    [self.view addSubview:filterTableView];
    
    NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(filterTableView);
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[filterTableView]|" options:0
                                                                   metrics:nil
                                                                     views:viewsDictionary];
    [self.view addConstraints:constraints];
    [self.view removeConstraint: self.spaceBetweenFilterBarAndMainTable];
    
    viewsDictionary = @{
    @"filterTableView": filterTableView, @"filterBar": self.filterBar, @"mainTableView": self.tb };
    
    /// this is new
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:
                   @"V:[filterBar][filterTableView(0)][mainTableView]"
                                                          options:0
                                                          metrics:nil views:viewsDictionary];
    verticalConstraintsBeforeAnimation = constraints;
    [self.view addConstraints:constraints]; 
    [self.view layoutIfNeeded];
    [self.view removeConstraints:constraints]; /// until here

    constraints = [NSLayoutConstraint constraintsWithVisualFormat:
                   @"V:[filterBar][filterTableView(72)][mainTableView]"
                                                          options:0
                                                          metrics:nil views:viewsDictionary];
    verticalConstraintsAfterAnimation = constraints;
    [self.view addConstraints:constraints];
    
    [UIView animateWithDuration:0.3f animations:^ {
        [self.view layoutIfNeeded]; }];
    
}

#pragma mark Segues
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *identifier = segue.identifier;
    
    if ([identifier isEqualToString:@"segueVideos"]) {
        
        BRCellSubCategory *cell =  (BRCellSubCategory *)sender;
        NSIndexPath *indexPath = [self.tb indexPathForCell:cell];
        BRRecordSubCategory* record =  [[BRDModel sharedInstance].subCategories objectAtIndex:[indexPath row]];
        [BRDModel sharedInstance].subCategoriesSelectedUid = record.uid;
        PRPLog(@"\n [BRDModel sharedInstance].subCategoriesSelectedUid %@ \n-[%@ , %@]",
               [BRDModel sharedInstance].subCategoriesSelectedUid,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));   
        //        UINavigationController *navigationController = segue.destinationViewController;
        
        //        BRSubCategoryViewController *BRSubCategoryViewController_ = (BRSubCategoryViewController *) navigationController.topViewController; 
        //        BRSubCategoryViewController_.m = self.birthday;
        
    }
}

@end
