//
//  TRTraceroute.h
//  TracerouteDemo
//
//  Created by LZephyr on 2018/2/8.
//  Copyright © 2018年 LZephyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TRTracerouteRecord.h"

/**
 TRTraceroute中每一跳的结果回调

 @param record 记录结果的对象
 */
typedef void (^TRTracerouteStepCallback)(TRTracerouteRecord *record);

/**
 TRTraceroute结束的回调

 @param results 所有的结果
 @param succeed 是否成功
 */
typedef void (^TRTracerouteFinishCallback)(NSArray<TRTracerouteRecord *> *results, BOOL succeed);

@interface TRTraceroute : NSObject

/**
 开始对指定的IP进行traceroute诊断，在当前线程同步执行
 
 @param host         诊断的域名或IP地址
 @param stepCallback 每一跳的结果回调
 @param finish       TRTraceroute结束的回调
 */
+ (instancetype)startTracerouteWithHost:(NSString *)host
                           stepCallback:(TRTracerouteStepCallback)stepCallback
                                 finish:(TRTracerouteFinishCallback)finish;

/**
 开始对指定的IP进行traceroute诊断，在指定的线程中进行

 @param host         诊断的域名或IP地址
 @param queue        诊断及回调所在的线程
 @param stepCallback 每一跳的结果回调
 @param finish       TRTraceroute结束的回调
 */
+ (instancetype)startTracerouteWithHost:(NSString *)host
                                  queue:(dispatch_queue_t)queue
                           stepCallback:(TRTracerouteStepCallback)stepCallback
                                 finish:(TRTracerouteFinishCallback)finish;

- (void)stopTrace;

@end
