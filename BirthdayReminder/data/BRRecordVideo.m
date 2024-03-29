//
//  BRRecordVideo.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRRecordVideo.h"

@implementation BRRecordVideo

-(id)initWithJsonDic:(NSDictionary *)dic{
    
    self = [super init];
    if (self) {
        
        self.uid = [dic objectForKey:@"_id"];
        self.name = [dic objectForKey:@"name"];
        self.desc = [dic objectForKey:@"desc"];
        self.mainCategoryName = [dic objectForKey:@"mainCategoryName"];
        self.subCategoryName = [dic objectForKey:@"subCategoryName"];
        self.youtubeKey = [dic objectForKey:@"youtubeKey"];
        self.imgName = [dic objectForKey:@"imgName"];
        self.strImgUrl = [NSString stringWithFormat:@"%@/uploads/%@", BASE_URL, self.imgName];
        
        self.created_at = [dic objectForKey:@"created_at"];
        self.modified_at = [dic objectForKey:@"modified_at"];
        
        NSNumber* isFavorite = (NSNumber*) [dic objectForKey:@"isFavorite"];
        self.isUserFavorite = [isFavorite boolValue];
    }
    return self;
}
-(NSString*)description
{
    [super description];
    return [NSString stringWithFormat:@"self.name: %@ \n self.name: %@ \n self.name: %@",  self.name, self.youtubeKey, self.imgName];
}
@end
