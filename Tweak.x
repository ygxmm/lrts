#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ================= 补充头文件声明（让编译器认识这些带点的 Swift 类） =================
// 声明父类，解决找不到 hidden、alpha 等属性的问题
@interface MeSignButton : UIView
@end

@interface LaunchSplashWindow : UIWindow
@end

@interface TabBarItemView : UIView
@end
// =====================================================================================

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

- (void)setHidden:(BOOL)hidden {
    %orig(YES); // 永远保持隐藏
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0); // 永远保持透明
}

%end

// ================= 3. 干掉底栏福利并触发重排 =================
%hook TabBarItemView

- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
        self.center = CGPointMake(-9999, self.center.y);
    }
}

%end

// ================= 4. 拦截所有弹窗控制器 =================
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
    if ([clsName containsString:@"Alert"] || 
        [clsName containsString:@"Popup"] || 
        [clsName containsString:@"Coin"] ||
        [clsName containsString:@"Reward"]) {
        NSLog(@"[Tweak] 成功拦截弹窗: %@", clsName);
        return;
    }
    %orig;
}

%end
