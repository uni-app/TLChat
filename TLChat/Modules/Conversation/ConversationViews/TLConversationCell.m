//
//  TLConversationCell.m
//  TLChat
//
//  Created by 李伯坤 on 16/1/23.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLConversationCell.h"
#import "NSDate+TLChat.h"
#import "TLMacros.h"
#import "NSFileManager+TLChat.h"
#import "TLGroupDataLoader.h"

#define     CONV_SPACE_X            10.0f
#define     CONV_SPACE_Y            9.5f
#define     REDPOINT_WIDTH          10.0f
#define     AVATAR_HEIGHT           40.0f

@interface TLConversationCell()

@property (nonatomic, strong) UIImageView *avatarImageView;

@property (nonatomic, strong) UILabel *usernameLabel;
@property (nonatomic, strong) UILabel *contextLabel;

@property (nonatomic, strong) UILabel *detailLabel;

@property (nonatomic, strong) UILabel *timeLabel;

@property (nonatomic, strong) UIImageView *remindImageView;

@property (nonatomic, strong) UIView *redPointView;

@end

@implementation TLConversationCell {
 
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.leftSeparatorSpace = CONV_SPACE_X;
        
        [self.contentView addSubview:self.avatarImageView];
        [self.contentView addSubview:self.usernameLabel];
        [self.contentView addSubview:self.contextLabel];
        [self.contentView addSubview:self.detailLabel];
        [self.contentView addSubview:self.timeLabel];
        [self.contentView addSubview:self.remindImageView];
        [self.contentView addSubview:self.redPointView];
        
        [self p_addMasonry];
 
        
    }
    return self;
}

#pragma mark - Public Methods
- (void)setConversation:(TLConversation *)conversation
{
    _conversation = conversation;
    
    if (conversation.avatarPath.length > 0) {
        NSString *path = [NSFileManager pathUserAvatar:conversation.avatarPath];
        [self.avatarImageView setImage:[UIImage imageNamed:path]];
    }
    else if (conversation.avatarURL.length > 0){
        [self.avatarImageView tt_setImageWithURL:TLURL(conversation.avatarURL) placeholderImage:[UIImage imageNamed:DEFAULT_AVATAR_PATH]];
    }
    else if (conversation.convType == TLConversationTypeGroup){
  
        [self.avatarImageView setImage:[[TLGroupDataLoader sharedGroupDataLoader] generateGroupName:conversation.partnerID groupName:conversation.partnerName]];
        
    }else{
        [self.avatarImageView setImage:[UIImage imageNamed:DEFAULT_AVATAR_PATH]]; //should be group avatar
    }
    [self.usernameLabel setText:conversation.partnerName];
    [self.detailLabel setText:conversation.content];
    [self.timeLabel setText:conversation.date.conversaionTimeInfo];
    
    [self.contextLabel setText:conversation.context];
    
    switch (conversation.remindType) {
        case TLMessageRemindTypeNormal:
            [self.remindImageView setHidden:YES];
            break;
        case TLMessageRemindTypeClosed:
            [self.remindImageView setHidden:NO];
            [self.remindImageView setImage:[UIImage imageNamed:@"conv_remind_close"]];
            break;
        case TLMessageRemindTypeNotLook:
            [self.remindImageView setHidden:NO];
            [self.remindImageView setImage:[UIImage imageNamed:@"conv_remind_notlock"]];
            break;
        case TLMessageRemindTypeUnlike:
            [self.remindImageView setHidden:NO];
            [self.remindImageView setImage:[UIImage imageNamed:@"conv_remind_unlike"]];
            break;
        default:
            break;
    }
    
    self.conversation.isRead ? [self markAsRead] : [self markAsUnread];
}


/**
 *  标记为未读
 */
- (void)markAsUnread
{
    if (_conversation) {
//        switch (_conversation.clueType) {
//            case TLClueTypePointWithNumber:
//
//                break;
//            case TLClueTypePoint:
                [self.redPointView setHidden:NO];
//                break;
//            case TLClueTypeNone:
//
//                break;
//            default:
//                break;
//        }
    }
}

/**
 *  标记为已读
 */
- (void)markAsRead
{
    if (_conversation) {
//        switch (_conversation.clueType) {
//            case TLClueTypePointWithNumber:
//
//                break;
//            case TLClueTypePoint:
                [self.redPointView setHidden:YES];
//                break;
//            case TLClueTypeNone:
//
//                break;
//            default:
//                break;
//        }
    }
}

#pragma mark - Private Methods -
- (void)p_addMasonry
{
    [self.avatarImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(CONV_SPACE_X);
//        make.top.mas_equalTo(CONV_SPACE_Y);
//        make.bottom.mas_equalTo(- CONV_SPACE_Y);
        make.centerY.mas_equalTo(self.contentView.mas_centerY);
        make.height.mas_equalTo(AVATAR_HEIGHT);
        make.width.mas_equalTo(self.avatarImageView.mas_height);
    }];
    

    [self.usernameLabel setContentCompressionResistancePriority:100 forAxis:UILayoutConstraintAxisHorizontal];
    [self.usernameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.avatarImageView.mas_right).mas_offset(CONV_SPACE_X);
        make.top.mas_equalTo(self.contentView).mas_offset(10.0);
        make.right.mas_lessThanOrEqualTo(self.timeLabel.mas_left).mas_offset(-5);
    }];
    
    NSString *path = [[NSBundle mainBundle] pathForResource: @"TLChat" ofType: @"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
    
    if ([[dict objectForKey:@"TLChatShowContextInConversationCell"] boolValue]) {
        [self.contextLabel setContentCompressionResistancePriority:105 forAxis:UILayoutConstraintAxisHorizontal];
        [self.contextLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.usernameLabel.mas_bottom).mas_offset(3.0);
            make.left.mas_equalTo(self.usernameLabel);
            make.right.mas_equalTo(self.contentView).mas_offset(-CONV_SPACE_X);
        }];
        
    }else{
 
    }
    
    [self.detailLabel setContentCompressionResistancePriority:110 forAxis:UILayoutConstraintAxisHorizontal];
    [self.detailLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(self.contentView).mas_offset(-10.0);
        make.left.mas_equalTo(self.usernameLabel);
        make.right.mas_lessThanOrEqualTo(self.remindImageView.mas_left);
    }];
    
    [self.timeLabel setContentCompressionResistancePriority:300 forAxis:UILayoutConstraintAxisHorizontal];
    [self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.usernameLabel);
        make.right.mas_equalTo(self.contentView).mas_offset(-CONV_SPACE_X);
    }];
    
    [self.remindImageView setContentCompressionResistancePriority:310 forAxis:UILayoutConstraintAxisHorizontal];
    [self.remindImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.timeLabel);
        make.centerY.mas_equalTo(self.detailLabel);
    }];
    
    [self.redPointView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.avatarImageView.mas_right).mas_offset(-2);
        make.centerY.mas_equalTo(self.avatarImageView.mas_top).mas_offset(2);
        make.width.and.height.mas_equalTo(REDPOINT_WIDTH);
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    
    NSString *path = [[NSBundle mainBundle] pathForResource: @"TLChat" ofType: @"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
    
    if ([[dict objectForKey:@"TLChatAvatarInRoundShape"] boolValue]) {
        [_avatarImageView.layer setCornerRadius:AVATAR_HEIGHT / 2.0];
    }
}

#pragma mark - Getter
- (UIImageView *)avatarImageView
{
    if (_avatarImageView == nil) {
        _avatarImageView = [[UIImageView alloc] init];
        [_avatarImageView.layer setMasksToBounds:YES];
       
        NSString *path = [[NSBundle mainBundle] pathForResource: @"TLChat" ofType: @"plist"];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
        if ([[dict objectForKey:@"TLChatAvatarInRoundShape"] boolValue]) {
            [_avatarImageView.layer setCornerRadius:AVATAR_HEIGHT / 2.0];
        }else{
            [_avatarImageView.layer setCornerRadius:3.0f];
        }
    }
    return _avatarImageView;
}

- (UILabel *)usernameLabel
{
    if (_usernameLabel == nil) {
        _usernameLabel = [[UILabel alloc] init];
        [_usernameLabel setFont:[UIFont fontConversationUsername]];
    }
    return _usernameLabel;
}

- (UILabel *)contextLabel
{
    if (_contextLabel == nil) {
        _contextLabel = [[UILabel alloc] init];
        [_contextLabel setFont:[UIFont fontConversationContext]];
    }
    return _contextLabel;
}

- (UILabel *)detailLabel
{
    if (_detailLabel == nil) {
        _detailLabel = [[UILabel alloc] init];
        [_detailLabel setFont:[UIFont fontConversationDetail]];
        [_detailLabel setTextColor:[UIColor colorTextGray]];
    }
    return _detailLabel;
}

- (UILabel *)timeLabel
{
    if (_timeLabel == nil) {
        _timeLabel = [[UILabel alloc] init];
        [_timeLabel setFont:[UIFont fontConversationTime]];
        [_timeLabel setTextColor:[UIColor colorTextGray1]];
    }
    return _timeLabel;
}

- (UIImageView *)remindImageView
{
    if (_remindImageView == nil) {
        _remindImageView = [[UIImageView alloc] init];
        [_remindImageView setAlpha:0.4];
    }
    return _remindImageView;
}

- (UIView *)redPointView
{
    if (_redPointView == nil) {
        _redPointView = [[UIView alloc] init];
        [_redPointView setBackgroundColor:[UIColor redColor]];
        
        [_redPointView.layer setMasksToBounds:YES];
        [_redPointView.layer setCornerRadius:REDPOINT_WIDTH / 2.0];
        [_redPointView setHidden:YES];
    }
    return _redPointView;
}

@end
