#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define LOG(fmt, ...) NSLog(@"[NoSplash] " fmt, ##__VA_ARGS__)

%ctor {
    LOG(@"=== LazyAudioNoSplash loaded pid=%d ===", getpid());
}

/* 1) 本地 launchAd 数据模型：是否该展示 */
%hook LMLaunchAd
+ (BOOL)shouldShow:(id)arg0 {
    LOG(@"[LMLaunchAd shouldShow:] arg=%@ -> NO", arg0);
    return NO;
}
%end

/* 2) 最大展示次数桥：是否超今天上限 */
%hook LMLaunchAdMaxShowCountBridge
+ (BOOL)shouldShow:(id)arg0 {
    LOG(@"[LMLaunchAdMaxShowCountBridge shouldShow:] arg=%@ -> NO", arg0);
    return NO;
}
%end

/* 3) TME 开屏管理器：三个判断方法 -> 所有候选广告都视为不可展示 */
%hook TMEAdOperateSplashManager
- (BOOL)checkAdCanShow:(id)arg0 {
    LOG(@"[TMEAdOperateSplashManager checkAdCanShow:] arg=%@ -> NO", arg0);
    return NO;
}
- (BOOL)hasP0AdSplashCanShow {
    LOG(@"[TMEAdOperateSplashManager hasP0AdSplashCanShow] -> NO");
    return NO;
}
- (BOOL)hasP1AdSplashCanShow:(id)arg0 {
    LOG(@"[TMEAdOperateSplashManager hasP1AdSplashCanShow:] arg=%@ -> NO", arg0);
    return NO;
}
%end
