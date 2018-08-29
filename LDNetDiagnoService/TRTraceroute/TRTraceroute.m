//
//  TRTraceroute.m
//  TracerouteDemo
//
//  Created by LZephyr on 2018/2/8.
//  Copyright © 2018年 LZephyr. All rights reserved.
//

#import "TRTraceroute.h"
#import "TRTracerouteCommon.h"

#define kTraceStepMaxAttempts 3 // 每一跳尝试的次数
#define kTraceRoutePort 20000 // traceroute所用的端口号
#define kTraceMaxJump 30 // 最多尝试30跳

@interface TRTraceroute()

@property (nonatomic) NSString *ipAddress; // 待诊断的IP地址
@property (nonatomic) NSString *hostname;
@property (nonatomic) NSInteger maxTtl; // 最大跳数
@property (nonatomic) NSMutableArray<TRTracerouteRecord *>* results;

@property (nonatomic) TRTracerouteStepCallback stepCallback;
@property (nonatomic) TRTracerouteFinishCallback finishCallback;
@property (nonatomic) BOOL cancel;

@end

@implementation TRTraceroute

+ (instancetype)startTracerouteWithHost:(NSString *)host
                           stepCallback:(TRTracerouteStepCallback)stepCallback
                                 finish:(TRTracerouteFinishCallback)finish {
    return [TRTraceroute startTracerouteWithHost:host
                                         queue:nil
                                  stepCallback:stepCallback
                                        finish:finish];
}

+ (instancetype)startTracerouteWithHost:(NSString *)host
                                  queue:(dispatch_queue_t)queue
                           stepCallback:(TRTracerouteStepCallback)stepCallback
                                 finish:(TRTracerouteFinishCallback)finish {
    TRTraceroute *traceroute = [[TRTraceroute alloc] initWithHost:host maxTtl:kTraceMaxJump stepCallback:stepCallback finish:finish];
    if (queue != nil) {
        dispatch_async(queue, ^{
            [traceroute run];
        });
    } else {
        [traceroute run];
    }
    return traceroute;
}

- (instancetype)initWithHost:(NSString*)host
                      maxTtl:(NSInteger)maxTtl
                stepCallback:(TRTracerouteStepCallback)stepCallback
                      finish:(TRTracerouteFinishCallback)finish {
    if (self = [super init]) {
        _hostname = host;
        _maxTtl = maxTtl;
        _stepCallback = stepCallback;
        _finishCallback = finish;
        _results = [[NSMutableArray alloc] init];
        _cancel = NO;
    }
    return self;
}

- (void)stopTrace{
    _cancel = YES;
}

#pragma mark - Private

- (void)run {
    NSArray *addresses = [TRTracerouteCommon resolveHost:_hostname];
    if (addresses.count == 0) {
        NSLog(@"DNS解析失败");
        return;
    }
    _ipAddress = [addresses firstObject];
    // 域名有多个地址时只取第一个
    if (addresses.count > 0) {
        NSLog(@"%@ has multiple addresses, using %@", _hostname, _ipAddress);
    }
    
    BOOL isIPv6 = [_ipAddress rangeOfString:@":"].location != NSNotFound;
    // 目标主机地址
    struct sockaddr *remoteAddr = [TRTracerouteCommon makeSockaddrWithAddress:_ipAddress
                                                                       port:(int)kTraceRoutePort
                                                                     isIPv6:isIPv6];
    
    
    if (remoteAddr == NULL) {
        return;
    }
    
    // 创建套接字
    int send_sock;
    if ((send_sock = socket(remoteAddr->sa_family,
                            SOCK_DGRAM,
                            isIPv6 ? IPPROTO_ICMPV6 : IPPROTO_ICMP)) < 0) {
        NSLog(@"创建socket失败");
        return;
    }
    
    // 超时时间3秒
    struct timeval timeout;
    timeout.tv_sec = 3;
    timeout.tv_usec = 0;
    setsockopt(send_sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    
    int ttl = 1;
    BOOL succeed = NO;
    do {
        // 设置数据包TTL，依次递增
        if (setsockopt(send_sock,
                       isIPv6 ? IPPROTO_IPV6 : IPPROTO_IP,
                       isIPv6 ? IPV6_UNICAST_HOPS : IP_TTL,
                       &ttl,
                       sizeof(ttl)) < 0) {
            NSLog(@"setsockopt失败");
        }
        succeed = [self sendAndRecv:send_sock addr:remoteAddr ttl:ttl];
    } while (++ttl <= _maxTtl && !succeed);
    
    close(send_sock);
    
    // traceroute结束，回调结果
    if (_finishCallback) {
        _finishCallback([_results copy], succeed);
    }
}

/**
 向指定目标连续发送3个数据包

 @param sendSock 发送用的socket
 @param addr     地址
 @param ttl      TTL大小
 @return 如果找到目标服务器则返回YES，否则返回NO
 */
- (BOOL)sendAndRecv:(int)sendSock
               addr:(struct sockaddr *)addr
                ttl:(int)ttl {
    char buff[200];
    BOOL finished = NO;
    BOOL isIPv6 = [_ipAddress rangeOfString:@":"].location != NSNotFound;
    socklen_t addrLen = isIPv6 ? sizeof(struct sockaddr_in6) : sizeof(struct sockaddr_in);
    
    // 构建icmp报文
    uint16_t identifier = (uint16_t)ttl;
    NSData *packetData = [TRTracerouteCommon makeICMPPacketWithID:identifier
                                                       sequence:ttl
                                                       isICMPv6:isIPv6];
    
    // 记录结果
    TRTracerouteRecord *record = [[TRTracerouteRecord alloc] init];
    record.ttl = ttl;
    
    BOOL receiveReply = NO;
    NSMutableArray *durations = [[NSMutableArray alloc] init];
    
    // 连续发送3个ICMP报文，记录往返时长
    for (int try = 0; try < kTraceStepMaxAttempts; try ++) {
        NSDate* startTime = [NSDate date];
        // 发送icmp报文
        ssize_t sent = sendto(sendSock,
                              packetData.bytes,
                              packetData.length,
                              0,
                              addr,
                              addrLen);
        if (sent < 0) {
            NSLog(@"发送失败: %s", strerror(errno));
            [durations addObject:[NSNull null]];
            continue;
        }
        
        // 接收icmp数据
        struct sockaddr remoteAddr;
        ssize_t resultLen = recvfrom(sendSock, buff, sizeof(buff), 0, (struct sockaddr*)&remoteAddr, &addrLen);
        if (resultLen < 0) {
            // fail
            [durations addObject:[NSNull null]];
            continue;
        } else {
            receiveReply = YES;
            NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
            
            // 解析IP地址
            NSString* remoteAddress = nil;
            if (!isIPv6) {
                char ip[INET_ADDRSTRLEN] = {0};
                inet_ntop(AF_INET, &((struct sockaddr_in *)&remoteAddr)->sin_addr.s_addr, ip, sizeof(ip));
                remoteAddress = [NSString stringWithUTF8String:ip];
            } else {
                char ip[INET6_ADDRSTRLEN] = {0};
                inet_ntop(AF_INET6, &((struct sockaddr_in6 *)&remoteAddr)->sin6_addr, ip, INET6_ADDRSTRLEN);
                remoteAddress = [NSString stringWithUTF8String:ip];
            }
            
            // 结果判断
            if ([TRTracerouteCommon isTimeoutPacket:buff len:(int)resultLen isIPv6:isIPv6]) {
                // 到达中间节点
                [durations addObject:@(duration)];
                record.ip = remoteAddress;
            } else if ([TRTracerouteCommon isEchoReplyPacket:buff len:(int)resultLen isIPv6:isIPv6] && [remoteAddress isEqualToString:_ipAddress]) {
                // 到达目标服务器
                [durations addObject:@(duration)];
                record.ip = remoteAddress;
                finished = YES;
            } else {
                // 失败
                [durations addObject:[NSNull null]];
            }
        }
    }
    record.recvDurations = [durations copy];
    [_results addObject:record];
    
    // 回调每一步的结果
    if (_stepCallback) {
        _stepCallback(record);
    }
    NSLog(@"%@", record);
    
    return finished;
}

- (BOOL)validateReply {
    return YES;
}

@end
