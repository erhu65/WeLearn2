//
//  BRVideoDetailViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/19/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRVideoDetailViewController.h"
#import "UIImageViewResizable.h"
#import "BRRecordVideo.h"
#import "BRDModel.h"

@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRVideoDetailViewController ()
<UIScrollViewDelegate>

@property(nonatomic, strong) UIImageViewResizable* imvThumb;
@property(weak, nonatomic) IBOutlet UIScrollView *scrvThumb;

@property (weak, nonatomic) IBOutlet UILabel *lbMainCateogryName;
@property (weak, nonatomic) IBOutlet UILabel *lbSubCategoryName;
@property (weak, nonatomic) IBOutlet UILabel *lbName;

@property (weak, nonatomic) IBOutlet UILabel *lbDesc;
@property (weak, nonatomic) IBOutlet UIWebView *webYoutube;

@end
@implementation BRVideoDetailViewController


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        self.imvThumb = nil;
    }
}
-(id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super initWithCoder:aDecoder];
    if(self){

        
    }
    return self;
}
-(void) setLbMainCateogryName:(UILabel *)lbMainCateogryName
{
    _lbMainCateogryName = lbMainCateogryName;
    if (_lbMainCateogryName) {
        [BRStyleSheet styleLabel:_lbMainCateogryName withType:BRLabelTypeDaysUntilBirthday];
    }
}

-(void) setLbSubCategoryName:(UILabel *)lbSubCategoryName
{
    _lbSubCategoryName = lbSubCategoryName;
    if (_lbSubCategoryName) {
        [BRStyleSheet styleLabel:_lbSubCategoryName withType:BRLabelTypeName];
    }
}
-(void) setLbName:(UILabel *)lbName
{
    _lbName= lbName;
    if (_lbName) {
        [BRStyleSheet styleLabel:_lbName withType:BRLabelTypeLarge];
    }
}
-(void) setLbDesc:(UILabel *)lbDesc
{
    _lbDesc = lbDesc;
    if (_lbDesc) {
        [BRStyleSheet styleLabel:_lbDesc withType:BRLabelTypeDaysUntilBirthdaySubText];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
   
	self.scrvThumb.delegate = self;
	
	UIImage *bigImage = [UIImage imageNamed:@"test.png"];
	self.imvThumb = [[UIImageViewResizable alloc] initWithImage:bigImage];
    //[self.imvThumb applyGestures];
	[self.scrvThumb  addSubview:self.imvThumb];
	self.scrvThumb.contentSize = self.imvThumb.frame.size; //important!
    self.scrvThumb.minimumZoomScale = 0.5;
	self.scrvThumb.maximumZoomScale = 2.0;
    
    UIBarButtonItem *btnBack = [[UIBarButtonItem alloc]
                                initWithTitle:self.lang[@"actionBack"] 
                                style:UIBarButtonItemStyleBordered
                                target:self
                                action:@selector(navigationBack:)];
    self.navigationItem.leftBarButtonItem = btnBack;

}

-(void)navigationBack:(id)sender  {
    
    [BRDModel sharedInstance].videoSelectedUid = nil;
    [BRDModel sharedInstance].currentSelectedVideo = nil;
    [super navigationBack:sender];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVideoDidUpdate:) name:BRNotificationVideoDidUpdate object:[BRDModel sharedInstance]];
    
    if(![BRDModel sharedInstance].currentSelectedVideo){
        [[BRDModel sharedInstance] fetchVideoByUid:[BRDModel sharedInstance].videoSelectedUid];
    }
} 
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationVideoDidUpdate object:[BRDModel sharedInstance]];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    PRPLog(@"%@-[%@ , %@]",
           [[UIWindow keyWindow] _autolayoutTrace],
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    
}

-(void)_handleVideoDidUpdate:(NSNotification *)notification
{
    [self hideHud:YES];
    NSDictionary *userInfo = [notification userInfo];
    NSString* errMsg = userInfo[@"errMsg"];
    
    if(errMsg!= nil && [errMsg length] > 0){
        
        [self showMsg:errMsg type:msgLevelError];
    } else {

        PRPLog(@"[BRDModel sharedInstance].currentSelectedVideo: %@-[%@ , %@]",
               [BRDModel sharedInstance].currentSelectedVideo,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd)); 
        self.lbMainCateogryName.text = [BRDModel sharedInstance].currentSelectedVideo.mainCategoryName;
        self.lbSubCategoryName.text = [BRDModel sharedInstance].currentSelectedVideo.subCategoryName;
        self.lbName.text = [BRDModel sharedInstance].currentSelectedVideo.name;
        self.navigationItem.title =self.lbName.text;
        
        self.lbDesc.text = [BRDModel sharedInstance].currentSelectedVideo.desc;
    }
    
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


#pragma mark UIScrollViewDelegate
- (void)scrollViewDidZoom:(UIScrollView *)aScrollView {
    CGFloat offsetX = (self.scrvThumb.bounds.size.width > self.scrvThumb.contentSize.width)? 
    (self.scrvThumb.bounds.size.width - self.scrvThumb.contentSize.width) * 0.5 : 0.0;
    CGFloat offsetY = (self.scrvThumb.bounds.size.height > self.scrvThumb.contentSize.height)? 
    (self.scrvThumb.bounds.size.height - self.scrvThumb.contentSize.height) * 0.5 : 0.0;
    self.imvThumb.center = CGPointMake(self.scrvThumb.contentSize.width * 0.5 + offsetX, 
                                   self.scrvThumb.contentSize.height * 0.5 + offsetY);
}
-(UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imvThumb;
}








@end
