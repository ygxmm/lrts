#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 补充声明
@interface MeSignButton : UIView
@end
@interface LaunchSplashWindow : UIWindow
@end
@interface TabBarItemView : UIView
@end

// ================= 1. 干掉签到按钮 =================
%hook MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0;
}
%end

// ================= 2. 干掉开屏 Window =================
%hook LaunchSplashWindow
- (void)makeKeyAndVisible { /* 拒绝上屏 */ }
- (void)setHidden:(BOOL)hidden { %orig(YES); }
%end

%hook Advertisement_SplashAdWindow
- (void)makeKeyAndVisible { /* 拒绝上屏 */ }
- (void)setHidden:(BOOL)hidden { %orig(YES); }
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
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
        // 直接移出屏幕，触发底层自动排版
        self.center = CGPointMake(-9999, self.center.y);
    }
}
%end

// ================= 5. 弹窗拦截 =================
%hook UIViewController
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([vc class]);
    if ([clsName containsString:@"Alert"] || [clsName containsString:@"Popup"] || [clsName containsString:@"Coin"]) {
        return;
    }
    %orig;
}
%end
