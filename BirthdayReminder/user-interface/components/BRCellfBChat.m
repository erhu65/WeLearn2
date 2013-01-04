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
    
    self.lbFbUserName.text =  record.sender;
    self.lbFbUserMsg.text = record.message;
    
    NSString *formattedDateString = [self.dateFormatter stringFromDate:record.created_at];
    self.lbChatDatetime.text = formattedDateString;
    self.lbVideoName.text = @"";
    if([record.type isEqualToString:@"server"]){

        self.imvThumb.image = [UIImage imageNamed:kSharedModel.theme[@"Icon"]];
    } else if (record.dataImg == nil) {
        if ([record.strImgUrl length] > 0) {
            [self.imvThumb setImageWithFbThumb:record.senderFbId placeHolderImage:[UIImage imageNamed:@"icon-birthday-cake.png"]];
        }
        else self.imvThumb.image = [UIImage imageNamed:@"icon-birthday-cake.png"];
    }
    else {
        self.imvThumb.image = [UIImage imageWithData:record.dataImg];
    }
    if([record.type isEqualToString:@"chat"]){
        
        self.lbVideoName.text = record.videoName;
       self.accessoryView = [self _makeDetailDisclosureButton];
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (UIButton *) _makeDetailDisclosureButton
{
    UIButton * button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(0, 0, 30, 30)];
    [button setImage:[UIImage imageNamed:kSharedModel.theme[@"eyeball"]] forState:UIControlStateNormal];
    [button addTarget: self
               action: @selector(_accessoryButtonTapped:withEvent:)
     forControlEvents: UIControlEventTouchUpInside];
    return (button);
}
- (void) _accessoryButtonTapped: (UIControl *) button withEvent: (UIEvent *) event
{
    [self.tb.delegate tableView: self.tb accessoryButtonTappedForRowWithIndexPath:self.indexPath];
}

-(void) setLbFbUserName:(UILabel *)lbFbUserName
{
    _lbFbUserName = lbFbUserName;
    if (_lbFbUserName) {
        [BRStyleSheet styleLabel:_lbFbUserName withType:BRLabelTypeDaysUntilBirthdaySubText];
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
        [BRStyleSheet styleLabel:_lbChatDatetime withType:BRLabelTypeDaysUntilBirthdaySubText];
    }
}

-(void)setLbVideoName:(UILabel *)lbVideoName{

    _lbVideoName = lbVideoName;
    if (_lbVideoName) {
        [BRStyleSheet styleLabel:_lbVideoName withType:BRLabelTypeDaysUntilBirthdaySubText];
    }
}

@end
