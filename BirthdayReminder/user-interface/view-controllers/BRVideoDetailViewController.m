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
#import "MarqueeLabel.h"
//#import "UIImageView+RemoteFile.h"



@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRVideoDetailViewController ()
<UIScrollViewDelegate>

//@property(nonatomic, strong) UIImageViewResizable* imvThumb;
//@property(weak, nonatomic) IBOutlet UIScrollView *scrvThumb;



@property (nonatomic, strong) LBYouTubePlayerController* youtubePlayer;
@property (nonatomic, assign, getter = isZoomed) BOOL zoomed;

@property (nonatomic, strong) NSArray *hConstraint;
@property (nonatomic, strong) NSArray *vConstraint;

@property (strong, nonatomic) MarqueeLabel*lbMarquee;



@end
@implementation BRVideoDetailViewController


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        //self.imvThumb = nil;
    }
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
    
   
//	self.scrvThumb.delegate = self;
//	
//	UIImage *bigImage = [UIImage imageNamed:@"test.png"];
//	self.imvThumb = [[UIImageViewResizable alloc] initWithImage:bigImage];
//    //[self.imvThumb applyGestures];
//	[self.scrvThumb  addSubview:self.imvThumb];
//	self.scrvThumb.contentSize = self.imvThumb.frame.size; //important!
//    self.scrvThumb.minimumZoomScale = 0.5;
//	self.scrvThumb.maximumZoomScale = 2.0;
    
    UIBarButtonItem *btnBack = [[UIBarButtonItem alloc]
                                initWithTitle:self.lang[@"actionBack"] 
                                style:UIBarButtonItemStyleBordered
                                target:self
                                action:@selector(navigationBack:)];
    self.navigationItem.leftBarButtonItem = btnBack;
    
    UIBarButtonItem *zoomBarbtn = [[UIBarButtonItem alloc]
                                   initWithTitle:self.lang[@"actionZoomIn"] 
                                   style:UIBarButtonItemStyleBordered
                                   target:self
                                   action:@selector(toggleVideoZoom:)];
    self.navigationItem.rightBarButtonItem = zoomBarbtn;


}

-(void)navigationBack:(id)sender  {
    
    [BRDModel sharedInstance].videoSelectedUid = nil;
    [BRDModel sharedInstance].currentSelectedVideo = nil;
    [super navigationBack:sender];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterFullscreen:) name:MPMoviePlayerWillEnterFullscreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willExitFullscreen:) name:MPMoviePlayerWillExitFullscreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredFullscreen:) name:MPMoviePlayerDidEnterFullscreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exitedFullscreen:) name:MPMoviePlayerDidExitFullscreenNotification object:nil];

    //使用Observer製作完成播放時要執行的動作
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification 
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleVideoDidUpdate:) name:BRNotificationVideoDidUpdate object:[BRDModel sharedInstance]];
    
    if(![BRDModel sharedInstance].currentSelectedVideo){
        [[BRDModel sharedInstance] fetchVideoByUid:[BRDModel sharedInstance].videoSelectedUid];
    }
} 
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
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
        
//        if ([[BRDModel sharedInstance].currentSelectedVideo.strImgUrl length] > 0) {
//            
//            [self.imvThumb setImageWithRemoteFileURL:[BRDModel sharedInstance].currentSelectedVideo.strImgUrl placeHolderImage:[UIImage imageNamed:@"icon-birthday-cake.png"]];
//        }         
        



        // Set the height of the container box to be 250
        
        [self _showMovie:[BRDModel sharedInstance].currentSelectedVideo.youtubeKey];
        //    youtubePlayer = [[LBYouTubePlayerController alloc] initWithYouTubeURL:[NSURL URLWithString:@"http://www.youtube.com/watch?v=i9OjcxfcUkE&list=FLEYfH4kbq85W_CiOTuSjf8w&feature=mh_lolz"] quality:LBYouTubeVideoQualityLarge];

        self.lbMarquee = [[MarqueeLabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width-20, 20)  rate:50.0f andFadeLength:10.0f];
        self.lbMarquee.translatesAutoresizingMaskIntoConstraints = NO;
        self.lbMarquee.marqueeType = MLContinuous;
        self.lbMarquee.continuousMarqueeSeparator = @"  |SEPARATOR|  ";
        self.lbMarquee.animationCurve = UIViewAnimationOptionCurveLinear;
        self.lbMarquee.numberOfLines = 1;
        self.lbMarquee.opaque = NO;
        self.lbMarquee.enabled = YES;
        self.lbMarquee.shadowOffset = CGSizeMake(0.0, -1.0);
        [BRStyleSheet styleLabel:(UILabel*)self.lbMarquee withType:BRLabelTypeName];
        
        self.lbMarquee.backgroundColor = [UIColor clearColor];
        self.lbMarquee.font = [UIFont fontWithName:@"Helvetica-Bold" size:17.000];
        self.lbMarquee.text = [NSString stringWithFormat:@"%@~%@ --- %@: %@", [BRDModel sharedInstance].currentSelectedVideo.mainCategoryName, 
                               [BRDModel sharedInstance].currentSelectedVideo.subCategoryName,
                               [BRDModel sharedInstance].currentSelectedVideo.name,
                               [BRDModel sharedInstance].currentSelectedVideo.desc];
        
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(marqueeTap:)];
        [self.lbMarquee addGestureRecognizer:tapRecognizer];
        self.lbMarquee.tag = 101;
        [self.view addSubview:self.lbMarquee];
        
        
        NSDictionary *viewsDictionary = 
        @{@"lbMarquee": self.lbMarquee};
        NSArray* constrainsMarqueeH = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[lbMarquee(<=490)]|" options:0 metrics:nil views:viewsDictionary];
        
        [self.view addConstraints:constrainsMarqueeH];
        NSArray* constrainsMarqueeV = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[lbMarquee(==20)]|" options:0 metrics:nil views:viewsDictionary];
        
        [self.view addConstraints:constrainsMarqueeV];        
    }
    
}
- (void)marqueeTap:(UITapGestureRecognizer *)recognizer {
    MarqueeLabel *lbMarquee = (MarqueeLabel *)recognizer.view;
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (!lbMarquee.isPaused) {
            [lbMarquee pauseLabel];
        } else {
            [lbMarquee unpauseLabel];
        }
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
//- (void)scrollViewDidZoom:(UIScrollView *)aScrollView {
//    CGFloat offsetX = (self.scrvThumb.bounds.size.width > self.scrvThumb.contentSize.width)? 
//    (self.scrvThumb.bounds.size.width - self.scrvThumb.contentSize.width) * 0.5 : 0.0;
//    CGFloat offsetY = (self.scrvThumb.bounds.size.height > self.scrvThumb.contentSize.height)? 
//    (self.scrvThumb.bounds.size.height - self.scrvThumb.contentSize.height) * 0.5 : 0.0;
//    self.imvThumb.center = CGPointMake(self.scrvThumb.contentSize.width * 0.5 + offsetX, 
//                                   self.scrvThumb.contentSize.height * 0.5 + offsetY);
//}
//-(UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView {
//    return self.imvThumb;
//}

#pragma mark LBYouTubePlayerViewControllerDelegate
-(void)youTubePlayerViewController:(LBYouTubePlayerController *)controller didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    
    PRPLog(@"Did extract video source:%@ -[%@ , %@]",
           videoURL,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}

-(void)youTubePlayerViewController:(LBYouTubePlayerController *)controller failedExtractingYouTubeURLWithError:(NSError *)error {
    
    PRPLog(@"Failed loading video due to error:%@ -[%@ , %@]",
           error,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
}

- (void)_showMovie:(NSString*)youtubeKey {
    
    self.youtubePlayer =  [[LBYouTubePlayerController alloc] initWithYouTubeID:youtubeKey quality:LBYouTubeVideoQualitySmall];
    self.youtubePlayer.view.frame = CGRectMake(0.0f, 0.0f, 100.0f, 100.0f);
    self.youtubePlayer.view.translatesAutoresizingMaskIntoConstraints = NO;
    //[self.view insertSubview:self.youtubePlayer.view belowSubview:self.btnZoom];
  
    self.youtubePlayer.delegate = self;
    //self.youtubePlayer.view.frame = self.vPlayerContainer.bounds;
    //self.youtubePlayer.view.center = self.view.center;        
    //設定影片比例的縮放、重複、控制列等參數
    self.youtubePlayer.scalingMode = MPMovieScalingModeAspectFill;
    self.youtubePlayer.repeatMode = MPMovieRepeatModeNone;
    self.youtubePlayer.controlStyle = MPMovieControlStyleDefault;
    [self.view addSubview:self.youtubePlayer.view];
    //self.youtubePlayer.view.userInteractionEnabled = NO;    
//    self.youtubePlayer.movieSourceType = MPMovieSourceTypeStreaming;
//    [self.youtubePlayer setInitialPlaybackTime:-1.f];
    //[self.youtubePlayer setFullscreen:YES animated:YES];
//    [self.youtubePlayer prepareToPlay];
//    [self.youtubePlayer play];
    
//     UIPinchGestureRecognizer* pinchOutGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchOutGesture:)];
//    [self.youtubePlayer.view addGestureRecognizer:pinchOutGesture];
//    UIPinchGestureRecognizer* pinchInGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchInGesture:)];
//    [self.youtubePlayer.view addGestureRecognizer:pinchInGesture];
    NSDictionary *viewsDictionary = 
    @{@"youtubePlayer": self.youtubePlayer.view};
    
    // Set the width of the container box to be 250
    self.hConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:viewsDictionary];
    // Set the height of the container box to be 250
    self.vConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[youtubePlayer(==200)]|" options:0 metrics:nil views:viewsDictionary];
    [self.view addConstraints:self.hConstraint];
    [self.view addConstraints: self.vConstraint];
    
}
#pragma mark MPMediaPlayback
- (void)willEnterFullscreen:(NSNotification*)notification {
    NSLog(@"willEnterFullscreen");
}

- (void)enteredFullscreen:(NSNotification*)notification {
    NSLog(@"enteredFullscreen");
}

- (void)willExitFullscreen:(NSNotification*)notification {
    NSLog(@"willExitFullscreen");
}
//only get called in full screen mode
- (void)exitedFullscreen:(NSNotification*)notification {
    
    NSLog(@"exitedFullscreen");
    
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if(self.youtubePlayer){
        
        PRPLog(@"reason: %d, currentPlaybackTime: %d-[%@ , %@]",
               reason,
               [self.youtubePlayer currentPlaybackRate],
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        [self.youtubePlayer play];
    }
}
//自行定義影片播放完成的函式 //only get called in non-full screen mode
//continue to play next video in this subCategoy playst list
- (void)moviePlayBackDidFinish:(NSNotification *)notification 
{
    NSNumber* reason = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    switch ([reason intValue]) {
        case MPMovieFinishReasonPlaybackEnded:
            NSLog(@"playbackFinished. Reason: Playback Ended");         
            break;
        case MPMovieFinishReasonPlaybackError:
            NSLog(@"playbackFinished. Reason: Playback Error");
            break;
        case MPMovieFinishReasonUserExited:
            NSLog(@"playbackFinished. Reason: User Exited");
            break;
        default:
            break;
    }
    //[self.youtubePlayer setFullscreen:NO animated:YES];
    //[self.youtubePlayer stop];
    //將影片重畫面上移除
    //[self.youtubePlayer.view removeFromSuperview];
}
- (IBAction)toggleVideoZoom:(id)sender {
    NSDictionary *views = @{ 
    @"self" : self.view, 
    @"youtubePlayer": self.youtubePlayer.view};
    
    [self.view removeConstraints:self.hConstraint];
    [self.view  removeConstraints:self.vConstraint];
    
    if (self.isZoomed)
    {
        UIBarButtonItem *zoomBarbtn = [[UIBarButtonItem alloc]
                                    initWithTitle:self.lang[@"actionZoomIn"] 
                                    style:UIBarButtonItemStyleBordered
                                    target:self
                                    action:@selector(toggleVideoZoom:)];
        self.navigationItem.rightBarButtonItem = zoomBarbtn;

        self.navigationItem.rightBarButtonItem.title = self.lang[@"actionZoomIn"];
        // Set the width of the container box to be 250
        self.hConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:views];
        
        // Set the height of the container box to be 250
        self.vConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[youtubePlayer(==200)]" options:0 metrics:nil views:views];
    }
    else
    {
        UIBarButtonItem *zoomBarbtn = [[UIBarButtonItem alloc]
                                       initWithTitle:self.lang[@"actionZoomOut"] 
                                       style:UIBarButtonItemStyleBordered
                                       target:self
                                       action:@selector(toggleVideoZoom:)];
        self.navigationItem.rightBarButtonItem = zoomBarbtn;
        
        self.hConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:views];
        
        self.vConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[youtubePlayer]|" options:0 metrics:nil views:views];
    }
    
    [self.view addConstraints:self.hConstraint];
    [self.view addConstraints:self.vConstraint];
    self.zoomed = !self.isZoomed;
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
    

}

@end