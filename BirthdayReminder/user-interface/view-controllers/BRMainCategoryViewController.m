//
//  BRMainCategoryViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/16/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRMainCategoryViewController.h"
#import "BRCellMainCategory.h"
#import "BRRecordMainCategory.h"
#import "BRDModel.h"

@interface BRMainCategoryViewController ()



@end

@implementation BRMainCategoryViewController
{
    BOOL addItemsTrigger;
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

   

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Add self as scroll view delegate to catch scroll events
    self.tb.autoresizesSubviews = YES;
    // Add the "Pull to Load" above the table
	UIView *pullView = [[[NSBundle mainBundle] loadNibNamed:@"HiddenHeaderView" owner:self options:nil] lastObject]; 
	pullView.frame = CGRectOffset(pullView.frame, 0.0f, -pullView.frame.size.height);
	[self.tb addSubview:pullView];
    
    [self populateLang];
	// Do any additional setup after loading the view.
}


-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMainCategoriesDidUpdate:) name:BRNotificationMainCategoriesDidUpdate object:[BRDModel sharedInstance]];
   
    
    if( [[BRDModel sharedInstance].mainCategories count] ==0){
        [self _handleRefresh];
    }

}

-(void)_handleRefresh{
    
    [self showHud:YES];    
    [[BRDModel sharedInstance] fetchMainCategoriesWithPage:self.page];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationMainCategoriesDidUpdate object:[BRDModel sharedInstance]];
}

-(void)handleMainCategoriesDidUpdate:(NSNotification *)notification
{
    [self hideHud:YES];
    NSDictionary *userInfo = [notification userInfo];
    NSString* errMsg = userInfo[@"errMsg"];
    self.page = userInfo[@"page"];
    self.lastPage = userInfo[@"lastPage"];
    
    if(errMsg!= nil && [errMsg length] > 0){
        [self handleErrMsg:errMsg];
    } else {
        PRPLog(@"[BRDModel sharedInstance].mainCategories: %d-[%@ , %@]",
                [BRDModel sharedInstance].mainCategories.count,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        [self.tb reloadData];
    }
    
}


-(void)populateLang
{
    PRPLog(@"sum: %@-[%@ , %@]",
           self.lang[@"sum"],
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}

#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[BRDModel sharedInstance].mainCategories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCellMainCategory *cell =  (BRCellMainCategory *)[self.tb dequeueReusableCellWithIdentifier:@"BRCellMainCategory"];
    
    BRRecordMainCategory *record = [BRDModel sharedInstance].mainCategories[indexPath.row];
    cell.indexPath = indexPath;
    cell.record = record;
    return cell;
}

#pragma mark UITableViewDelegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRRecordMainCategory *record = [BRDModel sharedInstance].mainCategories[indexPath.row];
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


@end
