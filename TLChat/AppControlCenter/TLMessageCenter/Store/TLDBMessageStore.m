//
//  TLDBMessageStore.m
//  TLChat
//
//  Created by 李伯坤 on 16/3/13.
//  Copyright © 2016年 李伯坤. All rights reserved.
//

#import "TLDBMessageStore.h"
#import "TLDBMessageStoreSQL.h"
#import "TLMacros.h"
#import <Parse/Parse.h>
#import "TLImageMessage.h"

@implementation TLDBMessageStore

- (id)init
{
    if (self = [super init]) {
        self.dbQueue = [TLDBManager sharedInstance].messageQueue;
        BOOL ok = [self createTable];
        if (!ok) {
            DDLogError(@"DB: 聊天记录表创建失败");
        }
    }
    return self;
}

- (BOOL)createTable
{
    NSString *sqlString = [NSString stringWithFormat:SQL_CREATE_MESSAGE_TABLE, MESSAGE_TABLE_NAME];
    return [self createTable:MESSAGE_TABLE_NAME withSQL:sqlString];
}

- (BOOL)addMessage:(TLMessage *)message
{
    if (message == nil || message.messageID == nil || message.userID == nil || (message.friendID == nil && message.groupID == nil)) {
        return NO;
    }
    
    NSString *fid = @"";
    NSString *subfid;
    if (message.partnerType == TLPartnerTypeUser) {
        fid = message.friendID;
    }
    else {
        fid = message.groupID;
        subfid = message.friendID;
    }
    
    NSString *sqlString = [NSString stringWithFormat:SQL_ADD_MESSAGE, MESSAGE_TABLE_NAME];
    NSString * newMessageID = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 10000)];
    NSArray *arrPara = [NSArray arrayWithObjects:
                        newMessageID,
                        message.userID,
                        fid,
                        TLNoNilString(subfid),
                        TLTimeStamp(message.date),
                        [NSNumber numberWithInteger:message.partnerType],
                        [NSNumber numberWithInteger:message.ownerTyper],
                        [NSNumber numberWithInteger:message.messageType],
                        [message.content mj_JSONString],
                        [NSNumber numberWithInteger:message.sendState],
                        [NSNumber numberWithInteger:message.readState],
                        @"", @"", @"", @"", @"", nil];
    BOOL ok = [self excuteSQL:sqlString withArrParameter:arrPara];
    
    /// Server code, only save outgoing message. otherwise dead loop
    if (message.messageID == nil) {
        
        
        PFObject * msgObject = [PFObject objectWithClassName:kParseClassNameMessage];
        msgObject[@"message"] = [message.content mj_JSONString];
    //    msgObject[@"readAt"] = @(message.readState);
        msgObject[@"sender"] = [PFUser currentUser].objectId; // quick way to set pointer
        
        if ([message isKindOfClass:[TLImageMessage class]]) {
            TLImageMessage * imageMessage = (TLImageMessage*)message;
            if (imageMessage.imageData) {
                
                PFFile * file = [PFFile fileWithData:imageMessage.imageData];
                msgObject[@"attachment"] = file;
                
            }
        }
        

        NSString * dialogName = @"";
        if (message.partnerType == TLPartnerTypeUser) {
            dialogName = [self makeDialogNameForFriend:  message.friendID myId:message.userID];
        }else {
            dialogName = message.groupID;
        }
        
        msgObject[@"dialogName"] = dialogName;
        [msgObject saveInBackground];
//        PFQuery * query = [PFQuery queryWithClassName:kParseClassNameDialog];
//        [query getFirstObjectInBackgroundWithBlock:^(PFObject * _Nullable object, NSError * _Nullable error) {
//
//            if (object) {
//                msgObject[@"dialog"] = object;
//                [msgObject saveEventually];
//            }
//
//        }];
        
    }
    
    
    
    
    
    return ok;
}

// TODO: move to a helper class
- (NSString *)makeDialogNameForFriend:(NSString *)fid myId:(NSString *)uid{
    NSArray * ids = [@[uid, fid]  sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [ids componentsJoinedByString:@":"];
}

- (void)messagesByUserID:(NSString *)userID partnerID:(NSString *)partnerID fromDate:(NSDate *)date count:(NSUInteger)count complete:(void (^)(NSArray *, BOOL))complete
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:
                        SQL_SELECT_MESSAGES_PAGE,
                        MESSAGE_TABLE_NAME,
//                        userID,
                        partnerID,
                        [NSString stringWithFormat:@"%lf", date.timeIntervalSince1970],
                        (long)(count + 1)];

    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage *message = [self p_createDBMessageByFMResultSet:retSet];
            [data insertObject:message atIndex:0];
        }
        [retSet close];
    }];
    
    BOOL hasMore = NO;
    if (data.count == count + 1) {
        hasMore = YES;
        [data removeObjectAtIndex:0];
    }
    complete(data, hasMore);
}

- (NSArray *)chatFilesByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CHAT_FILES, MESSAGE_TABLE_NAME, userID, partnerID];
    
    __block NSDate *lastDate = [NSDate date];
    __block NSMutableArray *array = [[NSMutableArray alloc] init];
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage * message = [self p_createDBMessageByFMResultSet:retSet];
            if (([message.date isThisWeek] && [lastDate isThisWeek]) || (![message.date isThisWeek] && [lastDate isSameMonthAsDate:message.date])) {
                [array addObject:message];
            }
            else {
                lastDate = message.date;
                if (array.count > 0) {
                    [data addObject:array];
                }
                array = [[NSMutableArray alloc] initWithObjects:message, nil];
            }
        }
        if (array.count > 0) {
            [data addObject:array];
        }
        [retSet close];
    }];
    return data;
}

- (NSArray *)chatImagesAndVideosByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    __block NSMutableArray *data = [[NSMutableArray alloc] init];
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_CHAT_MEDIA, MESSAGE_TABLE_NAME, partnerID];
    
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            TLMessage *message = [self p_createDBMessageByFMResultSet:retSet];
            [data addObject:message];
        }
        [retSet close];
    }];
    return data;
}

- (TLMessage *)lastMessageByUserID:(NSString *)userID partnerID:(NSString *)partnerID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_SELECT_LAST_MESSAGE, MESSAGE_TABLE_NAME, MESSAGE_TABLE_NAME, userID, partnerID];
    __block TLMessage * message;
    [self excuteQuerySQL:sqlString resultBlock:^(FMResultSet *retSet) {
        while ([retSet next]) {
            message = [self p_createDBMessageByFMResultSet:retSet];
        }
        [retSet close];
    }];
    return message;
}

- (BOOL)deleteMessageByMessageID:(NSString *)messageID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_MESSAGE, MESSAGE_TABLE_NAME, messageID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

- (BOOL)deleteMessagesByUserID:(NSString *)userID partnerID:(NSString *)partnerID;
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_FRIEND_MESSAGES, MESSAGE_TABLE_NAME, userID, partnerID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

- (BOOL)deleteMessagesByUserID:(NSString *)userID
{
    NSString *sqlString = [NSString stringWithFormat:SQL_DELETE_USER_MESSAGES, MESSAGE_TABLE_NAME, userID];
    BOOL ok = [self excuteSQL:sqlString, nil];
    return ok;
}

#pragma mark - Private Methods -
- (TLMessage *)p_createDBMessageByFMResultSet:(FMResultSet *)retSet
{
    TLMessageType type = [retSet intForColumn:@"msg_type"];
    TLMessage * message = [TLMessage createMessageByType:type];
    message.messageID = [retSet stringForColumn:@"msgid"];
    message.userID = [retSet stringForColumn:@"uid"];
    message.partnerType = [retSet intForColumn:@"partner_type"];
    if (message.partnerType == TLPartnerTypeGroup) {
        message.groupID = [retSet stringForColumn:@"fid"];
        message.friendID = [retSet stringForColumn:@"subfid"];
    }
    else {
        message.friendID = [retSet stringForColumn:@"fid"];
        message.groupID = [retSet stringForColumn:@"subfid"];
    }
    NSString *dateString = [retSet stringForColumn:@"date"];
    message.date = [NSDate dateWithTimeIntervalSince1970:dateString.doubleValue];
    message.ownerTyper = [retSet intForColumn:@"own_type"];
    NSString *content = [retSet stringForColumn:@"content"];
    message.content = [[NSMutableDictionary alloc] initWithDictionary:[content mj_JSONObject]];
    message.sendState = [retSet intForColumn:@"send_status"];
    message.readState = [retSet intForColumn:@"received_status"];
    return message;
}

@end
