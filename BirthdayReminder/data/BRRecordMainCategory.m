//
//  BRRecordMainCategory.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/16/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRRecordMainCategory.h"

@implementation BRRecordMainCategory


-(id)initWithJsonDic:(NSDictionary *)dic{

    self = [super init];
    if (self) {
        self.name = [dic objectForKey:@"name"];
        self.uid = [dic objectForKey:@"_id"];
        self.desc = [dic objectForKey:@"desc"];
    }
    return self;
}
@end
