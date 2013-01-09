//
//  BRRecordFbChat.m
//  BirthdayReminder
//
//  Created by Peter2 on 1/1/13.
//  Copyright (c) 2013 Nick Kuh. All rights reserved.
//

#import "BRRecordFbChat.h"
#import "BRRecordVideo.h"
@implementation BRRecordFbChat

-(id)initWithJsonDic:(NSDictionary *)dic{
    
    self = [super init];
    if (self) {
        
        self.type = [dic objectForKey:@"type"];
        self.sender = [dic objectForKey:@"sender"];
        self.socketOwnerFbId = [dic objectForKey:@"senderFbId"];
        self.senderFbId = [dic objectForKey:@"senderFbId"];
        self.message = [dic objectForKey:@"message"];
        self.currentYoutubeKey = [dic objectForKey:@"currentYoutubeKey"];
//        if([self.currentYoutubeKey length] > 0){
//            BRRecordVideo* video =  [kSharedModel findVideoByYoutubeKey:self.currentYoutubeKey];
//            self.videoName = video.name;
//        } else {
//            
        self.videoName = @"";
        self.currentPlaybackTime = [dic objectForKey:@"currentPlaybackTime"];
        self.created_at = [NSDate date];
        
        self.strImgUrl = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?", self.senderFbId];
        
        PRPLog(@"[self description]:%@  -[%@ , %@] \n ",
               [self description],
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
    }
    
    return self;
}

-(NSString*)description
{
    [super description];
    return [NSString stringWithFormat:@"self.type: %@ \n self.socketOwnerFbId: %@ \n self.senderFbId: %@ \n self.message: %@", self.type, self.socketOwnerFbId, self.senderFbId, self.message];
}
@end
