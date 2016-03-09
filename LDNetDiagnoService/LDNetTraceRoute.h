//
//  TraceRoute.h
//  LDNetCheckServiceDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#import <Foundation/Foundation.h>

static const int TRACEROUTE_PORT = 31234;
static const int TRACEROUTE_MAX_TTL = 32;
static const int TRACEROUTE_ATTEMPTS = 3;
static const int TRACEROUTE_TIMEOUT = 5000000;

typedef enum {
    HTTRACEROUTE_RESULT_TYPE_SUCCESS,
    HTTRACEROUTE_RESULT_TYPE_ERROR_HOST,
    HTTRACEROUTE_RESULT_TYPE_ERROR_SOCKET,
    HTTRACEROUTE_RESULT_TYPE_ERROR_SET_TTL,
    HTTRACEROUTE_RESULT_TYPE_ERROR_FCNTL,
} HTTRACEROUTE_RESULT_TYPE;

@interface HTTraceRouteRecord : NSObject

@property (nonatomic, assign, readwrite) int ttl;
@property (nonatomic, assign, readwrite) float avgTime;
@property (nonatomic, copy, readwrite) NSString *ip;

@end

/*
 * @protocal LDNetTraceRouteDelegate监测TraceRoute命令的的输出到日志变量；
 *
 */
@protocol LDNetTraceRouteDelegate <NSObject>
- (void)traceRecord:(HTTraceRouteRecord *)record;
@end

@interface HTTraceRouteResult : NSObject

@property (nonatomic, assign, readwrite) HTTRACEROUTE_RESULT_TYPE resultType;
@property (nonatomic, strong, readwrite) NSMutableArray *records;

@end

/*
 * @class LDNetTraceRoute TraceRoute网络监控
 * 主要是通过模拟shell命令traceRoute的过程，监控网络站点间的跳转
 * 默认执行20转，每转进行三次发送测速
 */
@interface LDNetTraceRoute : NSObject {
    int udpPort;      //执行端口
    int maxTTL;       //执行转数
    int readTimeout;  //每次发送时间的timeout
    int maxAttempts;  //每转的发送次数
    NSString *running;
    bool isrunning;
}

@property (nonatomic, weak) id<LDNetTraceRouteDelegate> delegate;

/**
 * 监控tranceroute 路径
 */
- (HTTraceRouteResult *)doTraceRoute:(NSString *)host;

/**
 * 停止traceroute
 */
- (void)stopTrace;
- (bool)isRunning;

@end
