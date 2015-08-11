//
//  LDNetGetAddress.m
//  LDNetDiagnoServiceDemo
//
//  Created by ZhangHaiyang on 15-8-5.
//  Copyright (c) 2015年 庞辉. All rights reserved.
//

#import "LDNetGetAddress.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>

#include <resolv.h>
#include <dns.h>

#import <sys/sysctl.h>
#import <netinet/in.h>

#if TARGET_IPHONE_SIMULATOR
#include <net/route.h>
#else
#include "Route.h"
#endif /*the very same from google-code*/

#define ROUNDUP(a) ((a) > 0 ? (1 + (((a)-1) | (sizeof(long) - 1))) : sizeof(long))

@implementation LDNetGetAddress


/*!
 * 获取当前设备ip地址
 */
+ (NSString *)deviceIPAdress
{
    NSString *address = @"";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;

    success = getifaddrs(&interfaces);

    if (success == 0) {  // 0 表示获取成功

        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] ||
                    [[NSString stringWithUTF8String:temp_addr->ifa_name]
                        isEqualToString:@"pdp_ip0"]) {
                    // Get NSString from C String
                    address = [NSString
                        stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)
                                                           ->sin_addr)];
                }
            }

            temp_addr = temp_addr->ifa_next;
        }
    }

    freeifaddrs(interfaces);

    if (address && ![address isEqualToString:@""]) {
        return address;
    } else {
        return @"127.0.0.1";
    }
}

/*!
 * 获取当前设备网关地址
 */
+ (NSString *)getGatewayIPAddress
{

    NSString *address = nil;

    /* net.route.0.inet.flags.gateway */
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char *buf, *p;
    struct rt_msghdr *rt;
    struct sockaddr *sa;
    struct sockaddr *sa_tab[RTAX_MAX];
    int i;
    int r = -1;

    if (sysctl(mib, sizeof(mib) / sizeof(int), 0, &l, 0, 0) < 0) {
        address = @"192.168.0.1";
    }

    if (l > 0) {
        buf = malloc(l);
        if (sysctl(mib, sizeof(mib) / sizeof(int), buf, &l, 0, 0) < 0) {
            address = @"192.168.0.1";
        }

        for (p = buf; p < buf + l; p += rt->rtm_msglen) {
            rt = (struct rt_msghdr *)p;
            sa = (struct sockaddr *)(rt + 1);
            for (i = 0; i < RTAX_MAX; i++) {
                if (rt->rtm_addrs & (1 << i)) {
                    sa_tab[i] = sa;
                    sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
                } else {
                    sa_tab[i] = NULL;
                }
            }

            if (((rt->rtm_addrs & (RTA_DST | RTA_GATEWAY)) == (RTA_DST | RTA_GATEWAY)) &&
                sa_tab[RTAX_DST]->sa_family == AF_INET &&
                sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {
                unsigned char octet[4] = {0, 0, 0, 0};
                int i;
                for (i = 0; i < 4; i++) {
                    octet[i] = (((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr.s_addr >>
                                (i * 8)) &
                               0xFF;
                }
                if (((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                    in_addr_t addr =
                        ((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr.s_addr;
                    r = 0;
                    address =
                        [NSString stringWithFormat:@"%s", inet_ntoa(*((struct in_addr *)&addr))];
                    NSLog(@"address%@", address);
                    break;
                }
            }
        }
        free(buf);
    }
    return address;
}


/*!
 * 通过hostname获取ip列表
 */
+ (NSArray *)getIPWithHostName:(NSString *)hostName
{
    const char *hostN = [hostName UTF8String];
    struct hostent *phot;

    @try {
        phot = gethostbyname(hostN);

    } @catch (NSException *exception) {
        return nil;
    }

    NSMutableArray *result = [[NSMutableArray alloc] init];
    int j = 0;
    while (phot && phot->h_addr_list && phot->h_addr_list[j]) {
        struct in_addr ip_addr;
        memcpy(&ip_addr, phot->h_addr_list[j], 4);
        char ip[20] = {0};
        inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));

        NSString *strIPAddress = [NSString stringWithUTF8String:ip];
        [result addObject:strIPAddress];
        j++;
    }

    return [NSArray arrayWithArray:result];
}

/*!
 * 获取当前网络DNS服务器地址
 */
+ (NSArray *)outPutDNSServers
{
    res_state res = malloc(sizeof(struct __res_state));

    int result = res_ninit(res);
    NSMutableArray *servers = [[NSMutableArray alloc] init];
    if (result == 0) {
        for (int i = 0; i < res->nscount; i++) {
            NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [servers addObject:s];
            NSLog(@"server : %@", s);
        }
    }

    res_nclose(res);
    free(res);

    return [NSArray arrayWithArray:servers];
}

/*!
 * 获取当前网络类型
 * 通过statusBar的网络subview获取具体类型
 */
+ (NETWORK_TYPE)getNetworkTypeFromStatusBar
{
    NSArray *subviews = [[[[UIApplication sharedApplication] valueForKey:@"statusBar"]
        valueForKey:@"foregroundView"] subviews];
    NSNumber *dataNetworkItemView = nil;
    for (id subview in subviews) {
        if ([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
            dataNetworkItemView = subview;
            break;
        }
    }
    NETWORK_TYPE nettype = NETWORK_TYPE_NONE;
    NSNumber *num = [dataNetworkItemView valueForKey:@"dataNetworkType"];
    nettype = [num intValue];
    return nettype;
}

@end
