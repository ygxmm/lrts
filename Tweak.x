#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ================= 补充声明 =================
@interface MeSignButton : UIView
@end
@interface LaunchSplashWindow : UIWindow
@end
@interface TabBarItemView : UIView
@end
// ============================================

// ================= 1. 干掉签到按钮 =================
%hook MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0;
    self.userInteractionEnabled = NO;
}
%end

// ================= 2. 干掉开屏 Window =================
%hook LaunchSplashWindow

- (void)makeKeyAndVisible {
    // 拦截上屏
}

- (void)setHidden:(BOOL)hidden {
    hidden = YES; // 核心修复：修改局部变量
    %orig;        // 无参调用，直接应用修改后的变量
}

%end

// 广点通广告 Window 同样处理
%hook Advertisement_SplashAdWindow
- (void)makeKeyAndVisible { /* 拦截上屏 */ }
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
%end

// ================= 3. 干掉开屏广告控制器 =================
%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    self.view.alpha = 0;
}
%end

%hook Advertisement_SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    self.view.alpha = 0;
}
%end

// ================= 4. 底栏福利去掉并自动重排 =================
%hook TabBarItemView
- (void)layoutSubviews {
    %orig;
    // 探针实锤 tag==3 是福利
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
        self.center = CGPointMake(-9999, self.center.y); // 移出屏幕触发重排
    }
}
%end

// ================= 5. 弹窗拦截 =================
%hook UIViewController
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([vc class]);
    if ([clsName containsString:@"Alert"] || 
        [clsName containsString:@"Popup"] || 
        [clsName containsString:@"Coin"] ||
        [clsName containsString:@"Reward"]) {
        return;
    }
    %orig;
}
%end
