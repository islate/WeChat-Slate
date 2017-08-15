//
//  WeChatWrapper.m
//  Slate
//
//  Created by lin yize on 16-6-3.
//  Copyright (c) 2016年 islate. All rights reserved.
//

#import "WeChatWrapper.h"

#import "WXApi.h"
#import "WXApiObject.h"

#define WeixinRequestState @"weixin_login"

typedef void (^WeChatWrapperShareBlock)(BOOL success, BOOL isWeixinInstalled);
typedef void (^WeChatWrapperLoginBlock)(BOOL success, NSError *error, NSString *openId, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *rawInfo);

@interface WeChatWrapper () <WXApiDelegate>
{
    WeChatWrapperLoginBlock loginBlock;
    WeChatWrapperShareBlock shareBlock;
    
    NSString *weixinAppId;
    NSString *weixinSecret;
    
    NSURLSession *session;
    
    NSString *userOpenId;
    NSString *userUniqueId;
    NSString *userToken;
}

@property (nonatomic, strong) NSString *userAddingInfo;

@end

@implementation WeChatWrapper

// 单例
+ (instancetype)sharedWrapper
{
    static id sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

// 初始化设置参数
- (void)setWeixinAppId:(NSString *)appId secret:(NSString *)secret
{
    [WXApi registerApp:appId];
    weixinAppId = appId;
    weixinSecret = secret;
    _isSigning = NO;
}

- (BOOL)handleOpenURL:(NSURL *)url
{
    return [WXApi handleOpenURL:url delegate:self];
}

#pragma mark - login

- (BOOL)canHandleURL:(NSURL *)url
{
    return ([url.scheme hasPrefix:weixinAppId]);
}

- (void)weixinLogin:(void (^)(BOOL isLogin, NSString *openId, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *userAddingInfo))block
{
    [self login:^(BOOL success, NSError *error, NSString *openId, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *rawInfo) {
        if (error) {
            block(NO, nil, nil, nil, nil, nil);
        }
        else {
            block(YES, openId, unionId, nickname, avatarUrl, rawInfo);
        }
    }];
}

- (void)login:(void (^)(BOOL success, NSError *error, NSString *openId, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *rawInfo))block
{
    if ([WXApi isWXAppInstalled])
    {
        loginBlock = [block copy];
        
        if (block)
        {
            _isSigning = YES;
            
            SendAuthReq* req = [[SendAuthReq alloc ] init ];
            req.scope = @"snsapi_userinfo" ;
            req.state =  WeixinRequestState;
            //第三方向微信终端发送一个SendAuthReq消息结构
            [WXApi sendReq:req];
        }
    }
    else
    {
        if (block)
        {
            // 未安装微信
            NSError * error = [NSError errorWithDomain:@"Wechat error"
                                                  code:200
                                              userInfo:@{NSLocalizedDescriptionKey:@"wechat not installed"}];
            block(NO,error,nil,nil,nil,nil,nil);
        }
    }
}

- (BOOL)isWeixinInstalled
{
    return [WXApi isWXAppInstalled];
}

#pragma mark - share

- (void)weixinShareWithContent:(NSString *)content
                           url:(NSString *)sourceUrl
                         image:(UIImage *)image
                         title:(NSString *)title
                  imageIsThumb:(BOOL)imageIsThumb
               toFriendsCircle:(BOOL)toFriendsCircle
                    shareBlock:(void(^)(BOOL success, BOOL isWeixinInstalled))block
{
    if ([WXApi isWXAppInstalled])
    {
        shareBlock = [block copy];
        [self sendTextContent:content url:sourceUrl image:image title:title imageIsThumb:imageIsThumb toFriendsCircle:toFriendsCircle];
    }
    else
    {
        if (block)
        {
            block(NO, NO);
        }
    }
}

- (void)sendTextContent:(NSString*)nsText url:(NSString *)aUrl image:(UIImage *)image title:(NSString *)title imageIsThumb:(BOOL)isThumb toFriendsCircle:(BOOL)toFriendsCircle
{
    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];
    WXWebpageObject *webpageObject = [WXWebpageObject object];
    WXMediaMessage *mediaMessage = [WXMediaMessage message];
    
    if (([aUrl isEqualToString:@""] || aUrl == nil) &&
        ((NSNull *)image == [NSNull null] || image == nil))
    {
        req.bText = YES;
        req.text = nsText;
    }
    else
    {
        req.bText = NO;
        webpageObject.webpageUrl = aUrl;
        mediaMessage.mediaObject = webpageObject;
        mediaMessage.description = nsText;
        mediaMessage.title = title;
        
        if (image && (NSNull *)image != [NSNull null])
        {
            [mediaMessage setThumbImage:[self generateThumbnail:image]];
            if (!isThumb)
            {
                WXImageObject *imageObject = [WXImageObject object];
                imageObject.imageData = UIImageJPEGRepresentation(image, 1.0);
                //如果有长微博图片，不会再加入webpageObject。
                mediaMessage.mediaObject = imageObject;
            }
        }
        
        if (!req.bText) {
            req.message = mediaMessage;
        }
    }
    
    req.scene = (toFriendsCircle) ? WXSceneTimeline : WXSceneSession;
    
    [WXApi sendReq:req];
}

#pragma mark -
#pragma mark adjust image size
- (UIImage *)generateThumbnail:(UIImage *)image {
    CGSize size = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
    CGSize croppedSize;
    CGFloat ratio = 64.0 * 2;
    CGFloat offsetX = 0.0;
    CGFloat offsetY = 0.0;
    
    if (size.width > size.height) {
        offsetX = (size.height - size.width) / 2;
        croppedSize = CGSizeMake(size.height, size.height);
    } else if (size.width < size.height)
    {
        offsetY = (size.width - size.height) / 2;
        croppedSize = CGSizeMake(size.width, size.width);
    }else{
        croppedSize = size;
    }
    
    CGRect clippedRect = CGRectMake(offsetX * -1, offsetY * -1, croppedSize.width, croppedSize.height);
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], clippedRect);
    
    CGRect rect = CGRectMake(0.0, 0.0, ratio, ratio);
    
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1.0);
    [[UIImage imageWithCGImage:imageRef] drawInRect:rect];
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    CGImageRelease(imageRef);
    UIGraphicsEndImageContext();
    
    return thumbnail;
}

#pragma mark - token request && userInfo request
- (void)requestWeixinTokenWithCode:(NSString *)code
{
    _isSigning = NO;
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code",weixinAppId,weixinSecret,code];
    [self requestWithURL:url
              completion:^(NSDictionary *responseDict, NSError* error) {
                  if (responseDict)
                  {
                      userUniqueId = responseDict[@"unionid"];
                      if (userUniqueId.length > 0)
                      {
                          userOpenId = responseDict[@"openid"];
                          userToken = responseDict[@"access_token"];
                          [self requestUserInfo];
                      }
                      else
                      {
                          if (loginBlock)
                          {
                              NSError * error = [NSError errorWithDomain:@"Wechat error"
                                                                    code:300
                                                                userInfo:@{NSLocalizedDescriptionKey:@"wechat unionid is empty"}];
                              loginBlock(NO, error, nil,nil,nil,nil,nil);
                              loginBlock = nil;
                          }
                      }
                  }
                  else
                  {
                      if (loginBlock)
                      {
                          loginBlock(NO,error,nil,nil,nil,nil,nil);
                          loginBlock = nil;
                      }
                  }
              }];
}

- (void)requestUserInfo
{
    NSString *url = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@",userToken,userOpenId];
    [self requestWithURL:url
              completion:^(NSDictionary *responseDict, NSError *error) {
                  if (responseDict)
                  {
                      NSString *nickname = responseDict[@"nickname"];
                      NSString *avatar = responseDict[@"headimgurl"];
                      if (loginBlock)
                      {
                          loginBlock(YES,nil,userOpenId,userUniqueId,nickname,avatar,self.userAddingInfo);
                          loginBlock = nil;
                      }
                  }
                  else
                  {
                      if (loginBlock)
                      {
                          loginBlock(NO,error,nil,nil,nil,nil,nil);
                          loginBlock = nil;
                      }
                  }
              }];
}

- (void)requestWithURL:(NSString *)url
            completion:(void(^)(NSDictionary *responseDict, NSError* error))completion
{
    if (!session)
    {
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:url]
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                            if (error) {
                                                if (completion) {
                                                    completion(nil, error);
                                                }
                                                return;
                                            }
                                            
                                            NSError * otherError = nil;
                                            NSString *exceText = nil;
                                            NSError *jsonError = nil;
                                            NSDictionary *dict = nil;
                                            @try {
                                                weakSelf.userAddingInfo = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                                                if (data)
                                                {
                                                    dict = [NSJSONSerialization JSONObjectWithData:data
                                                                                           options:NSJSONReadingAllowFragments
                                                                                             error:&jsonError];
                                                }
                                            } @catch (NSException *exception) {
                                                exceText = exception.reason;
                                            }
                                            
                                            if (jsonError) {
                                                otherError = jsonError;
                                                dict = nil;
                                            }
                                            else if (exceText) {
                                                dict = nil;
                                                otherError = [NSError errorWithDomain:@"Wechat error"
                                                                                  code:400
                                                                              userInfo:@{NSLocalizedDescriptionKey:exceText}];
                                            }
                                            
                                            if (completion)
                                            {
                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                    completion(dict, otherError);
                                                });
                                            }
                                        }];
    [task resume];
}

#pragma mark - 
#pragma mark - WXDelegate
- (void)onResp:(BaseResp*)resp
{
    if ([resp isKindOfClass:[SendAuthResp class]])
    {
        // auth
        SendAuthResp *response = (SendAuthResp *)resp;
        if (response.errCode == 0)
        {
            // 授权
            if (loginBlock)
            {
                if ([response.state isEqualToString:WeixinRequestState])
                {
                    [self requestWeixinTokenWithCode:response.code];
                }
                else
                {
                    NSString *errorText = [NSString stringWithFormat:@"response.state is %@", response.state];
                    NSError * error = [NSError errorWithDomain:@"Wechat error"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey:errorText}];
                    loginBlock(NO,error,nil,nil,nil,nil,nil);
                    loginBlock = nil;
                }
            }
        }
        else
        {
            // 没有授权
            if (loginBlock)
            {
                NSError * error = [NSError errorWithDomain:@"Wechat error"
                                                      code:response.errCode
                                                  userInfo:@{NSLocalizedDescriptionKey:response.errStr}];
                loginBlock(NO,error,nil,nil,nil,nil,nil);
                loginBlock = nil;
            }
        }
    }
    else
    {
        // 分享
        if (shareBlock)
        {
            if (resp.errCode == 0)
            {
                shareBlock(YES,YES);
                shareBlock = nil;
            }
            else
            {
                shareBlock(NO,YES);
                shareBlock = nil;
            }
        }
    }
}

- (BOOL)isWeixinLoginSupported
{
    if (weixinSecret.length > 0)
    {
        if ([weixinSecret isEqualToString:@"weixinSecret"])
        {
            return NO;
        }
        
        if ([self isWeixinInstalled])
        {
            return YES;
        }
    }
    return NO;
}

@end
