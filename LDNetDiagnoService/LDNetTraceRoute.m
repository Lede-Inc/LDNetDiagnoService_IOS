//
//  TraceRoute.m
//  LDNetCheckServiceDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#include <netdb.h>
#include <arpa/inet.h>
#include <sys/time.h>

#import "LDNetTraceRoute.h"
#import "LDNetTimer.h"
#import "LDSimplePing.h"

@implementation HTTraceRouteRecord

@end

@implementation HTTraceRouteResult

@end

@implementation LDNetTraceRoute

/**
 * 初始化
 */
- (LDNetTraceRoute *)init
{
    self = [super init];
    if (self) {
        maxTTL = TRACEROUTE_MAX_TTL;
        udpPort = TRACEROUTE_PORT;
        readTimeout = TRACEROUTE_TIMEOUT;
        maxAttempts = TRACEROUTE_ATTEMPTS;
    }

    return self;
}


/**
 * 监控tranceroute 路径
 */
- (HTTraceRouteResult *)doTraceRoute:(NSString *)host
{
    HTTraceRouteResult *result = [[HTTraceRouteResult alloc] init];
    result.records = [[NSMutableArray alloc] init];
    result.resultType = HTTRACEROUTE_RESULT_TYPE_SUCCESS;
    
    //从name server获取server主机的地址
    struct hostent *host_entry = gethostbyname(host.UTF8String);
    if (host_entry == NULL) {
        result.resultType = HTTRACEROUTE_RESULT_TYPE_ERROR_HOST;
        return result;
    }
    char *ip_addr;
    ip_addr = inet_ntoa(*((struct in_addr *)host_entry->h_addr_list[0]));
    
    NSString *ipString = [[NSString alloc] initWithCString:ip_addr encoding:NSUTF8StringEncoding];

    

    //初始化套接口
    struct sockaddr_in destination, fromAddr;
    int recv_sock;
    int send_sock;

    isrunning = true;
    //创建一个支持ICMP协议的UDP网络套接口（用于接收）
    if ((recv_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
        result.resultType = HTTRACEROUTE_RESULT_TYPE_ERROR_SOCKET;
        return result;
    }

    //创建一个UDP套接口（用于发送）
    //maoshu: udp目标主机不会反回port不可达信息，使用icmp的方式
    if ((send_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)) < 0) {
        result.resultType = HTTRACEROUTE_RESULT_TYPE_ERROR_SOCKET;
        return result;
    }

    //设置server主机的套接口地址
    memset(&destination, 0, sizeof(destination));
    destination.sin_family = AF_INET;
    destination.sin_addr.s_addr = inet_addr(ip_addr);
    destination.sin_port = htons(udpPort);

    socklen_t n = sizeof(fromAddr);
    char buf[100];
    
    ICMPHeader *icmpPtr;
    NSData *payload = [@"maoshuchen" dataUsingEncoding:NSASCIIStringEncoding];
    
    NSMutableData *packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + [payload length]];
    icmpPtr = [packet mutableBytes];
    icmpPtr->type = kICMPTypeEchoRequest;
    icmpPtr->code = 0;
    icmpPtr->checksum = 0;
    icmpPtr->identifier = OSSwapHostToBigInt16((uint16_t)arc4random());
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(0);
    memcpy(&icmpPtr[1], [payload bytes], [payload length]);
    
    icmpPtr->checksum = in_cksum([packet bytes], [packet length]);

    int ttl = 1;  // index sur le TTL en cours de traitement.
//    int timeoutTTL = 0;
    bool icmp = false;  // Positionné à true lorsqu'on reçoit la trame ICMP en retour.
    long startTime;     // Timestamp lors de l'émission du GET HTTP
    long delta;         // Durée de l'aller-retour jusqu'au hop.

    // On progresse jusqu'à un nombre de TTLs max.
    while (ttl <= maxTTL) {
        memset(&fromAddr, 0, sizeof(fromAddr));
        //设置sender 套接字的ttl
        if (setsockopt(send_sock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) < 0) {
            result.resultType = HTTRACEROUTE_RESULT_TYPE_ERROR_SET_TTL;
            return result;
        }


        //每一步连续发送maxAttenpts报文
        icmp = false;
        
        HTTraceRouteRecord *record = [[HTTraceRouteRecord alloc] init];
        record.ttl = ttl;
        long totalTime = 0;
        int trySuccessCount = 0;
        for (int try = 0; try < maxAttempts; try ++) {
            //中断
            @synchronized(running)
            {
                if (!isrunning) {
                    ttl = maxTTL;
                    // On force le statut d'icmp pour ne pas générer un Hop en sortie de boucle;
                    icmp = true;
                    break;
                }
            }
            
            startTime = [LDNetTimer getMicroSeconds];
            //发送成功返回值等于发送消息的长度
            if (sendto(send_sock, [packet bytes], [packet length], 0, (struct sockaddr *)&destination,
                       sizeof(destination)) != [packet length]) {
                NSLog(@"sendto length error.");
            }

            long res = 0;
            //从（已连接）套接口上接收数据，并捕获数据发送源的地址。
            if (-1 == fcntl(recv_sock, F_SETFL, O_NONBLOCK)) {
                result.resultType = HTTRACEROUTE_RESULT_TYPE_ERROR_FCNTL;
                return result;
            }
            /* set recvfrom from server timeout */
            struct timeval tv;
            fd_set readfds;
            tv.tv_sec = 1;
            tv.tv_usec = 0;  //设置了1s的延迟
            FD_ZERO(&readfds);
            FD_SET(recv_sock, &readfds);
            select(recv_sock + 1, &readfds, NULL, NULL, &tv);
            if (FD_ISSET(recv_sock, &readfds) > 0) {
//                timeoutTTL = 0;
                if ((res = recvfrom(recv_sock, buf, 100, 0, (struct sockaddr *)&fromAddr, &n)) <
                    0) {
                    NSLog(@"%s\t", strerror(errno));
                } else {
                    icmp = true;
                    delta = [LDNetTimer computeDurationSince:startTime];

                    //将“二进制整数” －> “点分十进制，获取hostAddress和hostName
                    char display[16] = {0};
                    inet_ntop(AF_INET, &fromAddr.sin_addr.s_addr, display, sizeof(display));
                    NSString *hostAddress = [NSString stringWithFormat:@"%s", display];
                    if (try == 0) {
                        record.ip = hostAddress;
                    }
                    totalTime += delta;
                    trySuccessCount++;
                }
            } else {
//                timeoutTTL++;
                break;
            }

        }
        
        if(trySuccessCount != 0){
            record.avgTime = totalTime / trySuccessCount / 1000.0;
        }
        [result.records addObject:record];
        
        if(self.delegate != nil){
            [self.delegate traceRecord:record];
        }
        
        //find destination
        if([ipString isEqualToString:record.ip]){
            break;
        }

//        //输出报文,如果三次都无法监控接收到报文，跳转结束
//        if (icmp) {
//            [self.delegate appendRouteLog:traceTTLLog];
//        } else {
//            //如果连续三次接收不到icmp回显报文
//            if (timeoutTTL >= 4) {
//                break;
//            } else {
//                [self.delegate appendRouteLog:[NSString stringWithFormat:@"%d\t********\t", ttl]];
//            }
//        }
        ttl++;
    }

    isrunning = false;

    return result;
}

/**
 * 停止traceroute
 */
- (void)stopTrace
{
    @synchronized(running)
    {
        isrunning = false;
    }
}


/**
 * 检测traceroute是否在运行
 */
- (bool)isRunning
{
    return isrunning;
}
@end
