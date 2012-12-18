//
//  BRCellSubCategory.m
//  BirthdayReminder
//
//  Created by Peter2 on 12/17/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRCellSubCategory.h"
#import "BRRecordSubCategory.h"
#import "BRStyleSheet.h"
#import "UIImageView+RemoteFile.h"

@implementation BRCellSubCategory

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        //not get called
        
    }
    return self;
    
}

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


-(void)setRecord:(BRRecordSubCategory *)record{
    
    self.nameLb.text = record.name;
    self.descLb.text = record.desc; 
    
}

-(void) setNameLb:(UILabel *)nameLb
{
    _nameLb = nameLb;
    if (_nameLb) {
        [BRStyleSheet styleLabel:_nameLb withType:BRLabelTypeName];
    }
}

-(void) setDescLb:(UILabel *)descLb
{
    _descLb = descLb;
    if (_descLb) {
        [BRStyleSheet styleLabel:_descLb withType:BRLabelTypeBirthdayDate];
    }
}


@end
