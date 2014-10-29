//
//  ViewController.m
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#import "ViewController.h"
#import "LDNetDiagnoService.h"

@interface ViewController () <LDNetDiagnoServiceDelegate> {
    UIActivityIndicatorView *_indicatorView;
    UITextView *_txtView_log;
    
    NSString *_logInfo;
    LDNetDiagnoService *_netDiagnoService;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"诊断信息";
    
    _indicatorView = [[UIActivityIndicatorView alloc]
                      initWithActivityIndicatorStyle:
                      UIActivityIndicatorViewStyleGray];
    _indicatorView.frame = CGRectMake(0, 0, 30, 30);
    _indicatorView.hidden = NO;
    _indicatorView.hidesWhenStopped = YES;
    [_indicatorView startAnimating];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:_indicatorView];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    _txtView_log = [[UITextView alloc] initWithFrame:CGRectZero];
    _txtView_log.backgroundColor = [UIColor whiteColor];
    _txtView_log.font = [UIFont systemFontOfSize:10.0f];
    _txtView_log.textAlignment = NSTextAlignmentLeft;
    _txtView_log.scrollEnabled = YES;
    _txtView_log.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    [self.view addSubview:_txtView_log];
    
    
    // Do any additional setup after loading the view, typically from a nib.
    _netDiagnoService = [[LDNetDiagnoService alloc] initWithAppCode:@"testDemo" userID:@"huipang@corp.netease.com" dormain:@"caipiao.163.com"];
    _netDiagnoService.delegate = self;
    _logInfo = @"";
    [_netDiagnoService startNetDiagnosis];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark NetDiagnosisDelegate
-(void)netDiagnosisDidStarted {
    NSLog(@"开始诊断～～～");
}

-(void)netDiagnosisStepInfo:(NSString *)stepInfo {
    NSLog(@"%@", stepInfo);
    _logInfo = [_logInfo stringByAppendingString:stepInfo];
    dispatch_async(dispatch_get_main_queue(), ^{
        _txtView_log.text = _logInfo;
    });
}

    

-(void)netDiagnosisDidEnd:(NSString *)allLogInfo;{
    NSLog(@"logInfo>>>>>\n%@", allLogInfo);
    //可以保存到文件，也可以通过邮件发送回来
    dispatch_async(dispatch_get_main_queue(), ^{
        [_indicatorView stopAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"邮件" style:UIBarButtonItemStylePlain target:self action:@selector(emailLogInfo)];
    });
}

-(void) emailLogInfo {
    [_netDiagnoService printLogInfo];
}

@end
