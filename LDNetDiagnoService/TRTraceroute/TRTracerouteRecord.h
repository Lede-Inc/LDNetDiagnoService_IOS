//
//  TRTracerouteRecord.h
//  TracerouteDemo
//
//  Created by LZephyr on 2018/2/8.
//  Copyright © 2018年 LZephyr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TRTracerouteRecord : NSObject

@property (nonatomic) NSString *ip; // 当前这一跳的IP
@property (nonatomic) NSString *hostName;// 查找位置信息
@property (nonatomic) NSArray<NSNumber *> *recvDurations; // 每次的往返耗时
@property (nonatomic) NSInteger total; // 次数
@property (nonatomic) NSInteger ttl; // 当前的TTL

@end
