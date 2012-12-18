//
//  BRRecordSubCategory.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/17/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRRecordSubCategory.h"

@implementation BRRecordSubCategory

-(id)initWithJsonDic:(NSDictionary *)dic{
    
    self = [super init];
    if (self) {
        self.name = [dic objectForKey:@"name"];
        self.uid = [dic objectForKey:@"_id"];
        self.desc = [dic objectForKey:@"desc"];
        self.created_at = [dic objectForKey:@"created_at"];
        self.modified_at = [dic objectForKey:@"modified_at"];
    }
    return self;
}
@end
