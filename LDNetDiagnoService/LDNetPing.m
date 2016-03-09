//
//  LDNetPing.m
//  LDNetCheckServiceDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//
#include <sys/socket.h>
#include <netdb.h>

#import "LDNetPing.h"
#import "LDNetTimer.h"

#define MAXCOUNT_PING 10

@interface LDNetPing () {
    BOOL _isStartSuccess; //监测第一次ping是否成功
    int _sendCount;  //当前执行次数
    long _startTime; //每次执行的开始时间
    NSString *_hostAddress; //目标域名的IP地址
    BOOL _isLargePing;
    NSTimer *timer;
    NSMutableArray *pingInfoArray;
}

@property (nonatomic, strong, readwrite) LDSimplePing *pinger;

@end


@implementation LDNetPing
@synthesize pinger = _pinger;


- (void)dealloc
{
    [self->_pinger stop];
}

-(HTPingResult*)getPingResult
{
    HTPingResult *pingResult = [[HTPingResult alloc] init];
    HTPingInfo *successPingInfo = nil;
    int successCount = 0;
    long rttMin = LONG_MAX;
    long rttMax = 0;
    long rttTotal = 0;
    for(int i = 0; i < pingInfoArray.count; i++){
        HTPingInfo *item = [pingInfoArray objectAtIndex:i];
        if(item != nil){
            if(item.isSuccess && successPingInfo == nil){
                successPingInfo = item;
            }
            if(item.isSuccess){
                successCount++;
                
                if(item.time > rttMax){
                    rttMax = item.time;
                }
                if(item.time < rttMin){
                    rttMin = item.time;
                }
                rttTotal += item.time;
            }
        }
    }
    if(successPingInfo != nil){
        pingResult.ip = successPingInfo.ip;
        pingResult.ttl = successPingInfo.ttl;
    }
    pingResult.sendCount = (int)pingInfoArray.count;
    pingResult.receiveCount = successCount;
    pingResult.lossRate = (float)(pingResult.sendCount - pingResult.receiveCount) / pingResult.sendCount;
    
    pingResult.rttMin = rttMin / 1000.0;
    pingResult.rttMax = rttMax / 1000.0;
    
    long rttAvg = rttTotal / successCount;
    
    pingResult.rttAvg = rttAvg / 1000.0;
    
    float totalDiff = 0;
    for(int i = 0; i < pingInfoArray.count; i++){
        HTPingInfo *item = [pingInfoArray objectAtIndex:i];
        if(item != nil && item.isSuccess){
            totalDiff += ABS(item.time - rttAvg);
        }
    }
    pingResult.rttMDev = totalDiff / successCount / 1000.0;
    pingResult.pingInfos = pingInfoArray;
    
    return pingResult;
}


/**
 * 停止当前ping动作
 */
- (void)stopPing
{
    [self->_pinger stop];
    self.pinger = nil;
    _sendCount = MAXCOUNT_PING + 1;
}


/*
 * 调用pinger解析指定域名
 * @param hostName 指定域名
 */
- (void)runWithHostName:(NSString *)hostName normalPing:(BOOL)normalPing{
    
    if(pingInfoArray == nil){
        pingInfoArray = [[NSMutableArray alloc] init];
    }
    [pingInfoArray removeAllObjects];
    
    assert(self.pinger == nil);
    self.pinger = [LDSimplePing simplePingWithHostName:hostName];
    assert(self.pinger != nil);
    
    _isLargePing = !normalPing;
    self.pinger.delegate = self;
    [self.pinger start];

    //在当前线程一直执行
    _sendCount = 1;
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.pinger != nil || _sendCount <= MAXCOUNT_PING);
}


/*
 * 发送Ping数据，pinger会组装一个ICMP控制报文的数据发送过去
 *
 */
- (void)sendPing
{
    if (timer) {
        [timer invalidate];
    }
    if (_sendCount > MAXCOUNT_PING) {
        _sendCount++;
        self.pinger = nil;
        if (self.delegate && [self.delegate respondsToSelector:@selector(netPingDidEnd)]) {
            [self.delegate netPingDidEnd];
        }
    }

    else {
        assert(self.pinger != nil);
        _sendCount++;
        _startTime = [LDNetTimer getMicroSeconds];
        if (_isLargePing) {
            NSString *testStr = @"";
            for (int i=0; i<408; i++) {
                testStr = [testStr stringByAppendingString:@"abcdefghi "];
            }
            testStr = [testStr stringByAppendingString:@"abcdefgh"];
            NSData *data = [testStr dataUsingEncoding:NSASCIIStringEncoding];
            [self.pinger sendPingWithData:data];
        } else {
            [self.pinger sendPingWithData:nil];
        }
        timer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                 target:self
                                               selector:@selector(pingTimeout:)
                                               userInfo:[NSNumber numberWithInt:_sendCount]
                                                repeats:NO];
    }
}

- (void)pingTimeout:(NSTimer *)index
{
    if ([[index userInfo] intValue] == _sendCount && _sendCount <= MAXCOUNT_PING + 1 &&
        _sendCount > 1) {
        NSString *timeoutLog =
            [NSString stringWithFormat:@"ping: cannot resolve %@: TimeOut", _hostAddress];
        
        HTPingInfo *ipInfo = [[HTPingInfo alloc] init];
        ipInfo.isSuccess = NO;
        ipInfo.errorText = timeoutLog;
        ipInfo.ip = _hostAddress;
        [pingInfoArray addObject:ipInfo];
        
        
        [self sendPing];
    }
}


#pragma mark - Pingdelegate
/*
 * PingDelegate: 套接口开启之后发送ping数据，并开启一个timer（1s间隔发送数据）
 *
 */
- (void)simplePing:(LDSimplePing *)pinger didStartWithAddress:(NSData *)address
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
    assert(address != nil);
    _hostAddress = DisplayAddressForAddress(address);
    NSLog(@"pinging %@", _hostAddress);

    // Send the first ping straight away.
    _isStartSuccess = YES;
    [self sendPing];
}

/*
 * PingDelegate: ping命令发生错误之后，立即停止timer和线程
 *
 */
- (void)simplePing:(LDSimplePing *)pinger didFailWithError:(NSError *)error
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(error)
    
    NSLog(@"#%u try create failed: %@", _sendCount,
          [self shortErrorFromError:error]);


    //如果不是创建套接字失败，都是发送数据过程中的错误,可以继续try发送数据
    if (_isStartSuccess) {
        [self sendPing];
    } else {
        [self stopPing];
    }
}

/*
 * PingDelegate: 发送ping数据成功
 *
 */
- (void)simplePing:(LDSimplePing *)pinger didSendPacket:(NSData *)packet
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    NSLog(@"#%u sent success",
          (unsigned int)OSSwapBigToHostInt16(((const ICMPHeader *)[packet bytes])->sequenceNumber));
}


/*
 * PingDelegate: 发送ping数据失败
 *
 */
- (void)simplePing:(LDSimplePing *)pinger
    didFailToSendPacket:(NSData *)packet
                  error:(NSError *)error
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
#pragma unused(error)
    NSString *sendFailLog =
        [NSString stringWithFormat:@"#%u send failed: %@",
                                   (unsigned int)OSSwapBigToHostInt16(
                                       ((const ICMPHeader *)[packet bytes])->sequenceNumber),
                                   [self shortErrorFromError:error]];
    HTPingInfo *ipInfo = [[HTPingInfo alloc] init];
    ipInfo.isSuccess = NO;
    ipInfo.errorText = sendFailLog;
    ipInfo.ip = _hostAddress;
    [pingInfoArray addObject:ipInfo];

    [self sendPing];
}


/*
 * PingDelegate: 成功接收到PingResponse数据
 *
 */
- (void)simplePing:(LDSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet
{
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    
    //add pinginfo to array
    HTPingInfo *ipInfo = [[HTPingInfo alloc] init];
    ipInfo.isSuccess = YES;
    ipInfo.ip = _hostAddress;
    ipInfo.ttl = (unsigned int)([LDSimplePing ipHeaderInPacket:packet]->timeToLive);
    ipInfo.time = [LDNetTimer computeDurationSince:_startTime];
    [pingInfoArray addObject:ipInfo];

//    NSString *successLog = [NSString
//        stringWithFormat:@"%lu bytes from %@ icmp_seq=#%u ttl=%d time=%ldms",
//                         (unsigned long)[packet length], _hostAddress,
//                         (unsigned int)OSSwapBigToHostInt16(
//                             [LDSimplePing icmpInPacket:packet]->sequenceNumber),
//                         (unsigned int)([LDSimplePing ipHeaderInPacket:packet]->timeToLive),
//                         [LDNetTimer computeDurationSince:_startTime] / 1000];
//    //记录ping成功的数据
//    if (self.delegate && [self.delegate respondsToSelector:@selector(appendPingLog:)]) {
//        [self.delegate appendPingLog:successLog];
//    }

    [self sendPing];
}


/*
 * PingDelegate: 接收到错误的pingResponse数据
 *
 */
- (void)simplePing:(LDSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet
{
    const ICMPHeader *icmpPtr;
    if (self.pinger && pinger == self.pinger) {
        icmpPtr = [LDSimplePing icmpInPacket:packet];
        NSString *errorLog = @"";
        if (icmpPtr != NULL) {
            errorLog = [NSString
                stringWithFormat:@"#%u unexpected ICMP type=%u, code=%u, identifier=%u",
                                 (unsigned int)OSSwapBigToHostInt16(icmpPtr->sequenceNumber),
                                 (unsigned int)icmpPtr->type, (unsigned int)icmpPtr->code,
                                 (unsigned int)OSSwapBigToHostInt16(icmpPtr->identifier)];
        } else {
            errorLog = [NSString stringWithFormat:@"#%u try unexpected packet size=%zu", _sendCount,
                                                  (size_t)[packet length]];
        }
        
        HTPingInfo *ipInfo = [[HTPingInfo alloc] init];
        ipInfo.isSuccess = NO;
        ipInfo.errorText = errorLog;
        ipInfo.ip = _hostAddress;
        [pingInfoArray addObject:ipInfo];
    }

    //当检测到错误数据的时候，再次发送
    [self sendPing];
}


/**
 * 将ping接收的数据转换成ip地址
 * @param address 接受的ping数据
 */
NSString *DisplayAddressForAddress(NSData *address)
{
    int err;
    NSString *result;
    char hostStr[NI_MAXHOST];

    result = nil;

    if (address != nil) {
        err = getnameinfo([address bytes], (socklen_t)[address length], hostStr, sizeof(hostStr),
                          NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = [NSString stringWithCString:hostStr encoding:NSASCIIStringEncoding];
            assert(result != nil);
        }
    }

    return result;
}

/*
 * 解析错误数据并翻译
 */
- (NSString *)shortErrorFromError:(NSError *)error
{
    NSString *result;
    NSNumber *failureNum;
    int failure;
    const char *failureStr;

    assert(error != nil);

    result = nil;

    // Handle DNS errors as a special case.

    if ([[error domain] isEqual:(NSString *)kCFErrorDomainCFNetwork] &&
        ([error code] == kCFHostErrorUnknown)) {
        failureNum = [[error userInfo] objectForKey:(id)kCFGetAddrInfoFailureKey];
        if ([failureNum isKindOfClass:[NSNumber class]]) {
            failure = [failureNum intValue];
            if (failure != 0) {
                failureStr = gai_strerror(failure);
                if (failureStr != NULL) {
                    result = [NSString stringWithUTF8String:failureStr];
                    assert(result != nil);
                }
            }
        }
    }

    // Otherwise try various properties of the error object.

    if (result == nil) {
        result = [error localizedFailureReason];
    }
    if (result == nil) {
        result = [error localizedDescription];
    }
    if (result == nil) {
        result = [error description];
    }
    assert(result != nil);
    return result;
}

@end

@implementation HTPingResult

@end

@implementation HTPingInfo


@end
