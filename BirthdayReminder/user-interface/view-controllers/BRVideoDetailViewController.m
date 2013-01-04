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
#import "BRRecordFbChat.h"
#import "BRDModel.h"
#import "MarqueeLabel.h"
#import "WebViewJavascriptBridge.h"

#import "FbChatRoomViewController.h"
#import "FbMsgBaordViewController.h"
//#import "UIImageView+RemoteFile.h"

@interface UIWindow (AutoLayoutDebug) 
+ (UIWindow *)keyWindow;
- (NSString *)_autolayoutTrace;
@end

@interface BRVideoDetailViewController ()
<LBYouTubePlayerControllerDelegate, 
MPMediaPlayback,
UIScrollViewDelegate,
UIAlertViewDelegate,
FbChatRoomViewControllerDelegate,
FbMsgBaordViewControllerDelegate>

//@property(nonatomic, strong) UIImageViewResizable* imvThumb;
//@property(weak, nonatomic) IBOutlet UIScrollView *scrvThumb;

@property (nonatomic, strong) LBYouTubePlayerController* youtubePlayer;
@property (nonatomic, assign, getter = isZoomed) BOOL zoomed;
@property (nonatomic, strong) NSArray *hConstraintYoutubePlayer;
@property (nonatomic, strong) NSArray *vConstraintYoutubePlayer;
@property (strong, nonatomic) MarqueeLabel*lbMarquee;

@property(nonatomic, strong) FbChatRoomViewController* fbChatRoomViewController;
@property(nonatomic, strong) FbMsgBaordViewController* fbMsgBoardviewController;
@property (weak, nonatomic) IBOutlet UIView *vFbChatRoom;


@end
@implementation BRVideoDetailViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        //self.imvThumb = nil;
        self.view = nil;
		[self.fbChatRoomViewController willMoveToParentViewController:nil];
		[self.fbChatRoomViewController removeFromParentViewController];
        
        [self.fbMsgBoardviewController willMoveToParentViewController:nil];
        [self.fbMsgBoardviewController removeFromParentViewController];

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
    self.fbChatRoomViewController.isLeaving = YES;
    //stop youtube before leaving
    self.youtubePlayer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
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
    } else {
        if(!self.youtubePlayer)[self _handleVideoDidUpdate:nil];
    } 
} 
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    
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
        // Set the height of the container box to be 250
        [self _showMovie:[BRDModel sharedInstance].currentSelectedVideo.youtubeKey];

        if(self.lbMarquee){
            [self.lbMarquee removeFromSuperview];
            self.lbMarquee = nil;
        }
        
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
        self.title = [BRDModel sharedInstance].currentSelectedVideo.name;
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
    [self _showNextMovie];
}


-(void)_showNextMovie
{
    kSharedModel.currentSelectedVideoPlayBackTime = 0.0f;
    
    NSUInteger indexOfPerivousVideo = [[BRDModel sharedInstance].videos indexOfObject:[BRDModel sharedInstance].currentSelectedVideo];
    
    NSUInteger count = [[BRDModel sharedInstance].videos count];
    NSUInteger indexOfNextVideo = ++indexOfPerivousVideo;
    if(indexOfNextVideo == count)indexOfNextVideo = 0;
    [BRDModel sharedInstance].currentSelectedVideo = [[BRDModel sharedInstance].videos objectAtIndex:indexOfNextVideo];

    if(self.youtubePlayer){
        
        [self.youtubePlayer.view removeFromSuperview];
        self.youtubePlayer = nil; 
    }
    
    [self _handleVideoDidUpdate:nil];
    //[self _showMovie:strYoutubeKeyNextVideo];
}

-(void)_showMovieByKey:(NSString*) youtubeKey playBackTime:(double)playbackTime
{
    [BRDModel sharedInstance].currentSelectedVideo = [kSharedModel findVideoByYoutubeKey:youtubeKey];
    if(![BRDModel sharedInstance].currentSelectedVideo)return;
    kSharedModel.currentSelectedVideoPlayBackTime = playbackTime;
    
    if(self.youtubePlayer){
        [self.youtubePlayer.view removeFromSuperview];
        self.youtubePlayer = nil; 
    }
    
    
    [self _handleVideoDidUpdate:nil];
    //[self _showMovie:strYoutubeKeyNextVideo];
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
    if(kSharedModel.currentSelectedVideoPlayBackTime > 0.0f ){
        self.youtubePlayer.initialPlaybackTime = kSharedModel.currentSelectedVideoPlayBackTime;
    }
    
    //self.youtubePlayer.view.userInteractionEnabled = NO;    
//    self.youtubePlayer.movieSourceType = MPMovieSourceTypeStreaming;
//    [self.youtubePlayer setInitialPlaybackTime:-1.f];
    //[self.youtubePlayer setFullscreen:YES animated:YES];
    [self.youtubePlayer prepareToPlay];
    [self.youtubePlayer play];
    [self.view insertSubview:self.youtubePlayer.view atIndex:1];
//     UIPinchGestureRecognizer* pinchOutGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchOutGesture:)];
//    [self.youtubePlayer.view addGestureRecognizer:pinchOutGesture];
//    UIPinchGestureRecognizer* pinchInGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchInGesture:)];
//    [self.youtubePlayer.view addGestureRecognizer:pinchInGesture];
    NSDictionary *viewsDictionary = 
    @{@"youtubePlayer": self.youtubePlayer.view};
    
    // Set the width of the container box to be 250
    self.hConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:viewsDictionary];
    // Set the height of the container box to be 250
    self.vConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[youtubePlayer(==200)]|" options:0 metrics:nil views:viewsDictionary];
    [self.view addConstraints:self.hConstraintYoutubePlayer];
    [self.view addConstraints: self.vConstraintYoutubePlayer];
}

#pragma mark FbMsgBaordViewDelegate method
-(void)FbMsgBaordViewTriggerOuterGoBack
{  
    [BRDModel sharedInstance].videoSelectedUid = nil;
    [BRDModel sharedInstance].currentSelectedVideo = nil;
    //stop youtube before leaving
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.youtubePlayer stop];
    self.youtubePlayer = nil;
    
    [self performSegueWithIdentifier:@"segueBackTovideos" sender:self];
}

#pragma mark FbChatRoomViewControllerDelegate method
-(void)getOutterInfo
{
    self.fbChatRoomViewController.currentYoutubeKey = [BRDModel sharedInstance].currentSelectedVideo.youtubeKey;
    self.fbChatRoomViewController.currentPlaybackTime = [NSString stringWithFormat:@"%f", [self.youtubePlayer currentPlaybackTime]];
    [[BRDModel sharedInstance] findVideoByYoutubeKey:self.fbChatRoomViewController.currentYoutubeKey];
}
-(BOOL)toggleOutterUI
{
    
    [self toggleVideoZoom:nil];
    return self.isZoomed;
}
-(void)triggerOuterGoBack
{  
    [BRDModel sharedInstance].videoSelectedUid = nil;
    [BRDModel sharedInstance].currentSelectedVideo = nil;
    self.fbChatRoomViewController.isLeaving = YES;
    //stop youtube before leaving
    self.youtubePlayer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
    
    [self performSegueWithIdentifier:@"segueBackTovideos" sender:self];
    //[self dismissViewControllerAnimated: YES completion: ^{
    //}];
}
-(void)triggerOuterAction1:(id)record_{
    BRRecordFbChat* record = (BRRecordFbChat*)record_;
    

    
    if([record.currentYoutubeKey length] > 0 
       &&  [record.currentPlaybackTime length] > 0) {
        
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
        
        PRPLog(@"user selected currentPlaybackTime: %@ \n currentPlaybackTime: %@ \n -[%@ , %@]",
               record.currentYoutubeKey,
               record.currentPlaybackTime,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        [self _showMovieByKey:record.currentYoutubeKey 
                 playBackTime:[record.currentPlaybackTime doubleValue]];
    
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayBackDidFinish:)
                                                     name:MPMoviePlayerPlaybackDidFinishNotification 
                                                   object:nil];
    
    }

    
}

#pragma mark MPMediaPlayback delegate
- (void)willEnterFullscreen:(NSNotification*)notification 
{
    NSLog(@"willEnterFullscreen");
}

- (void)enteredFullscreen:(NSNotification*)notification 
{
    NSLog(@"enteredFullscreen");
}

- (void)willExitFullscreen:(NSNotification*)notification 
{
    NSLog(@"willExitFullscreen");
}

//only get called in full screen mode
- (void)exitedFullscreen:(NSNotification*)notification 
{
    NSLog(@"exitedFullscreen");
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if(self.youtubePlayer){
        
        PRPLog(@"reason: %d, currentPlaybackTime: %f \n currentPlaybackRate: %f \n -[%@ , %@]",
               reason,
               [self.youtubePlayer currentPlaybackTime],
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
            PRPLog(@"playbackFinished. Reason: Playback Ended[%@ , %@]",
                   [self.youtubePlayer currentPlaybackRate],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            break;
        case MPMovieFinishReasonPlaybackError:
            PRPLog(@"playbackFinished. Reason: Playback Error[%@ , %@]",
                   [self.youtubePlayer currentPlaybackRate],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            break;
        case MPMovieFinishReasonUserExited:
            PRPLog(@"playbackFinished. Reason: User Exited[%@ , %@]",
                   [self.youtubePlayer currentPlaybackRate],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            break;
        default:
            break;
    }
    if([reason intValue] == MPMovieFinishReasonPlaybackEnded){
        [self _showNextMovie];
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
    
    [self.view removeConstraints:self.hConstraintYoutubePlayer];
    [self.view  removeConstraints:self.vConstraintYoutubePlayer];
    
    if (self.isZoomed)
    {
        [self.view insertSubview:self.youtubePlayer.view atIndex:1];
        UIBarButtonItem *zoomBarbtn = [[UIBarButtonItem alloc]
                                    initWithTitle:self.lang[@"actionZoomIn"] 
                                    style:UIBarButtonItemStyleBordered
                                    target:self
                                    action:@selector(toggleVideoZoom:)];
        self.navigationItem.rightBarButtonItem = zoomBarbtn;
        self.navigationItem.rightBarButtonItem.title = self.lang[@"actionZoomIn"];
        // Set the width of the container box to be 250
        self.hConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:views];
        // Set the height of the container box to be 250
        self.vConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[youtubePlayer(==200)]" options:0 metrics:nil views:views];
    }
    else
    {
        [self.view insertSubview:self.youtubePlayer.view atIndex:2];
        UIBarButtonItem *zoomBarbtn = [[UIBarButtonItem alloc]
                                       initWithTitle:self.lang[@"actionZoomOut"] 
                                       style:UIBarButtonItemStyleBordered
                                       target:self
                                       action:@selector(toggleVideoZoom:)];
        self.navigationItem.rightBarButtonItem = zoomBarbtn;
        self.hConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[youtubePlayer]|" options:0 metrics:nil views:views];
        self.vConstraintYoutubePlayer = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[youtubePlayer]-40-|" options:0 metrics:nil views:views];
    }
    
    [self.view addConstraints:self.hConstraintYoutubePlayer];
    [self.view addConstraints:self.vConstraintYoutubePlayer];
    self.zoomed = !self.isZoomed;
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //segueFbChatRoom
	if ([segue.identifier isEqualToString:@"segueFbChatRoom"])
	{
		self.fbChatRoomViewController = segue.destinationViewController;
        self.fbChatRoomViewController.delegate = self;
		//self.daysViewController.records = _records;
	} else if ([segue.identifier isEqualToString:@"segueFbMsgBoard"]) {
    
		self.fbMsgBoardviewController = segue.destinationViewController;
        self.fbMsgBoardviewController.videoId = kSharedModel.currentSelectedVideo.uid;
        self.fbMsgBoardviewController.delegate = self;
    }
    //	else if ([segue.identifier isEqualToString:@"EmbedGraph"])
    //	{
    //		self.graphViewController = segue.destinationViewController;
    //	}
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
//	if ([identifier isEqualToString:@"DoneEdit"])
//	{
//		if ([self.textField.text length] > 0)
//		{
//			int value = [self.textField.text intValue];
//			if (value >= 0 && value <= 100)
//				return YES;
//		}
//        
//		[[[UIAlertView alloc]
//          initWithTitle:nil
//          message:@"Value must be between 0 and 100."
//          delegate:nil
//          cancelButtonTitle:@"OK"
//          otherButtonTitles:nil]
//         show];
//		return NO;
//	}
	return YES;
}

@end
