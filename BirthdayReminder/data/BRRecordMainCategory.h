//
//  BRRecordMainCategory.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/16/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

@interface BRRecordMainCategory : NSObject


@property(nonatomic, strong)NSString* uid;
@property(nonatomic, strong)NSString* name;
@property(nonatomic, strong)NSString* desc;

-(id)initWithJsonDic:(NSDictionary *)dic;
@end
