//
//  ViewController.m
//  SocketRocket_LN
//
//  Created by Sidney on 2018/3/26.
//  Copyright © 2018年 Sidney. All rights reserved.
//

#import "ViewController.h"
#import "SZSocketManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self socketRocketDemo];
    
}

- (void)socketRocketDemo {
    [[SZSocketManager shareManager] open:@"xxxxx" connect:^{
        
    } receive:^(id message, SZSocketReceiveType type) {
        
    } failure:^(NSError *error) {
        
    }];

}

@end
