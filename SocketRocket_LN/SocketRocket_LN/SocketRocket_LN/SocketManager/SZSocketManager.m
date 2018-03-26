//
//  SZSocketManager.m
//  SocketRocket_LN
//
//  Created by chaobi on 2018/3/26.
//  Copyright © 2018年 Sidney. All rights reserved.
//

#import "SZSocketManager.h"
#import <SocketRocket/SocketRocket.h>

@interface SZSocketManager ()<SRWebSocketDelegate>
@property (nonatomic,strong)SRWebSocket *webSocket;
@property (nonatomic,assign)SZSocketStatus socketStatus;
@property (nonatomic,weak)NSTimer *timer;
@property (nonatomic,copy)NSString *urlString;
@end

@implementation SZSocketManager {
    NSInteger _reconnectCounter;
}

+ (instancetype)shareManager {
    static SZSocketManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.overtime = 1;
        instance.reconnectCount = 5;
    });
    return instance;
}

- (void)open:(NSString *)urlStr connect:(SocketDidConnectBlock)connect receive:(SocketDidReceiveBlock)receive failure:(SocketDidFailBlock)failure {
    self.connect = connect;
    self.receive = receive;
    self.failure = failure;
    [self sz_open:urlStr];
}
- (void)close:(SocketDidCloseBlock)close {
    self.close = close;
    [self sz_close];
}

- (void)send:(id)data {
    switch (self.socketStatus) {
        case SZSocketStatusConnected:
        case SZSocketStatusReceived:
        {
            NSLog(@"发送中...");
            [self.webSocket send:data];
            break;
        }
        case SZSocketStatusFailed:
            NSLog(@"发送失败");
            break;
        case SZSocketStatusServerClosed:
            NSLog(@"已经关闭");
            break;
        case SZSocketStatusUserClosed:
            NSLog(@"已经关闭");
            break;
    }
}

#pragma mark - private method
- (void)sz_open:(id)params {
    NSString *urlStr = nil;
    if ([params isKindOfClass:[NSString class]]) {
        urlStr = params;
    } else if ([params isKindOfClass:[NSTimer class]]) {
        NSTimer *timer = (NSTimer *)params;
        urlStr = [timer userInfo];
    }
    self.urlString = urlStr;
    [self.webSocket close];
    self.webSocket.delegate = nil;
    
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
    self.webSocket.delegate = self;
    [self.webSocket open];
}
- (void)sz_close {
    [self.webSocket close];
    self.webSocket = nil;
    [self.timer invalidate];
    self.timer = nil;
}
- (void)sz_reconnect{
    // 计数+1
    if (_reconnectCounter < self.reconnectCount - 1) {
        _reconnectCounter ++;
        // 开启定时器
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.overtime target:self selector:@selector(sz_open:) userInfo:self.urlString repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.timer = timer;
    }
    else{
        NSLog(@"Websocket Reconnected Outnumber ReconnectCount");
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
        return;
    }
    
}

#pragma mark -- SRWebSocketDelegate
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"Websocket Connected");
    self.connect? self.connect() : nil;
    self.socketStatus = SZSocketStatusConnected;
    // 开启成功重置连接计数器
    _reconnectCounter = 0;
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@":( Websocket Failed With Error %@", error);
    self.socketStatus = SZSocketStatusFailed;
    self.failure? self.failure(error): nil;
    // reconnect
    [self sz_reconnect];
}
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@":( Websocket Receive With message %@", message);
    self.socketStatus = SZSocketStatusReceived;
    self.receive ? self.receive(message,SZSocketReceiveTypeMsg): nil;
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"Closed Reason:%@  code = %zd",reason,code);
    if (reason) {
        self.socketStatus = SZSocketStatusServerClosed;
        [self sz_reconnect];
    } else {
        self.socketStatus = SZSocketStatusUserClosed;
    }
    
    self.close ?self.close(code, reason, wasClean) : nil;
    self.webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    self.receive ? self.receive(pongPayload, SZSocketReceiveTypePong) : nil;
}

- (void)dealloc {
    [self sz_close];
}
@end
