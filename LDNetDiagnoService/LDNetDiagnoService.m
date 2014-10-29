//
//  LDNetDiagnoService.m
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "LDNetDiagnoService.h"
#import "LDNetPing.h"
#import "LDNetTraceRoute.h"

@interface LDNetDiagnoService ()<LDNetPingDelegate, LDNetTraceRouteDelegate> {
    NSMutableString *_logInfo; //记录网络诊断log日志
    
    BOOL _isRunning;
    LDNetPing *_netPinger;
    LDNetTraceRoute *_traceRouter;
}

@end

@implementation LDNetDiagnoService
@synthesize appCode = _appCode;
@synthesize UID = _UID;
@synthesize dormain = _dormain;

#pragma mark - public method
/**
 * 初始化网络诊断服务
 */
-(id) initWithAppCode:(NSString *)theAppCode
               userID:(NSString *)theUID
              dormain:(NSString *)theDormain {
    self = [super init];
    if(self){
        _appCode = theAppCode;
        _UID = theUID;
        _dormain = theDormain;
        
        _logInfo = [[NSMutableString alloc] initWithCapacity:20];
        _isRunning = NO;
    }
    
    return self;
}

-(void) recordCurrentAppVersion {
    //输出应用版本信息和用户ID
    [self recordStepInfo: [NSString stringWithFormat:@"应用code:\t%@", _appCode]];
    NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];
    [self recordStepInfo: [NSString stringWithFormat:@"应用名称:\t%@", [dicBundle objectForKey:@"CFBundleDisplayName"]]];
    [self recordStepInfo: [NSString stringWithFormat:@"应用版本:\t%@", [dicBundle objectForKey:@"CFBundleShortVersionString"]]];
    [self recordStepInfo:[NSString stringWithFormat:@"用户id:\t%@", _UID]];
    
    //输出机器信息
    UIDevice* device = [UIDevice currentDevice];
    [self recordStepInfo:[NSString stringWithFormat:@"机器类型:\t%@", [device systemName]]];
    [self recordStepInfo:[NSString stringWithFormat:@"系统版本:\t%@", [device systemVersion]]];
    
    
    //运营商信息
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc]init];
    CTCarrier *carrier = [netInfo subscriberCellularProvider];
    if (carrier!=NULL) {
        [self recordStepInfo:[NSString stringWithFormat:@"运营商:\t%@", [carrier carrierName]]];
        [self recordStepInfo:[NSString stringWithFormat:@"ISOCountryCode:\t%@", [carrier mobileCountryCode]]];
        [self recordStepInfo:[NSString stringWithFormat:@"MobileCountryCode:\t%@", [carrier mobileCountryCode]]];
        [self recordStepInfo:[NSString stringWithFormat:@"MobileNetworkCode:\t%@", [carrier mobileNetworkCode]]];
    }
}


/**
 * 开始诊断网络
 */
-(void) startNetDiagnosis{
    if(!_dormain || [_dormain isEqualToString:@""]) return;
    
    _isRunning = YES;
    [_logInfo setString:@""];
    [self recordStepInfo:@"开始诊断..."];
    [self recordCurrentAppVersion];
    
    //诊断ping信息, 同步过程
    [self recordStepInfo:[NSString stringWithFormat:@"\n\n诊断域名 %@...", _dormain]];
    [self recordStepInfo:@"\n开始ping..."];
    _netPinger = [[LDNetPing alloc] init];
    _netPinger.delegate = self;
    [_netPinger runWithHostName: _dormain];
    
    
    //开始诊断traceRoute
    [self recordStepInfo:@"\n开始traceroute..."];
    _traceRouter = [[LDNetTraceRoute alloc] initWithMaxTTL:TRACEROUTE_MAX_TTL timeout:TRACEROUTE_TIMEOUT maxAttempts:TRACEROUTE_ATTEMPTS port:TRACEROUTE_PORT];
    _traceRouter.delegate = self;
    if(_traceRouter) {
        [NSThread detachNewThreadSelector:@selector(doTraceRoute:) toTarget:_traceRouter withObject:_dormain];
    }
}

/**
 * 停止诊断网络
 */
-(void) stopNetDialogsis {
    if(_isRunning){
        if(_netPinger != nil){
            [_netPinger  stopPing];
            _netPinger = nil;
        }
        
        if(_traceRouter != nil) {
            [_traceRouter stopTrace];
            _traceRouter = nil;
        }
        
        _isRunning = NO;
    }
}


/**
 * 打印整体loginInfo；
 */
-(void)printLogInfo {
    NSLog(@"\n%@\n", _logInfo);
}





#pragma mark netPingDelegate
-(void)appendPingLog:(NSString *)pingLog {
    [self recordStepInfo:pingLog];
}

-(void) netPingDidEnd {
    //net
}

#pragma mark - traceRouteDelegate
-(void) appendRouteLog:(NSString *)routeLog {
    [self recordStepInfo:routeLog];
}

-(void) traceRouteDidEnd {
    _isRunning = NO;
    if(self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]){
        [self.delegate netDiagnosisDidEnd:_logInfo];
    }
}


#pragma mark - common method
/**
 * 如果调用者实现了stepInfo接口，输出信息
 */
-(void) recordStepInfo:(NSString *)stepInfo{
    [_logInfo appendString:stepInfo];
    [_logInfo appendString:@"\n"];

    if(self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisStepInfo:)]){
        [self.delegate netDiagnosisStepInfo:[NSString stringWithFormat:@"%@\n", stepInfo]];
    }
}






@end
