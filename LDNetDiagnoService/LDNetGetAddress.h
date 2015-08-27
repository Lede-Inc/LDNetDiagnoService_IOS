//
//  LDNetGetAddress.h
//  LDNetDiagnoServiceDemo
//
//  Created by ZhangHaiyang on 15-8-5.
//  Copyright (c) 2015年 庞辉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LDNetGetAddress : NSObject

//网络类型
typedef enum {
    NETWORK_TYPE_NONE = 0,
    NETWORK_TYPE_2G = 1,
    NETWORK_TYPE_3G = 2,
    NETWORK_TYPE_4G = 3,
    NETWORK_TYPE_5G = 4,  //  5G目前为猜测结果
    NETWORK_TYPE_WIFI = 5,
} NETWORK_TYPE;

/*!
 * 获取当前设备ip地址
 */
+ (NSString *)deviceIPAdress;


/*!
 * 获取当前设备网关地址
 */
+ (NSString *)getGatewayIPAddress;


/*!
 * 通过hostname获取ip列表
 */
+ (NSArray *)getIPWithHostName:(NSString *)hostName;


/*!
 * 获取当前网络DNS服务器地址
 */
+ (NSArray *)outPutDNSServers;


/*!
 * 获取当前网络类型
 */
+ (NETWORK_TYPE)getNetworkTypeFromStatusBar;

@end
