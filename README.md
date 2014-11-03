# LDNetDiagnoService_IOS
===============

>利用ping和traceroute的原理，对指定域名（通常为后台API的提供域名）进行网络诊断，并收集诊断日志。功能通过Service的方式提供给各个产品项目，由各个项目组决定如何使用。



## LDNetDiagnoService最终效果
-------------------
>
* 调用网络诊断服务，监控日志输出；
* 诊断结束之后，返回日志文本;
* 调用者可以选择保存、邮件上传、接口上传等方式上传监控日志；

>如下图所示：



## 如何集成LDNetDiagnoService_IOS
-------------------

### Pod集成

>
强烈推荐采用Pod集成。具体方法如下：

1.  Clone线上repo仓库到本地 (第一次创建私有类库引用)

		pod repo add podspec https://git.ms.netease.com/commonlibraryios/podspec.git 
		pod repo update podspec
	
2. 在项目工程的Podfile文件中加载LDNetDiagnoService库：

		pod 'LDNetDiagnoService'


### 代码拷贝集成

>
如果没有私有库Pod访问权限（可以联系技术支持），也可以拷贝工程中[LDNetDiagnoService文件夹](LDNetDiagnoService) 到你所在项目的工程文件夹中 进行代码集成；


## 如何使用LDNetDiagnoService_IOS
---------------------------------

>
 在IOS项目中，当展示WAP页面的时候会用到UIWebView组件，我们通过在UIWebView组件所在的Controller中注册JSAPIServie服务，拦截Webview的URL进行处理。
 
 * 在Webview所在的Controller中初始化一个JSAPIService，并注册该WebView需要使用的插件
 
		-(void) viewDidLoad {
    		[super viewDidLoad];
    
    		....
    
	    	//创建webview
	    	[self createGapView];
        
		    //注册插件Service
    		if(_jsService == nil){
        		_jsService = [[LDJSService alloc] initWithWebView:_webview];
    		}
    

    		//批量测试
			//NSDictionary *pluginsDic = [NSDictionary dictionaryWithObjects:ARR_PLUGINS_CLASS forKeys:ARR_PLUGINS_KEY];
			//[_jsService registerPlugins:pluginsDic];
			//[_jsService unRegisterAllPlugins];
    
		    //单个注册测试, 
		    //device是js调用namespace名称， 
			//LDPDevice 是Natvie插件的Class名称
    		[_jsService registerPlugin:@"device" withPluginClass:@"LDPDevice"];
		    [_jsService registerPlugin:@"app" withPluginClass:@"LDPAppInfo"];
    		[_jsService registerPlugin:@"nav" withPluginClass:@"LDPUINavCtrl"];
		    [_jsService registerPlugin:@"ui" withPluginClass:@"LDPUIGlobalCtrl"];
		  	
		  	 ....
		    
		  }

 
 
 * 通过WebviewDelegate拦截url请求，处理JSAPI中发送的jsbridge://请求
 

		- (BOOL)webView:(UIWebView*)theWebView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
		{
			//拦截JSBridge命令
			if([[url scheme] isEqualToString:@"jsbridge"]){
        		[_jsService handleURLFromWebview:[url absoluteString]];
        		return NO;
    		}
    		
    		....

		}



## 定义NavigationController导航的Wap功能模块
-------------------------------------------

>
在手机qq里可以看到很多独立的基于WAP页面的功能模块，其实基于JSBridge的JSAPI最大的用处是以这种方式呈现。

* 目前在demo工程中已经初步完成了Device、App、UI导航部分的示例（参看[LDPBaseWebViewCrtl.m 文件](CommonJSAPI/LDPBaseWebViewCrtl.m)），客户端可以在此基础上根据项目需求进行完善开发：


>
		

## 技术支持
-------------------


>
to be continued ....



庞辉, 电商技术中心，popo：__huipang@corp.netease.com__
