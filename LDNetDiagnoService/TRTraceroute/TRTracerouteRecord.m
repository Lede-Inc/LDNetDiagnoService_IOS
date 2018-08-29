//
//  TRTracerouteRecord.m
//  TracerouteDemo
//
//  Created by LZephyr on 2018/2/8.
//  Copyright © 2018年 LZephyr. All rights reserved.
//

#import "TRTracerouteRecord.h"

@implementation TRTracerouteRecord

- (NSString *)description {
    NSMutableString *record = [[NSMutableString alloc] initWithCapacity:20];
    [record appendFormat:@"%-3ld ", (long)self.ttl];
    
    if (self.ip == nil) {
        [record appendFormat:@"%-15s |","***************"];
    } else {
        [record appendFormat:@"%-15s |", [self.ip UTF8String]];
    }
    
    for (id number in _recvDurations) {
        if ([number isKindOfClass:[NSNull class]]) {
            [record appendFormat:@"     *     |"];
        } else {
            [record appendFormat:@" %6.2f ms |", [(NSNumber *)number floatValue] * 1000];
        }
    }
    
    return record;
}

@end
