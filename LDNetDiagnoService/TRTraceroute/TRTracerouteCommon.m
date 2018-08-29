//
//  TRTracerouteCommon.m
//  TracerouteDemo
//
//  Created by LZephyr on 2018/2/7.
//  Copyright © 2018年 LZephyr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssertMacros.h>
#import "TRTracerouteCommon.h"

// IPv4数据报结构
typedef struct IPv4Header {
    uint8_t versionAndHeaderLength; // 版本和首部长度
    uint8_t serviceType; // 服务类型
    uint16_t totalLength; // 数据包长度
    uint16_t identifier;
    uint16_t flagsAndFragmentOffset;
    uint8_t timeToLive;
    uint8_t protocol; // 协议类型，1表示ICMP: https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
    uint16_t checksum;
    uint8_t sourceAddress[4];
    uint8_t destAddress[4];
    // options...
    // data...
} IPv4Header;

// IPv6数据包结构
typedef struct IPv6Header {
    uint32_t padding; // 版本 + 通信量等级 + 流标签
    uint16_t payloadLength; // 有效载荷大小
    uint8_t nextHeader; // 表示类型，58为ICMPv6
    uint8_t hopLimit; // 跳限制
    uint8_t sourceAddress[16]; // 128位源地址
    uint8_t destAddress[16]; //128目标地址
    // data
} IPv6Header;

// IPv4Header编译期检查
__Check_Compile_Time(sizeof(IPv4Header) == 20);
__Check_Compile_Time(offsetof(IPv4Header, versionAndHeaderLength) == 0);
__Check_Compile_Time(offsetof(IPv4Header, serviceType) == 1);
__Check_Compile_Time(offsetof(IPv4Header, totalLength) == 2);
__Check_Compile_Time(offsetof(IPv4Header, identifier) == 4);
__Check_Compile_Time(offsetof(IPv4Header, flagsAndFragmentOffset) == 6);
__Check_Compile_Time(offsetof(IPv4Header, timeToLive) == 8);
__Check_Compile_Time(offsetof(IPv4Header, protocol) == 9);
__Check_Compile_Time(offsetof(IPv4Header, checksum) == 10);
__Check_Compile_Time(offsetof(IPv4Header, sourceAddress) == 12);
__Check_Compile_Time(offsetof(IPv4Header, destAddress) == 16);
__Check_Compile_Time(sizeof(TRICMPPacket) == 8);
__Check_Compile_Time(offsetof(TRICMPPacket, type) == 0);
__Check_Compile_Time(offsetof(TRICMPPacket, code) == 1);
__Check_Compile_Time(offsetof(TRICMPPacket, checksum) == 2);
__Check_Compile_Time(offsetof(TRICMPPacket, identifier) == 4);
__Check_Compile_Time(offsetof(TRICMPPacket, sequenceNumber) == 6);

// IPv6Header编译期检查
__Check_Compile_Time(offsetof(IPv6Header, padding) == 0);
__Check_Compile_Time(offsetof(IPv6Header, payloadLength) == 4);
__Check_Compile_Time(offsetof(IPv6Header, nextHeader) == 6);
__Check_Compile_Time(offsetof(IPv6Header, hopLimit) == 7);
__Check_Compile_Time(offsetof(IPv6Header, sourceAddress) == 8);
__Check_Compile_Time(offsetof(IPv6Header, destAddress) == 24);

@implementation TRTracerouteCommon

#pragma mark - Public

// 来源于官方示例：https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html
+ (uint16_t)makeChecksumFor:(const void *)buffer len:(size_t)bufferLen {
    size_t bytesLeft;
    int32_t sum;
    const uint16_t *cursor;
    union {
        uint16_t us;
        uint8_t uc[2];
    } last;
    uint16_t answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = *(const uint8_t *)cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff); /* add hi 16 to low 16 */
    sum += (sum >> 16); /* add carry */
    answer = (uint16_t)~sum; /* truncate to 16 bits */
    
    return answer;
}

+ (struct sockaddr *)makeSockaddrWithAddress:(NSString *)address port:(int)port isIPv6:(BOOL)isIPv6 {
    NSData *addrData = nil;
    if (isIPv6) {
        struct sockaddr_in6 addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin6_family = AF_INET6;
        addr.sin6_len = sizeof(addr);
        addr.sin6_port = htons(port);
        if (inet_pton(AF_INET6, address.UTF8String, &addr.sin6_addr) < 0) {
            NSLog(@"创建sockaddr结构体失败");
            return NULL;
        }
        addrData = [NSData dataWithBytes:&addr length:sizeof(addr)];
    } else {
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        if (inet_pton(AF_INET, address.UTF8String, &addr.sin_addr.s_addr) < 0) {
            NSLog(@"创建sockaddr结构体失败");
            return NULL;
        }
        addrData = [NSData dataWithBytes:&addr length:sizeof(addr)];
    }
    return (struct sockaddr *)[addrData bytes];
}

+ (NSData *)makeICMPPacketWithID:(uint16_t)identifier
                        sequence:(uint16_t)seq
                        isICMPv6:(BOOL)isICMPv6 {
    NSMutableData *packet;
    TRICMPPacket *icmpPtr;
    
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr)];
    
    icmpPtr = packet.mutableBytes;
    icmpPtr->type = isICMPv6 ? kTRICMPv6TypeEchoRequest : kTRICMPv4TypeEchoRequest;
    icmpPtr->code = 0;
    
    if (isICMPv6) {
        icmpPtr->identifier     = 0;
        icmpPtr->sequenceNumber = 0;
    } else {
        icmpPtr->identifier     = OSSwapHostToBigInt16(identifier);
        icmpPtr->sequenceNumber = OSSwapHostToBigInt16(seq);
    }
    
    // ICMPv6的校验和由内核计算
    if (!isICMPv6) {
        icmpPtr->checksum = 0;
        icmpPtr->checksum = [TRTracerouteCommon makeChecksumFor:packet.bytes len:packet.length];
    }
    
    return packet;
}

+ (NSArray<NSString *> *)resolveHost:(NSString *)hostname {
    NSMutableArray<NSString *> *resolve = [NSMutableArray array];
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);
    if (hostRef != NULL) {
        Boolean result = CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL); // 开始DNS解析
        if (result == true) {
            CFArrayRef addresses = CFHostGetAddressing(hostRef, &result);
            for(int i = 0; i < CFArrayGetCount(addresses); i++){
                CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addresses, i);
                struct sockaddr *addressGeneric = (struct sockaddr *)CFDataGetBytePtr(saData);
                
                if (addressGeneric != NULL) {
                    if (addressGeneric->sa_family == AF_INET) {
                        struct sockaddr_in *remoteAddr = (struct sockaddr_in *)CFDataGetBytePtr(saData);
                        [resolve addObject:[self formatIPv4Address:remoteAddr->sin_addr]];
                    } else if (addressGeneric->sa_family == AF_INET6) {
                        struct sockaddr_in6 *remoteAddr = (struct sockaddr_in6 *)CFDataGetBytePtr(saData);
                        [resolve addObject:[self formatIPv6Address:remoteAddr->sin6_addr]];
                    }
                }
            }
        }
    }
    
    return [resolve copy];
}

+ (BOOL)isEchoReplyPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6 {
    TRICMPPacket *icmpPacket = NULL;
    
    if (isIPv6) {
        icmpPacket = [TRTracerouteCommon unpackICMPv6Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kTRICMPv6TypeEchoReply) {
            return YES;
        }
    } else {
        icmpPacket = [TRTracerouteCommon unpackICMPv4Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kTRICMPv4TypeEchoReply) {
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)isTimeoutPacket:(char *)packet len:(int)len isIPv6:(BOOL)isIPv6 {
    TRICMPPacket *icmpPacket = NULL;
    
    if (isIPv6) {
        icmpPacket = [TRTracerouteCommon unpackICMPv6Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kTRICMPv6TypeTimeOut) {
            return YES;
        }
    } else {
        icmpPacket = [TRTracerouteCommon unpackICMPv4Packet:packet len:len];
        if (icmpPacket != NULL && icmpPacket->type == kTRICMPv4TypeTimeOut) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Helper

// 从IPv4数据包中解析出ICMP
+ (TRICMPPacket *)unpackICMPv4Packet:(char *)packet len:(int)len {
    if (len < (sizeof(IPv4Header) + sizeof(TRICMPPacket))) {
        return NULL;
    }
    const struct IPv4Header *ipPtr = (const IPv4Header *)packet;
    if ((ipPtr->versionAndHeaderLength & 0xF0) != 0x40 || // IPv4
        ipPtr->protocol != 1) { //ICMP
        return NULL;
    }
    
    size_t ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t); // IPv4头部长度
    if (len < ipHeaderLength + sizeof(TRICMPPacket)) {
        return NULL;
    }
    
    return (TRICMPPacket *)((char *)packet + ipHeaderLength);
}

// 从IPv6数据包中解析出ICMP
// https://tools.ietf.org/html/rfc2463
+ (TRICMPPacket *)unpackICMPv6Packet:(char *)packet len:(int)len {
//    if (len < (sizeof(IPv6Header) + sizeof(TRICMPPacket))) {
//        return NULL;
//    }
//    const struct IPv6Header *ipPtr = (const IPv6Header *)packet;
//    if (ipPtr->nextHeader != 58) { // ICMPv6
//        return NULL;
//    }
//
//    size_t ipHeaderLength = sizeof(uint8_t) * 40; // IPv6头部长度为固定的40字节
//    if (len < ipHeaderLength + sizeof(TRICMPPacket)) {
//        return NULL;
//    }
//
//    return (TRICMPPacket *)((char *)packet + ipHeaderLength);
    return (TRICMPPacket *)packet;
}

+ (NSString *)formatIPv6Address:(struct in6_addr)ipv6Addr {
    NSString *address = nil;
    
    char dstStr[INET6_ADDRSTRLEN];
    char srcStr[INET6_ADDRSTRLEN];
    memcpy(srcStr, &ipv6Addr, sizeof(struct in6_addr));
    if(inet_ntop(AF_INET6, srcStr, dstStr, INET6_ADDRSTRLEN) != NULL){
        address = [NSString stringWithUTF8String:dstStr];
    }
    
    return address;
}

+ (NSString *)formatIPv4Address:(struct in_addr)ipv4Addr {
    NSString *address = nil;
    
    char dstStr[INET_ADDRSTRLEN];
    char srcStr[INET_ADDRSTRLEN];
    memcpy(srcStr, &ipv4Addr, sizeof(struct in_addr));
    if(inet_ntop(AF_INET, srcStr, dstStr, INET_ADDRSTRLEN) != NULL) {
        address = [NSString stringWithUTF8String:dstStr];
    }
    
    return address;
}

@end
