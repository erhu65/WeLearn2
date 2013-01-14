//
//  FbChatRoomViewController.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/28/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "FbChatRoomViewController.h"
#import "WebViewJavascriptBridge.h"
#import "BRDModel.h"
#import "BRRecordFbChat.h"
#import "BRCellfBChat.h"
#import "BRRecordSubCategory.h"
#import "QuartzCore/QuartzCore.h"
#import "UIView+position.h"

#define KTempTfInKeyboard 7789

@interface FbChatRoomViewController ()
<UITableViewDataSource,UITableViewDelegate,
BRCellfBChatDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webview;
@property (weak, nonatomic) IBOutlet UITextView* tvOutPut;
@property (weak, nonatomic) IBOutlet UIButton* joinRoomButton;
@property (weak, nonatomic) IBOutlet UIButton* chatButton;
@property (strong, nonatomic) WebViewJavascriptBridge *javascriptBridge;
@property (weak, nonatomic) IBOutlet UITextField *tfChat;


@property (strong, nonatomic) IBOutlet UIToolbar *tb;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBarRoom;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barBtnTalk;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *barBtnJoin;

@property (weak, nonatomic) IBOutlet UILabel *lbRoomCount;
@property (weak, nonatomic) IBOutlet UITableView *tbFbChat;
@property(strong, nonatomic) NSMutableArray* mArrFbChat;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityChatRoom;


@property (nonatomic) BOOL isJoinFbChatRoom;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *btnZoom;
@property(nonatomic) BOOL isZoomed;
@property (weak, nonatomic) IBOutlet UIView *vContainer;

@property (nonatomic, strong) NSArray *hConstraintVContainer;
@property (nonatomic, strong) NSArray *vConstraintVContainer;

@end


@implementation FbChatRoomViewController
{
    
}
@synthesize javascriptBridge = _bridge;


-(void)setIsLeaving:(BOOL)isLeaving{
    
    _isLeaving = isLeaving;
    if(isLeaving){
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationFacebookMeDidUpdate object:[BRDModel sharedInstance]];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
        //Clear A UIWebView to trigger window.onunload
        [self.webview loadHTMLString:@"" baseURL:[NSURL URLWithString:@"http://google.com"]];    
    }
}


-(NSString*)currentPlaybackTime{
    if([_currentPlaybackTime isEqualToString:@"nan"])
        
        _currentPlaybackTime = @"0";
    return _currentPlaybackTime;
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    if([self isViewLoaded] && self.view.window == nil){
        //self.imvThumb = nil;
        self.tb = nil;
    }
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super initWithCoder:aDecoder];
    if(self){
        self.isJoinFbChatRoom = NO;
        self.isLeaving = NO;
        self.isZoomed = YES;
        self.mArrFbChat = [[NSMutableArray alloc] init];
        self.isDisableInAppNotification = YES;
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //node.js socket.io webview bridge start...
    [self.view  insertSubview:self.webview atIndex:0];
    
    //add custom key input to the dummy textfield
    self.tfChat.inputAccessoryView = [self accessoryView];
    self.tfChat.backgroundColor = [UIColor whiteColor];
    [self.tfChat.layer setCornerRadius:18];
    self.tfChat.borderStyle = UITextBorderStyleBezel;
    self.tfChat.frameWidth = 180.0f;
    self.tfChat.frameHeight = 30.0f;
    
    self.barBtnJoin.title = self.lang[@"actionJoin"];
    self.barBtnTalk.title = self.lang[@"actionTalk"];
    self.btnZoom.title = self.lang[@"actionFull"];
    //hide activityChatRoom first
    self.activityChatRoom.hidden = YES;
    
    self.tbFbChat.backgroundColor = [UIColor clearColor];
    [BRStyleSheet styleLabel:self.lbRoomCount withType:BRLabelTypeLarge];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleFacebookMeDidUpdate:) name:BRNotificationFacebookMeDidUpdate object:[BRDModel sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardDidShowNotification object:nil];
}
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if(self.isLeaving){
        [[NSNotificationCenter defaultCenter] removeObserver:self name:BRNotificationFacebookMeDidUpdate object:[BRDModel sharedInstance]];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
        //Clear A UIWebView to trigger window.onunload
        [self.webview loadHTMLString:@"" baseURL:[NSURL URLWithString:@"http://google.com"]];    
    }

}

-(void)_handleFacebookMeDidUpdate:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString* error = userInfo[@"error"];
    if(nil != error){
        [self showMsg:error type:msgLevelWarn]; 
        self.barBtnJoin.title = kSharedModel.lang[@"actionJoin"];
        self.barBtnJoin.enabled = YES;
        return;
    }

    PRPLog(@"[BRDModel sharedInstance].fbName: %@-[%@ , %@]",
           [BRDModel sharedInstance].fbName,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    
    NSString* name = [BRDModel sharedInstance].fbName;
    NSString* fbId = [BRDModel sharedInstance].fbId;
    [self callJsJoinRoomHandler:name toRoom:self.room withFbId:fbId];
}

#pragma mark node.js socekt helper methods
- (void)callJsSendMsgHandler:(NSString*)newMsg  {
    
    if([self.delegate respondsToSelector:@selector(getOutterInfo)]){
        [self.delegate getOutterInfo];
        PRPLog(@"self.currentYoutubeKey:%@  self.currentPlaybackTime:%@ -[%@ , %@] \n ",
               self.currentYoutubeKey,
               self.currentPlaybackTime,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
    }
    
    NSDictionary* data = @{@"msg": newMsg,
                           @"senderFbId": kSharedModel.fbId,
                           @"fbId":  kSharedModel.fbId,
                           @"currentYoutubeKey": self.currentYoutubeKey,
                           @"currentPlaybackTime": self.currentPlaybackTime,
    };
    
    [_bridge callHandler:@"JsSendMsgHandler" data:data responseCallback:^(id response) {
        NSLog(@"JsSendMsgHandler responded: %@", response);
    }];
}

- (void)callJsJoinRoomHandler:(NSString*)newName
                             toRoom:(NSString*)room
                            withFbId:(NSString*)fbId{
    
    if([self.delegate respondsToSelector:@selector(getOutterInfo)]){
        [self.delegate getOutterInfo];
        PRPLog(@"self.currentYoutubeKey:%@  self.currentPlaybackTime:%@ -[%@ , %@] \n ",
               self.currentYoutubeKey,
               self.currentPlaybackTime,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
    }
    
    PRPLog(@"self.currentYoutubeKey:%@  self.currentPlaybackTime:%@ -[%@ , %@] \n ",
           self.currentYoutubeKey,
           self.currentPlaybackTime,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    
    NSDictionary* data =  @{@"newName": newName,
                            @"newRoom": room,
                            @"newFbId": fbId,
                            @"senderFbId": [BRDModel sharedInstance].fbId,
                            @"currentYoutubeKey": self.currentYoutubeKey,
                            @"currentPlaybackTime": self.currentPlaybackTime};
    
    [_bridge callHandler:@"JsJoinRoomHandler" 
                    data:data 
        responseCallback:^(id response) {
        PRPLog(@"callJsJoinRoomHandler responded: %@-[%@ , %@] \n ",
               response,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
    }];
}
- (void) _cancelSendMsg
{
	//[self.tfChat setText:@""];
    self.barBtnTalk.enabled = YES;
    UITextField* tfTemp = (UITextField*)[self.tb viewWithTag:KTempTfInKeyboard];
    [tfTemp resignFirstResponder];
    //[tfTemp setText:@""];
}
-(void)_sendMsgToRoom
{
    self.barBtnTalk.enabled = FALSE;
    self.activityChatRoom.hidden = NO;
    [self.activityChatRoom startAnimating];
    UITextField* tfTemp = (UITextField*)[self.tb viewWithTag:KTempTfInKeyboard];
    if(tfTemp.text.length == 0){
        [self showMsg:self.lang[@"warnEmptyText"] type:msgLevelWarn];
        return;
    } 
    
    if(!self.isJoinFbChatRoom){
        [self showMsg:self.lang[@"infoConnectFBFirst"] type:msgLevelInfo];
        [self.activityChatRoom stopAnimating];
        self.activityChatRoom.hidden = YES;
        self.barBtnTalk.enabled = YES;
        [tfTemp resignFirstResponder];
        return;
    }
    
    [self callJsSendMsgHandler: tfTemp.text];
    [tfTemp resignFirstResponder];
}

-(IBAction)_prepareTextForSendMsgToRoom:(id)sender
{
    self.barBtnTalk.enabled = NO;
    [self.tfChat becomeFirstResponder];
}

- (IBAction)joinRoomWithFBAccount:(UIBarButtonItem*)sender {
    
    NSString* btnTitle = sender.title;    
    if([btnTitle isEqualToString:self.lang[@"actionJoin"]] 
       && !self.isJoinFbChatRoom){
        
        [WebViewJavascriptBridge enableLogging];
        
        _bridge = [WebViewJavascriptBridge bridgeForWebView:self.webview handler:^(id data, WVJBResponseCallback responseCallback) {
            
            NSLog(@"ObjC received message from JS: %@", data);
            responseCallback(@"Response for message from ObjC");
        }];
        
        [_bridge registerHandler:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
            
            NSLog(@"testObjcCallback called: %@", data);
            responseCallback(@"Response from testObjcCallback");
        }];
        
        [_bridge registerHandler:@"iosGetMsgCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        
            NSDictionary* resDic = (NSDictionary*)data;
            NSLog(@"iosGetMsgCallback called: %@", resDic);
            //NSString* type = resDic[@"type"];
            NSString* roomCount = (NSString*)resDic[@"roomCount"];
            NSString* sender = (NSString*)resDic[@"sender"];
            //NSString* senderFbId =  (NSString*)resDic[@"senderFbId"];
            NSString* message = (NSString*)resDic[@"message"];
            NSString* fbId = (NSString*)resDic[@"fbId"];
            
//            NSString* currentYoutubeKey = (NSString*)resDic[@"currentYoutubeKey"];
//            NSString* currentPlaybackTime = (NSString*)resDic[@"currentPlaybackTime"];

            if([sender isEqualToString:@"me"]) fbId = kSharedModel.fbId;
            
            if([sender isEqualToString:@"server"]
               && [message rangeOfString:@"Good to see your"].location != NSNotFound){
                self.isJoinFbChatRoom = YES;
            }
//            NSString* strOutput = [NSString stringWithFormat:@"%@(%@) say: %@ key:%@, playback:%@ at %@ count:%@", sender, fbId, message, currentYoutubeKey, currentPlaybackTime, [NSDate date] , roomCount];
            //NSString* strOutputOriginal = self.tvOutPut.text;
            //NSString* strOutputNew = [NSString stringWithFormat:@"%@ \n %@", strOutput, strOutputOriginal];
            //self.tvOutPut.text = strOutputNew;
            self.lbRoomCount.text = [NSString stringWithFormat:@"%@: %@",kSharedModel.lang[@"onLine"], roomCount];
            BRRecordFbChat* recordNew = [[BRRecordFbChat alloc] initWithJsonDic:resDic];
            [self.mArrFbChat insertObject:recordNew atIndex:0];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            NSArray* arrIndexPathNew = @[indexPath];
            
            [[self tbFbChat] beginUpdates];
            [self.tbFbChat insertRowsAtIndexPaths:arrIndexPathNew withRowAnimation:UITableViewRowAnimationAutomatic];
            [[self tbFbChat] endUpdates];
            [[self tbFbChat] setContentOffset:CGPointZero animated:YES];
            self.activityChatRoom.hidden = YES;
            [self.activityChatRoom stopAnimating];
            self.barBtnTalk.enabled = YES;
            self.barBtnJoin.enabled = YES;
            responseCallback(@"Response from iosGetMsgCallback: ios got chatroom msg");
        }];
        [_bridge send:@"A string sent from ObjC before Webview has loaded." responseCallback:^(id responseData) {
            NSLog(@"objc got response! %@", responseData);
        }];
        
        [_bridge callHandler:@"testJavascriptHandler" data:[NSDictionary dictionaryWithObject:@"before ready" forKey:@"foo"]];
        //node.js socket.io webview bridge end... 
        
        NSURL* url = [[NSURL alloc] initWithString:[BRDModel sharedInstance].socketUrl];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
        [self.webview loadRequest:request];
        [_bridge send:@"A string sent from ObjC after Webview has loaded."];
        self.barBtnJoin.title = self.lang[@"actionLeave"];
        self.barBtnJoin.enabled = FALSE;
        self.activityChatRoom.hidden = NO;
        [self.activityChatRoom startAnimating];
        if(nil != [BRDModel sharedInstance].fbId){
            
            [self _handleFacebookMeDidUpdate:nil];
        } else {
            [[BRDModel sharedInstance] fetchFacebookMe];
        }
    
    } else if([btnTitle isEqualToString:self.lang[@"actionLeave"]]){
        
        self.isJoinFbChatRoom = NO;
        self.barBtnJoin.title = self.lang[@"actionJoin"];
        self.barBtnJoin.enabled = YES;
        //Clear A UIWebView to trigger window.onunload
        NSURL* url = [[NSURL alloc] initWithString:@"http://google.com"];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
        [self.webview loadRequest:request];
    } 

}

#pragma mark chat textfield/keyboard 
- (void) keyboardWillHide: (NSNotification *) notification
{
    UITextField* tfTemp = (UITextField*)[self.tb viewWithTag:KTempTfInKeyboard];
    tfTemp.text = @"";
}
- (void) keyboardWillShow: (NSNotification *) notification
{
    UITextField* tfTemp = (UITextField*)[self.tb viewWithTag:KTempTfInKeyboard];
    tfTemp.text = self.tfChat.text;
    [tfTemp becomeFirstResponder];
}
- (UIToolbar *) accessoryView
{
	self.tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 44.0f)];
	self.tb .tintColor = [UIColor darkGrayColor];
	NSMutableArray *items = [NSMutableArray array];
	[items addObject:BARBUTTON(@"Cancel", @selector(_cancelSendMsg))];
	[items addObject:SYSBARBUTTON(UIBarButtonSystemItemFlexibleSpace, nil)];
	[items addObject:BARBUTTON(@"Send", @selector(_sendMsgToRoom))];
    
	self.tb.items = items;	
    UITextField *tfTemp = [[UITextField alloc] initWithFrame:CGRectMake(85.0, 8.0, 165.0, 30)];
    tfTemp.backgroundColor = [UIColor whiteColor];
    [tfTemp.layer setCornerRadius:18];
    tfTemp.borderStyle = UITextBorderStyleBezel;
    tfTemp.tag = KTempTfInKeyboard;
    [self.tb addSubview:tfTemp];
	return self.tb ;
}

- (IBAction)toggleOutterUI:(UIBarButtonItem*)sender {
    BOOL isZoomed = [self.delegate toggleOutterUI];
    if(isZoomed){
        sender.title = self.lang[@"actionSplit"];
    } else {
        sender.title = self.lang[@"actionFull"];
    }
}

- (IBAction)_back:(id)sender {
    
    UIBarButtonItem* barBtnBack = (UIBarButtonItem* )sender;
    barBtnBack.enabled = NO;    
    [self.delegate triggerOuterGoBack];
//    [self dismissViewControllerAnimated:YES completion:^{
//    
//    }];
}

#pragma mark UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BRCellfBChat *cellfBChat = (BRCellfBChat *)[self.tbFbChat dequeueReusableCellWithIdentifier:@"BRCellfBChat"];
    
    cellfBChat.tb = tableView;
    BRRecordFbChat* record = [self.mArrFbChat objectAtIndex:[indexPath row]];
    cellfBChat.record = record;
    cellfBChat.indexPath = indexPath;
    
    cellfBChat.deletate = self;
    UIImage *backgroundImage = [UIImage imageNamed:@"table-row-background.png"];
    cellfBChat.backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    
    return cellfBChat;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.mArrFbChat count];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleInsert) {
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
    }
}
#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}
-(void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath{
    
//    BRRecordFbChat* record = [self.mArrFbChat objectAtIndex:[indexPath row]];
//    PRPLog(@"record.currentYoutubeKey: %@-[%@ , %@] \n ",
//           record.currentYoutubeKey,
//           
//           NSStringFromClass([self class]),
//           NSStringFromSelector(_cmd));
//    
//    
//    BRRecordFbChat* record = self.tappedRecord;
//    [self.delegate triggerOuterAction1:record];

}
#pragma mark BRCellfBChatDelegate method
-(void)BRCellfBChatDelegateCellTapped:(BRRecordFbChat *)record
{
    [self.delegate triggerOuterAction1:record];
    
}
@end
