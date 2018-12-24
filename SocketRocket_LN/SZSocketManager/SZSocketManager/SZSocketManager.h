//
//  SZSocketManager.h
//  SZSocketManager
//
//  Created by admin on 2018/12/24.
//  Copyright © 2018 Sidney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SRWebSocket.h>


typedef NS_ENUM(NSUInteger,SZSocketStatus){
    SZSocketStatusDefault = 0,      //初始状态,未连接
    SZSocketStatusConnected,        //已连接
    SZSocketStatusDisconnected       //连接后断开
};

@class SZSocketManager;

@protocol SZSocketManagerDelegate <NSObject>
- (void)socketManagerDidReceiveMessage:(NSString *)msg;
@end

@interface SZSocketManager : NSObject

///  client socket
@property (nonatomic, strong) SRWebSocket *webSocket;
/// 遵守协议 接受返回的数据
@property(nonatomic,weak)  id<SZSocketManagerDelegate> delegate;
/// 是否建立连接
@property (nonatomic, assign) BOOL isConnected;
/// socket的状态
@property (nonatomic, assign) SZSocketStatus status;

+(instancetype)shared;

- (void)open:(NSString *)URLString;//建立长连接
- (void)reConnect;//重新连接
- (void)close;//关闭长连接
- (void)send:(NSString *)data;//发送数据给服务器

@end



