//
//  BRDBirthday.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 26/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRRecordFriend.h"


@implementation BRRecordFriend



-(id)initWithJsonDic:(NSDictionary *)dic{
    
    self = [super init];
    if (self) {
        
        self.fbId = [dic objectForKey:@"id"];
        self.fbName = [dic objectForKey:@"name"];
        //self.count = (NSNumber*)[dic objectForKey:@"count"];
        self.count = (NSNumber*)[dic objectForKey:@"count"];
        self.strImgUrl = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?", self.fbId];
    }
    return self;
    
}


-(NSString*)description
{
    [super description];
    return [NSString stringWithFormat:@"self.fbId: %@ \n self.fbName: %@ \n self.count: %d", self.fbId, self.fbName, [self.count integerValue]];
}


@end
