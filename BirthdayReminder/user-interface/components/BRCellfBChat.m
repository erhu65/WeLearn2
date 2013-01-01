//
//  BRCellVideo.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCellfBChat.h"
#import "BRRecordFbChat.h"
#import "BRStyleSheet.h"
#import "UIImageView+RemoteFile.h"

@implementation BRCellfBChat

-(id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(self){
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm:ss"];
        
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}



-(void)setRecord:(BRRecordFbChat *)record{
    
    self.lbFbUserName.text = record.sender;
    self.lbFbUserMsg.text = record.message;
    
    NSString *formattedDateString = [self.dateFormatter stringFromDate:record.created_at];
    self.lbChatDatetime.text = formattedDateString;

    
    if (record.dataImg == nil)
    {
        if ([record.strImgUrl length] > 0) {
            [self.imvThumb setImageWithRemoteFileURL:record.strImgUrl placeHolderImage:[UIImage imageNamed:@"icon-birthday-cake.png"]];
        }
        else self.imvThumb.image = [UIImage imageNamed:@"icon-birthday-cake.png"];
    }
    else {
        self.imvThumb.image = [UIImage imageWithData:record.dataImg];
    }
}

-(void) setLbFbUserName:(UILabel *)lbFbUserName
{
    _lbFbUserName = lbFbUserName;
    if (_lbFbUserName) {
        [BRStyleSheet styleLabel:_lbFbUserName withType:BRLabelTypeName];
    }
}

-(void) setLbFbUserMsg:(UILabel *)lbFbUserMsg
{
    _lbFbUserMsg = lbFbUserMsg;
    if (_lbFbUserMsg) {
        [BRStyleSheet styleLabel:_lbFbUserMsg withType:BRLabelTypeLarge];
    }
}


-(void) setLbChatDatetime:(UILabel *)lbChatDatetime
{
    _lbChatDatetime = lbChatDatetime;
    if (_lbChatDatetime) {
        [BRStyleSheet styleLabel:_lbFbUserMsg withType:BRLabelTypeDaysUntilBirthday];
    }
}


@end
