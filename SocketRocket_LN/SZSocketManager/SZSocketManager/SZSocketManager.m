//
//  SZSocketManager.m
//  SZSocketManager
//
//  Created by admin on 2018/12/24.
//  Copyright © 2018 Sidney. All rights reserved.
//

#import "SZSocketManager.h"

//DEBUG  模式下打印日志,当前行
#ifdef DEBUG
#define SZLog(...) printf("[%s] %s [Line %d]: %s\n", __TIME__ ,__PRETTY_FUNCTION__ ,__LINE__, [[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#else
#define SZLog(...)
#endif


//主线程同步队列
#define dispatch_main_sync_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_sync(dispatch_get_main_queue(), block);\
}
//主线程异步队列
#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}



#define SZWS(type)__weak typeof(type)weak##type = type; /// 弱引用
#define SZSS(type)__strong typeof(type)type = weak##type; /// 强引用


@interface SZSocketManager()<SRWebSocketDelegate>

/// 心跳定时器
@property(nonatomic, strong) NSTimer *heartBeatTimer;
/// 无网络的时候检测网络 定时器
@property(nonatomic, strong) NSTimer *pingTimer;
/// 重连时间间隔
@property(nonatomic, assign) NSTimeInterval reDuration;

/// 存储要发送给服务端的数据
@property(nonatomic, strong) NSMutableArray *sourceForSend;


/// 存储要发送给服务端的数据
@property(nonatomic, copy) NSString *URLString;

/// 判断是否主动关闭长连接，如果是主动断开连接，连接失败的代理中，就不用执行 重新连接方法
@property(nonatomic, assign) BOOL isActiveClose;
@end
@implementation SZSocketManager

+ (instancetype)shared{
    static SZSocketManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.reDuration      = 0;
        self.isActiveClose   = NO;
        self.sourceForSend   = [NSMutableArray array];
    }
    return self;
}

// 建立长连接
- (void)open:(NSString *)URLString {
    self.isActiveClose = NO;
    self.webSocket.delegate = nil;
    [self.webSocket close];
    self.webSocket = nil;
    
    self.URLString = URLString;
    self.webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:URLString]];
    self.webSocket.delegate = self;
    [self.webSocket open];
}


- (void)sendPing:(id)sender{
    [self.webSocket sendPing:nil];
    
}


- (void)connect {
    [self open:self.URLString];

}


#pragma mark - SRWebSocketDelegate
///  开启连接成功的回调
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    SZLog(@"【WS】:【Websocket Connected】");
    self.isConnected = YES;
    self.status = SZSocketStatusConnected;
    [self setupHeartBeat];
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    SZLog(@"【WS】:【FAILED】: %@", error);
    self.status = SZSocketStatusDisconnected;
    SZLog(@"连接失败，这里可以实现掉线自动重连，要注意以下几点");
    SZLog(@"1.判断当前网络环境，如果断网了就不要连了，等待网络到来，在发起重连");
    SZLog(@"3.连接次数限制，如果连接失败了，重试10次左右就可以了");

    //判断网络环境 处理重连机制
//    if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable){ //没有网络
//         [self noNetWorkStartTestingTimer];//开启网络检测定时器
//    else{ //有网络
//         [self reConnectServer];//连接失败就重连
//    }
    
    
}


/// 接受服务器推送的数据
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    SZLog(@"【WS】:【RECEIVE】From:%@",message);
    if ([self.delegate respondsToSelector:@selector(socketManagerDidReceiveMessage:)]) {
        [self.delegate socketManagerDidReceiveMessage:message];
    }
}



- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    self.isConnected = NO;
    if (self.isActiveClose) {
        self.status = SZSocketStatusDefault;
        return;
    } else {
        self.status = SZSocketStatusDisconnected;
    }
    SZLog(@"【WS】:【CLOSED】code:%ld,reason:%@,wasClean:%d",code,reason,wasClean);
    //判断网络环境
//        if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable){ //没有网络
//                [self noNetWorkStartTestingTimer];//开启网络检测
//            }else{ //有网络
//                    NSLog(@"关闭连接");
//                    _webSocket = nil;
//                    [self reConnectServer];//连接失败就重连
//                }
    
    
}

/// 收到服务器发送的心跳
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    SZLog(@"【WS】:【PONG:】%@", pongPayload);
}




#pragma mark - Timer
/// 设置❤️定时器
- (void)setupHeartBeat {
    if (self.heartBeatTimer)  return;
    [self destoryHeartBeat];
    
    dispatch_main_async_safe(^{
        self.heartBeatTimer = [NSTimer timerWithTimeInterval:10 target:self selector:@selector(senderheartBeat) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:self.heartBeatTimer forMode:NSRunLoopCommonModes];
    })
    
    
    
}


- (void)reConnect {
    if (self.webSocket.readyState == SR_OPEN) return;
    /// 重连10次
    if (self.reDuration > 1024) {
        self.reDuration = 0;
        return;
    }
    
    SZWS(self)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.reDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakself.webSocket.readyState == SR_OPEN &&
            weakself.webSocket.readyState == SR_CONNECTING) return;
        
        
        [weakself connect];
        SZLog(@"【WS】:正在重连中....");
        
        /// 重连时间间隔2的指数增长
        if (weakself.reDuration == 0) {
            weakself.reDuration = 2;
        } else {
            weakself.reDuration *= 2;
        }
        
        
    });
    
}
//发送心跳
- (void)senderheartBeat{
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        WS(weakSelf);
        dispatch_main_async_safe(^{
                if(weakSelf.webSocket.readyState == RM_OPEN){
                        [weakSelf sendPing:nil];
                    }
            });
}
//没有网络的时候开始定时 -- 用于网络检测
- (void)noNetWorkStartTestingTimer{
        WS(weakSelf);
        dispatch_main_async_safe(^{
                weakSelf.netWorkTestingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:weakSelf selector:@selector(noNetWorkStartTesting) userInfo:nil repeats:YES];
                [[NSRunLoop currentRunLoop] addTimer:weakSelf.netWorkTestingTimer forMode:NSDefaultRunLoopMode];
            });
}
//定时检测网络
- (void)noNetWorkStartTesting{
        //有网络
        if(AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable)
            {
                    //关闭网络检测定时器
                    [self destoryNetWorkStartTesting];
                    //开始重连
                    [self reConnectServer];
                }
}
//取消网络检测
- (void)destoryNetWorkStartTesting{
        WS(weakSelf);
        dispatch_main_async_safe(^{
                if(weakSelf.netWorkTestingTimer)
                    {
                            [weakSelf.netWorkTestingTimer invalidate];
                            weakSelf.netWorkTestingTimer = nil;
                        }
            });
}
//取消心跳
- (void)destoryHeartBeat{
        WS(weakSelf);
        dispatch_main_async_safe(^{
                if(weakSelf.heartBeatTimer)
                    {
                            [weakSelf.heartBeatTimer invalidate];
                            weakSelf.heartBeatTimer = nil;
                        }
            });
}
//关闭长连接
- (void)RMWebSocketClose{
        self.isActivelyClose = YES;
        self.isConnect = NO;
        self.connectType = WebSocketDefault;
        if(self.webSocket)
            {
                    [self.webSocket close];
                    _webSocket = nil;
                }
         
        //关闭心跳定时器
        [self destoryHeartBeat];
         
        //关闭网络检测定时器
        [self destoryNetWorkStartTesting];
}
//发送数据给服务器
- (void)sendDataToServer:(NSString *)data{
        [self.sendDataArray addObject:data];
         
        //[_webSocket sendString:data error:NULL];
         
        //没有网络
        if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable)
            {
                    //开启网络检测定时器
                    [self noNetWorkStartTestingTimer];
                }
        else //有网络
            {
                    if(self.webSocket != nil)
                        {
                                // 只有长连接OPEN开启状态才能调 send 方法，不然会Crash
                                if(self.webSocket.readyState == RM_OPEN)
                                    {
                            //                if (self.sendDataArray.count > 0)
                            //                {
                            //                    NSString *data = self.sendDataArray[0];
                                                [_webSocket sendString:data error:NULL]; //发送数据
                            //                    [self.sendDataArray removeObjectAtIndex:0];
                            //
                            //                }
                                        }
                                else if (self.webSocket.readyState == RM_CONNECTING) //正在连接
                                    {
                                            DLog(@"正在连接中，重连后会去自动同步数据");
                                        }
                                else if (self.webSocket.readyState == RM_CLOSING || self.webSocket.readyState == RM_CLOSED) //断开连接
                                    {
                                            //调用 reConnectServer 方法重连,连接成功后 继续发送数据
                                            [self reConnectServer];
                                        }
                            }
                    else
                        {
                                [self connectServer]; //连接服务器
                            }
                }
}
@end
