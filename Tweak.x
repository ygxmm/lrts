#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ================= 1. 斩首签到按钮 (基于 MeSignButton.h) =================
%hook MeSignButton

// 无论它是 initWithFrame 还是 didMoveToWindow，只要它想上屏，我们就隐藏
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0;
    self.userInteractionEnabled = NO;
}

%end

// ================= 2. 干掉开屏广告 (基于 LaunchSplashWindow / TGGDTSplashViewController.h) =================
// 原生开屏 Window，拒绝上屏
%hook LaunchSplashWindow
- (void)makeKeyAndVisible {
    // 拦截，不给上屏
}
%end

// 广点通开屏 VC，一出现就隐身
%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    self.view.alpha = 0;
}
%end

// ================= 3. 底栏福利隐藏 (基于 TabBarItemView.h) =================
%hook TabBarItemView
- (void)layoutSubviews {
    %orig;
    // 探针实锤，福利的 tag 为 3
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
    }
}
%end

// ================= 4. 赚钱悬浮球隐藏 (基于 EarningTask 系列头文件) =================
%hook EarningTaskBallView
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
}
%end

%hook OnlineEarningNewEntryView
- (void)updateStateWithIsEnforce:(BOOL)enforce {
    %orig;
    self.hidden = YES;
}
%end

// ================= 5. 拦腰斩断弹窗调度中心 (最核心) =================
// 由于头文件里有一大堆 AlertDispatcher 系列（Service, API, Model），
// 我们直接在最底层的 UIViewController 层面，拦截所有可能带有弹窗意义的弹窗
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
    
    // 只要类名带这些字眼，直接拒绝弹出，连动画都不给
    if ([clsName containsString:@"AlertDispatcher"] ||
        [clsName containsString:@"CouponAlert"] ||
        [clsName containsString:@"Coin"] ||
        [clsName containsString:@"Earn"] ||
        [clsName containsString:@"Sign"] ||
        [clsName containsString:@"Reward"] ||
        [clsName containsString:@"Popup"]) {
        
        NSLog(@"[Tweak] 成功拦截恶心弹窗: %@", clsName);
        return; 
    }
    
    %orig;
}
%end
