//
//  LDNetPing.h
//  LDNetCheckServiceDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDSimplePing.h"


/*
 * @protocal LDNetPingDelegate监测Ping命令的的输出到日志变量；
 *
 */
@protocol LDNetPingDelegate <NSObject>
//- (void)appendPingLog:(NSString *)pingLog;
- (void)netPingDidEnd;
@end


/*
 * @class LDNetPing ping监控
 * 主要是通过模拟shell命令ping的过程，监控目标主机是否连通
 * 连续执行五次，因为每次的速度不一致，可以观察其平均速度来判断网络情况
 */
@protocol LDSimplePingDelegate;

@interface HTPingResult : NSObject
@property (nonatomic, copy, readwrite) NSString *ip;
@property (nonatomic, assign, readwrite) int sendCount;
@property (nonatomic, assign, readwrite) int receiveCount;
@property (nonatomic, assign, readwrite) int ttl;
/**
 * max is 1.0
 */
@property (nonatomic, assign, readwrite) float lossRate;
/**
 * rtt is ms
 */
@property (nonatomic, assign, readwrite) float rttMin;
@property (nonatomic, assign, readwrite) float rttAvg;
@property (nonatomic, assign, readwrite) float rttMax;
@property (nonatomic, assign, readwrite) float rttMDev;

@property (nonatomic, copy, readwrite) NSMutableArray *pingInfos;
@end

@interface HTPingInfo : NSObject
@property (nonatomic, assign, readwrite) BOOL isSuccess;
@property (nonatomic, copy, readwrite) NSString *errorText;
@property (nonatomic, copy, readwrite) NSString *ip;
@property (nonatomic, assign, readwrite) unsigned int ttl;
@property (nonatomic, assign, readwrite) long time;
@end

@interface LDNetPing : NSObject <LDSimplePingDelegate> 

@property (nonatomic, weak, readwrite) id<LDNetPingDelegate> delegate;

/**
 * 通过hostname 进行ping诊断
 */
- (void)runWithHostName:(NSString *)hostName normalPing:(BOOL)normalPing;

/**
 * 停止当前ping动作
 */
- (void)stopPing;

- (HTPingResult*)getPingResult;

@end


