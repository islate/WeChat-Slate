
Pod::Spec.new do |s|

  s.name         = "WeChat-Slate"
  s.version      = "0.1.1"
  s.summary      = "Slate WeChat Wrapper."


  s.description  = <<-DESC
		   Slate WeChat Wrapper.   
           WeChatSDK ver 1.7.9
                   DESC

  s.homepage     = "http://github.com/islate/WeChat-Slate"
  s.license      = "Apache 2.0"
  s.author       = { "linyize" => "linyize@gmail.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "http://github.com/islate/WeChat-Slate.git", :tag => "#{s.version}" }

  s.dependency 'WeChatSDK', '1.7.9'

  s.source_files  = 'WeChatWrapper.*'

end
