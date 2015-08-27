//
//  LDNetConnect.m
//  LDNetDiagnoServiceDemo
//
//  Created by ZhangHaiyang on 15-8-5.
//  Copyright (c) 2015年 庞辉. All rights reserved.
//

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

#import "LDNetConnect.h"
#import "LDNetTimer.h"

#define MAXCOUNT_CONNECT 4

@interface LDNetConnect () {
    BOOL _isExistSuccess;  //监测是否有connect成功
    int _connectCount;     //当前执行次数

    int tcpPort;             //执行端口
    NSString *_hostAddress;  //目标域名的IP地址
    NSString *_resultLog;
    NSInteger _sumTime;
    CFSocketRef _socket;
}

@property (nonatomic, assign) long _startTime;  //每次执行的开始时间

@end

@implementation LDNetConnect
@synthesize _startTime;

/**
 * 停止connect
 */
- (void)stopConnect
{
    _connectCount = MAXCOUNT_CONNECT + 1;
}

/**
 * 通过hostaddress和port 进行connect诊断
 */
- (void)runWithHostAddress:(NSString *)hostAddress port:(int)port
{
    _hostAddress = hostAddress;
    tcpPort = port;
    _isExistSuccess = FALSE;
    _connectCount = 0;
    _sumTime = 0;
    _resultLog = @"";
    if (self.delegate && [self.delegate respondsToSelector:@selector(appendSocketLog:)]) {
        [self.delegate
            appendSocketLog:[NSString stringWithFormat:@"connect to host %@ ...", _hostAddress]];
    }
    _startTime = [LDNetTimer getMicroSeconds];
    [self connect];
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (_connectCount < MAXCOUNT_CONNECT);
}

/**
 * 建立socket对hostaddress进行连接
 */
- (void)connect
{
    //创建套接字
    CFSocketContext CTX = {0, (__bridge_retained void *)(self), NULL, NULL, NULL};
    _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                             kCFSocketConnectCallBack, TCPServerConnectCallBack, &CTX);

    //设置地址
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(tcpPort);
    addr.sin_addr.s_addr = inet_addr([_hostAddress UTF8String]);

    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));

    //执行连接
    CFSocketConnectToAddress(_socket, address, 3);
    CFRelease(address);
    CFRunLoopRef cfrl = CFRunLoopGetCurrent();  // 获取当前运行循环
    CFRunLoopSourceRef source =
        CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, _connectCount);  //定义循环对象
    CFRunLoopAddSource(cfrl, source, kCFRunLoopDefaultMode);  //将循环对象加入当前循环中
    CFRelease(source);
}

/**
 * connect回调函数
 */
static void TCPServerConnectCallBack(CFSocketRef socket, CFSocketCallBackType type,
                                     CFDataRef address, const void *data, void *info)
{
    if (data != NULL) {
        printf("connect");
        LDNetConnect *con = (__bridge_transfer LDNetConnect *)info;
        [con readStream:FALSE];
    } else {

        LDNetConnect *con = (__bridge_transfer LDNetConnect *)info;
        [con readStream:TRUE];
    }
}

/**
 * 返回之后的一系列操作
 */
- (void)readStream:(BOOL)success
{
    //    NSString *errorLog = @"";
    if (success) {
        _isExistSuccess = TRUE;
        NSInteger interval = [LDNetTimer computeDurationSince:_startTime] / 1000;
        _sumTime += interval;
        NSLog(@"connect success %ld", (long)interval);
        _resultLog = [_resultLog
            stringByAppendingString:[NSString stringWithFormat:@"%d's time=%ldms, ",
                                                               _connectCount + 1, (long)interval]];
    } else {
        _sumTime = 99999;
        _resultLog =
            [_resultLog stringByAppendingString:[NSString stringWithFormat:@"%d's time=TimeOut, ",
                                                                           _connectCount + 1]];
    }
    if (_connectCount == MAXCOUNT_CONNECT - 1) {
        if (_sumTime >= 99999) {
            _resultLog = [_resultLog substringToIndex:[_resultLog length] - 1];
        } else {
            _resultLog = [_resultLog
                stringByAppendingString:[NSString stringWithFormat:@"average=%ldms",
                                                                   (long)(_sumTime / 4)]];
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(appendSocketLog:)]) {
            [self.delegate appendSocketLog:_resultLog];
        }
    }

    CFRelease(_socket);
    _connectCount++;
    if (_connectCount < MAXCOUNT_CONNECT) {
        _startTime = [LDNetTimer getMicroSeconds];
        [self connect];

    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(connectDidEnd:)]) {
            [self.delegate connectDidEnd:_isExistSuccess];
        }
    }
}

@end
