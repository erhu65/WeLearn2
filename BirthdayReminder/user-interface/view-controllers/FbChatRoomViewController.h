//
//  FbChatRoomViewController.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/28/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"

@protocol FbChatRoomViewControllerDelegate <NSObject>

@optional
-(void)getOutterInfo;
-(BOOL)toggleOutterUI;
-(void)triggerOuterGoBack;
-(void)triggerOuterAction1:(id)record;
@end

@interface FbChatRoomViewController : BRCoreViewController
@property(nonatomic, strong)NSString* room;
@property(nonatomic) BOOL isLeaving;
@property(nonatomic, strong) NSString* currentYoutubeKey;
@property(nonatomic, strong) NSString* currentPlaybackTime;
@property(nonatomic, weak) id<FbChatRoomViewControllerDelegate> delegate;
@end
