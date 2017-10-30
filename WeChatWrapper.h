//
//  WeChatWrapper.h
//  Slate
//
//  Created by lin yize on 16-6-3.
//  Copyright (c) 2016年 modernmedia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WeChatWrapper : NSObject

@property (nonatomic,assign) BOOL isSigning;

// 单例
+ (instancetype)sharedWrapper;

// 初始化设置参数
- (void)setWeixinAppId:(NSString *)appId secret:(NSString *)secret;

- (void)weixinLogin:(void (^)(BOOL isLogin, NSString *openId, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *userAddingInfo))loginBlock;
- (void)weixinShareWithContent:(NSString *)content
                           url:(NSString *)sourceUrl
                         image:(UIImage *)image
                         title:(NSString *)title
                  imageIsThumb:(BOOL)imageIsThumb
               toFriendsCircle:(BOOL)toFriendsCircle
                    shareBlock:(void(^)(BOOL success, BOOL isWeixinInstalled))shareBlock;
- (BOOL)isWeixinInstalled;
- (BOOL)isWeixinLoginSupported;
- (BOOL)canHandleURL:(NSURL *)url;
- (BOOL)handleOpenURL:(NSURL *)url;

- (void)login:(void (^)(BOOL success, NSError *error, NSString *openId, NSString *accessToken, NSString *unionId, NSString *nickname, NSString *avatarUrl, NSString *rawInfo))loginBlock;

@end
