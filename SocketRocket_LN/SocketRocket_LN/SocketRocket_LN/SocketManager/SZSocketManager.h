//
//  SZSocketManager.h
//  SocketRocket_LN
//
//  Created by chaobi on 2018/3/26.
//  Copyright © 2018年 Sidney. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSUInteger, SZSocketStatus) {
    SZSocketStatusConnected, // 已连接
    SZSocketStatusFailed,    // 失败
    SZSocketStatusServerClosed, // 服务器关闭
    SZSocketStatusUserClosed,  // 用户关闭
    SZSocketStatusReceived     // 接受消息
};

typedef NS_ENUM(NSUInteger, SZSocketReceiveType) {
    SZSocketReceiveTypeMsg,
    SZSocketReceiveTypePong
};

typedef void(^SocketDidConnectBlock)(void);
typedef void(^SocketDidFailBlock)(NSError *error);
typedef void(^SocketDidCloseBlock)(NSInteger code,NSString *reason,BOOL wasClean);
typedef void(^SocketDidReceiveBlock)(id message ,SZSocketReceiveType type);

@interface SZSocketManager : NSObject
@property (nonatomic,copy)SocketDidConnectBlock connect;
@property (nonatomic,copy)SocketDidReceiveBlock receive;
@property (nonatomic,copy)SocketDidFailBlock failure;
@property (nonatomic,copy)SocketDidCloseBlock close;
@property (nonatomic,assign,readonly)SZSocketStatus socketStatus;

/// 超时重连时间，默认1秒
@property (nonatomic,assign)NSTimeInterval overtime;
/// 重连次数,默认5次
@property (nonatomic, assign)NSUInteger reconnectCount;

+ (instancetype)shareManager;


/**
 开启socket
 
 @param urlStr 服务器地址
 @param connect 连接成功回调
 @param receive 接收消息回调
 @param failure 失败回调
 */
- (void)open:(NSString *)urlStr
     connect:(SocketDidConnectBlock)connect
     receive:(SocketDidReceiveBlock)receive
     failure:(SocketDidFailBlock)failure;

// 关闭回调
- (void)close:(SocketDidCloseBlock)close;
// 发送消息:NSString/NSData
- (void)send:(id)data;

@end
