//
//  BRCellVideo.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCellVideo.h"
#import "BRRecordVideo.h"
#import "BRStyleSheet.h"
#import "UIImageView+RemoteFile.h"

@implementation BRCellVideo

-(id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if(self){
        
      
        
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)setRecord:(BRRecordVideo *)record{
    
    self.lbName.text = record.name;
    self.lbDesc.text = record.desc; 
    
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

-(void) setLbName:(UILabel *)lbName
{
    _lbName = lbName;
    if (_lbName) {
        [BRStyleSheet styleLabel:_lbName withType:BRLabelTypeName];
    }
}

-(void) setLbDesc:(UILabel *)lbDesc
{
    _lbDesc = lbDesc;
    if (_lbDesc) {
        [BRStyleSheet styleLabel:_lbDesc withType:BRLabelTypeBirthdayDate];
    }
}

@end
