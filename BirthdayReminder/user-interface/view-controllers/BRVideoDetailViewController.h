//
//  BRVideoDetailViewController.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/19/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCoreViewController.h"
#import "LBYouTube.h" 
#import "BRDBirthday.h"
@interface BRVideoDetailViewController : BRCoreViewController

@property(nonatomic, strong)NSMutableArray* docs;
@property(nonatomic, strong)NSString* videoSelecteSubCategoryId;
@property(nonatomic, strong)NSString* videoSelectedUid;
@property(nonatomic, strong)BRRecordVideo* currentSelectedVideo;
@property(nonatomic) double currentSelectedVideoPlayBackTime;
@property(nonatomic, strong)BRDBirthday* fbFriend;

@end
