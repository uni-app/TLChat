//
//  TLChatBaseViewController.m
//  TLChat
//
//  Created by 李伯坤 on 16/2/15.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLChatBaseViewController.h"
#import "TLChatBaseViewController+Proxy.h"
#import "TLChatBaseViewController+ChatBar.h"
#import "TLChatBaseViewController+MessageDisplayView.h"
#import "UIImage+Size.h"
#import "NSFileManager+TLChat.h"


@import Parse;
@import ParseLiveQuery;
@import Parse.PFQuery;

@interface TLChatBaseViewController()
@property (nonatomic, strong) PFLiveQueryClient *client;
@property (nonatomic, strong) PFQuery *query;
@property (nonatomic, strong) PFLiveQuerySubscription *subscription; // must use properyt to hold reference.
@end


@implementation TLChatBaseViewController

- (void)loadView
{
    [super loadView];
    
    [self.view addSubview:self.messageDisplayView];
    [self.view addSubview:self.chatBar];
    
    [self p_addMasonry];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self loadKeyboard];
    
    self.client = [[PFLiveQueryClient alloc] init];
    
    self.query = [PFQuery queryWithClassName:kParseClassNameMessage];
    
    if (self.converstaion.date) {
        [self.query whereKey:@"createdAt" greaterThan:self.converstaion.date];
        NSLog(@"TLConversation last message date: %@", self.converstaion.date);
    }
    
//    [self.query whereKey:@"sender" notEqualTo:[PFUser currentUser].objectId]; //livequery doesn't work with pointer
    
    [self.query orderByAscending:@"createdAt"];
    
    [self.query findObjectsInBackgroundWithBlock:^(NSArray * _Nullable objects, NSError * _Nullable error) {
        for (PFObject * message in [objects sortedArrayUsingComparator:^NSComparisonResult(PFObject *  _Nonnull obj1, PFObject *  _Nonnull obj2) {
            return [obj1[@"createdAt"] isEarlierThanDate:obj2[@"createdAt"]];
        }]) {
            
            [self processMessageFromServer:message];
        }
    }];
    
    
    self.subscription = [self.client  subscribeToQuery:self.query];
    
 
    self.subscription = [self.subscription addSubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
        NSLog(@"Subscribed");
    }];
    
    self.subscription = [self.subscription addUnsubscribeHandler:^(PFQuery<PFObject *> * _Nonnull query) {
        NSLog(@"unsubscribed");
    }];
    
    self.subscription = [self.subscription addEnterHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull object) {
        NSLog(@"enter");
    }];
    
    self.subscription = [self.subscription addEventHandler:^(PFQuery<PFObject *> * _Nonnull query, PFLiveQueryEvent * _Nonnull event) {
        NSLog(@"event: %@", event);
    }];
    
    self.subscription = [self.subscription addDeleteHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
        NSLog(@"message deleted: %@ %@",message.createdAt, message.objectId);
    }];
    
    
    __weak TLChatBaseViewController * weakSelf = self;
    self.subscription = [self.subscription addCreateHandler:^(PFQuery<PFObject *> * _Nonnull query, PFObject * _Nonnull message) {
        
      
        [weakSelf processMessageFromServer:message];
        
        
    }];
}

- (void)processMessageFromServer:(PFObject *)message {
    
    NSLog(@"message received: %@ %@ %@", message.objectId, message[@"message"], message[@"sender"]);
    
    NSDictionary * dict = [message[@"message"] mj_JSONObject];
    
    __weak TLChatBaseViewController * weakSelf = self;
    
    if (dict ) {
        if (dict[@"text"]) {
            TLTextMessage *message1 = [[TLTextMessage alloc] init];
            message1.messageID = message.objectId;
            if ([[self.user chat_userID] isEqualToString: message[@"sender"]]) {
                message1.fromUser = weakSelf.user;
                message1.ownerTyper = TLMessageOwnerTypeSelf;
                
            }else{
                message1.fromUser = weakSelf.partner;
                message1.ownerTyper = TLMessageOwnerTypeFriend;
            }
            
            message1.userID = message[@"sender"];
            message1.text = dict[@"text"];
            [weakSelf receivedMessage:message1];
        }else if (message[@"attachment"]) {
            TLImageMessage *message1 = [[TLImageMessage alloc] init];
            message1.messageID = message.objectId;
            if ([[self.user chat_userID]  isEqualToString: message[@"sender"]]) {
                message1.fromUser = weakSelf.user;
                message1.ownerTyper = TLMessageOwnerTypeSelf;
                
            }else{
                message1.fromUser = weakSelf.partner;
            }
            message1.userID = message[@"sender"];
            message1.ownerTyper = TLMessageOwnerTypeFriend;
            PFFile * file = message[@"attachment"];
            if (dict[@"w"] && dict[@"h"]) {
                message1.imageSize = CGSizeMake([dict[@"w"] floatValue], [dict[@"h"] floatValue]);
            }
            if (file && ![file isKindOfClass:[NSNull class]]) {
                [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error) {
                    if (!error) {
                        
                        NSString *imageName = dict[@"path"];
                        NSString *imagePath = [NSFileManager pathUserChatImage:imageName];
                        // TODO: check file exist
                        [[NSFileManager defaultManager] createFileAtPath:imagePath contents:imageData attributes:nil];
                        
                        // TODO: use thumbnail
                        message1.imagePath = imageName; //no path needed here, cell will prefix it when rendering
                        
                        [weakSelf receivedMessage:message1];
                    } else {
                        [weakSelf receivedMessage:message1];
                    }
                }];
            }
            
            
        }
    }
    
    
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[TLAudioPlayer sharedAudioPlayer] stopPlayingAudio];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
    [[TLMoreKeyboard keyboard] dismissWithAnimation:NO];
    [[TLEmojiKeyboard keyboard] dismissWithAnimation:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#ifdef DEBUG_MEMERY
    NSLog(@"dealloc ChatBaseVC");
#endif
}

#pragma mark - # Public Methods
- (void)setPartner:(id<TLChatUserProtocol>)partner
{
    if (_partner && [[_partner chat_userID] isEqualToString:[partner chat_userID]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messageDisplayView scrollToBottomWithAnimation:NO];
        });
        return;
    }
    _partner = partner;
    [self.navigationItem setTitle:[_partner chat_username]];
    [self resetChatVC];
}

- (void)setChatMoreKeyboardData:(NSMutableArray *)moreKeyboardData
{
    [self.moreKeyboard setChatMoreKeyboardData:moreKeyboardData];
}

- (void)setChatEmojiKeyboardData:(NSMutableArray *)emojiKeyboardData
{
    [self.emojiKeyboard setEmojiGroupData:emojiKeyboardData];
}

- (void)resetChatVC
{
    NSString *chatViewBGImage;
    if (self.partner) {
        chatViewBGImage = [[NSUserDefaults standardUserDefaults] objectForKey:[@"CHAT_BG_" stringByAppendingString:[self.partner chat_userID]]];
    }
    if (chatViewBGImage == nil) {
        chatViewBGImage = [[NSUserDefaults standardUserDefaults] objectForKey:@"CHAT_BG_ALL"];
        if (chatViewBGImage == nil) {
            [self.view setBackgroundColor:[UIColor colorGrayCharcoalBG]];
        }
        else {
            NSString *imagePath = [NSFileManager pathUserChatBackgroundImage:chatViewBGImage];
            UIImage *image = [UIImage imageNamed:imagePath];
            [self.view setBackgroundColor:[UIColor colorWithPatternImage:image]];
        }
    }
    else {
        NSString *imagePath = [NSFileManager pathUserChatBackgroundImage:chatViewBGImage];
        UIImage *image = [UIImage imageNamed:imagePath];
        [self.view setBackgroundColor:[UIColor colorWithPatternImage:image]];
    }
    
    [self resetChatTVC];
}

/**
 *  发送图片消息
 */
- (void)sendImageMessage:(UIImage *)image
{
    NSData *imageData = (UIImagePNGRepresentation(image) ? UIImagePNGRepresentation(image) :UIImageJPEGRepresentation(image, 0.5));
    NSString *imageName = [NSString stringWithFormat:@"%lf.jpg", [NSDate date].timeIntervalSince1970];
    NSString *imagePath = [NSFileManager pathUserChatImage:imageName];
    [[NSFileManager defaultManager] createFileAtPath:imagePath contents:imageData attributes:nil];
    
    TLImageMessage *message = [[TLImageMessage alloc] init];
    message.fromUser = self.user;
    message.ownerTyper = TLMessageOwnerTypeSelf;
    message.imagePath = imageName;
    message.imageSize = image.size;
    message.imageData = imageData;
    [self sendMessage:message];
    
    // TODO: remove auto reply code below
//    if ([self.partner chat_userType] == TLChatUserTypeUser) {
//        TLImageMessage *message1 = [[TLImageMessage alloc] init];
//        message1.fromUser = self.partner;
//        message1.ownerTyper = TLMessageOwnerTypeFriend;
//        message1.imagePath = imageName;
//        message1.imageSize = image.size;
//        [self receivedMessage:message1];
//    }
//    else {
//        for (id<TLChatUserProtocol> user in [self.partner groupMembers]) {
//            TLImageMessage *message1 = [[TLImageMessage alloc] init];
//            message1.friendID = [user chat_userID];
//            message1.fromUser = user;
//            message1.ownerTyper = TLMessageOwnerTypeFriend;
//            message1.imagePath = imageName;
//            message1.imageSize = image.size;
//            [self receivedMessage:message1];
//        }
//    }
}

#pragma mark - # Private Methods
- (void)p_addMasonry
{
    [self.messageDisplayView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.and.left.and.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.chatBar.mas_top);
    }];
    [self.chatBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.and.right.and.bottom.mas_equalTo(self.view);
        make.height.mas_greaterThanOrEqualTo(TABBAR_HEIGHT);
    }];
    [self.view layoutIfNeeded];
}

#pragma mark - # Getter
- (TLChatMessageDisplayView *)messageDisplayView
{
    if (_messageDisplayView == nil) {
        _messageDisplayView = [[TLChatMessageDisplayView alloc] init];
        [_messageDisplayView setDelegate:self];
    }
    return _messageDisplayView;
}

- (TLChatBar *)chatBar
{
    if (_chatBar == nil) {
        _chatBar = [[TLChatBar alloc] init];
        [_chatBar setDelegate:self];
    }
    return _chatBar;
}

- (TLEmojiDisplayView *)emojiDisplayView
{
    if (_emojiDisplayView == nil) {
        _emojiDisplayView = [[TLEmojiDisplayView alloc] init];
    }
    return _emojiDisplayView;
}

- (TLImageExpressionDisplayView *)imageExpressionDisplayView
{
    if (_imageExpressionDisplayView == nil) {
        _imageExpressionDisplayView = [[TLImageExpressionDisplayView alloc] init];
    }
    return _imageExpressionDisplayView;
}

- (TLRecorderIndicatorView *)recorderIndicatorView
{
    if (_recorderIndicatorView == nil) {
        _recorderIndicatorView = [[TLRecorderIndicatorView alloc] init];
    }
    return _recorderIndicatorView;
}

@end
