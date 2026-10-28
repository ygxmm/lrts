#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ================= 1. 干掉签到按钮 =================
// 头文件: lazyaudio.MeSignButton : LMGradientButton
%hook MeSignButton

// 直接在视图初始化或上屏时隐藏
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0;
    self.userInteractionEnabled = NO;
}

%end

// ================= 2. 干掉开屏 Window =================
// 头文件: lazyaudio.LaunchSplashWindow : UIWindow
%hook LaunchSplashWindow

// 探针实锤它重写了 hidden 属性，说明底层是用这个方法上屏的
- (void)setHidden:(BOOL)hidden {
    %orig(YES); // 无论底层传什么，永远保持 YES（隐藏）
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0); // 连透明度都锁死为 0
}

%end

// ================= 3. 干掉底栏福利并触发重排 =================
// 头文件: lazyaudio.TabBarItemView : UIView
%hook TabBarItemView

// 探针实锤：福利的 tag 为 3
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
        // 因为你的测试表明，只要隐藏它，底层 Swift 会自动将其余 4 个重排。
        // 所以这里我们直接改 center 把它移出屏幕，防止它占位
        self.center = CGPointMake(-9999, self.center.y);
    }
}

%end

// ================= 4. 拦截所有弹窗控制器 =================
// 头文件里有一大堆 AlertController、Popup，我们直接在 UIViewController 拦截
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
    
    // 基于头文件：CouponAlert, ServerAlert, LMAwardAlert 等，通杀
    if ([clsName containsString:@"Alert"] || 
        [clsName containsString:@"Popup"] || 
        [clsName containsString:@"Coin"] ||
        [clsName containsString:@"Reward"]) {
        NSLog(@"[Tweak] 成功拦截弹窗: %@", clsName);
        return; // 直接拦截，不让它弹
    }
    %orig;
}

%end
