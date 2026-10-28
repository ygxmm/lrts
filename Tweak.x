#import <UIKit/UIKit.h>

// Swift 类在 ObjC Runtime 下的实际类名前置声明
@interface _TtC9lazyaudio14TabBarItemView : UIView
@end
@interface _TtC9lazyaudio12MeSignButton : UIView
@end
@interface _TtC9lazyaudio18LaunchSplashWindow : UIWindow
@end
@interface _TtC13Advertisement22SplashAdViewController : UIViewController
@end
@interface _TtC13Advertisement14SplashAdWindow : UIWindow
@end
@interface TGGDTSplashViewController : UIViewController
@end

// 1. 隐藏底部“福利”Tab：tag == 3，剩余 4 个自动重排
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
        self.center = CGPointMake(-9999, self.center.y);
    }
}
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
        self.center = CGPointMake(-9999, self.center.y);
    }
}
%end

// 2. 干掉“签到领钱”按钮
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
%end

// 3. 拦截 lazyaudio 开屏 Window
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    self.hidden = YES;
}
%end

// 4. 拦截 Advertisement.SplashAdWindow
%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    self.hidden = YES;
}
%end

// 5. 拦截 Advertisement.SplashAdViewController
%hook _TtC13Advertisement22SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

// 6. 拦截广点通开屏控制器
%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

// 7. 拦截 Alert / Popup / Coin / Reward 类弹窗
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!viewControllerToPresent) {
        %orig;
        return;
    }
    NSString *className = NSStringFromClass([viewControllerToPresent class]);
    NSArray<NSString *> *blockedKeywords = @[@"Alert", @"Popup", @"Coin", @"Reward"];
    for (NSString *keyword in blockedKeywords) {
        if ([className rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
    }
    %orig;
}
%end
