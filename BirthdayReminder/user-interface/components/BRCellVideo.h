//
//  BRCellVideo.h
//  BirthdayReminder
//
//  Created by Peter2 on 12/18/12.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//



@class BRRecordVideo;

@interface BRCellVideo : UITableViewCell

@property(nonatomic, strong)BRRecordVideo* record;
@property(nonatomic, strong)NSIndexPath* indexPath;

@property(nonatomic, weak)IBOutlet UILabel* lbName;
@property(nonatomic, weak)IBOutlet UILabel* lbDesc;
@property(nonatomic, weak)IBOutlet UIImageView* imvThumb;

@property (weak, nonatomic) IBOutlet UIButton *btnFavorite;
-(void)toggleBtnFavoriteTitle:(BOOL)isFavorite;

@end
