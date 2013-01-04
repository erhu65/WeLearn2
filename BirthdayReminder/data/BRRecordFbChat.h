//
//  BRRecordFbChat.h
//  BirthdayReminder
//
//  Created by Peter2 on 1/1/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "BRRecordBase.h"

@interface BRRecordFbChat : BRRecordBase


@property(nonatomic, strong)NSString* type;
@property(nonatomic, strong)NSString* sender;
@property(nonatomic, strong)NSString* socketOwnerFbId;
@property(nonatomic, strong)NSString* senderFbId;
@property(nonatomic, strong)NSString* message;@property(nonatomic, strong)NSString* videoName;

@property(nonatomic, strong)NSString* currentYoutubeKey;
@property(nonatomic, strong)NSString* currentPlaybackTime;
@property(nonatomic, strong)NSDate* created_at;

-(id)initWithJsonDic:(NSDictionary *)dic;
@end
