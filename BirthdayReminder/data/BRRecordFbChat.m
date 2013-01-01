//
//  BRRecordFbChat.m
//  BirthdayReminder
//
//  Created by Peter2 on 1/1/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "BRRecordFbChat.h"

@implementation BRRecordFbChat

-(id)initWithJsonDic:(NSDictionary *)dic{
    
    self = [super init];
    if (self) {
        
        self.type = [dic objectForKey:@"type"];
        self.sender = [dic objectForKey:@"sender"];
        self.socketOwnerFbId = [dic objectForKey:@"fbId"];
        self.senderFbId = [dic objectForKey:@"senderFbId"];
        self.message = [dic objectForKey:@"message"];
        self.youtubeKey = [dic objectForKey:@"youtubeKey"];
        self.placbacktime = [dic objectForKey:@"placbacktime"];
        self.created_at = [NSDate date];
        
        self.strImgUrl = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?", self.senderFbId];
        
        
    }
    return self;
}

-(NSString*)description
{
    [super description];
    
    return [NSString stringWithFormat:@"self.type: %@ \n self.sender: %@ \n self.message: %@",  self.type, self.sender, self.message];
}


@end
