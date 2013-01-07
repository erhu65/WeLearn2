//
//  BRRecordVideo.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRRecordBase.h"
@interface BRRecordVideo : BRRecordBase

@property(nonatomic, strong)NSString* uid;
@property(nonatomic, strong)NSString* name;
@property(nonatomic, strong)NSString* desc;
@property(nonatomic, strong)NSString* mainCategoryName;
@property(nonatomic, strong)NSString* subCategoryName;
@property(nonatomic, strong)NSString* youtubeKey;
@property(nonatomic, strong)NSString* imgName;
@property(nonatomic, strong)NSDate* created_at;
@property(nonatomic, strong)NSDate* modified_at;
@property BOOL isUserFavorite;

-(id)initWithJsonDic:(NSDictionary *)dic;

@end
