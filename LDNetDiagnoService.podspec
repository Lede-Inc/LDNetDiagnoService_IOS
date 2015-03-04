Pod::Spec.new do |s|
  s.name     = 'LDNetDiagnoService'
  s.version  = '1.0.1'
  s.license  = {:type => 'MIT', :file => 'LICENSE'}
  s.summary  = '利用ping和traceroute的原理，对指定域名（通常为后台API的提供域名）进行网络诊断，并收集诊断日志。'
  s.homepage = 'https://git.ms.netease.com/commonlibraryios/LDNetDiagnoService_IOS'
  s.authors  = { 'huipang' => 'huipang@corp.netease.com' }
  s.source   = { :git => 'https://git.ms.netease.com/commonlibraryios/LDNetDiagnoService_IOS.git', :tag => "1.0.1"}

  s.platform = :ios
  s.requires_arc = true
  s.ios.deployment_target = '5.0'
  s.ios.public_header_files = 'LDNetDiagnoService/LDNetDiagnoService.h'
  s.ios.source_files = 'LDNetDiagnoService/*.{h,m}'
end
