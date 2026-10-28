#import <UIKit/UIKit.h>

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

// 找到真正装多个 TabBarItemView 的祖先容器，然后重排
static void LAFixTabBar(UIView *item) {
    UIView *parent = item.superview;
    while (parent) {
        NSUInteger cnt = 0;
        for (UIView *sub in parent.subviews) {
            if ([NSStringFromClass([sub class]) containsString:@"TabBarItemView"]) cnt++;
        }
        if (cnt >= 2) break;
        parent = parent.superview;
    }
    if (!parent) return;

    NSMutableArray<UIView *> *visibles = [NSMutableArray array];
    for (UIView *sub in parent.subviews) {
        if (![sub isKindOfClass:[UIView class]]) continue;
        NSString *cls = NSStringFromClass([sub class]);
        if (![cls containsString:@"TabBarItemView"]) continue;
        if (sub.tag == 3) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
            sub.frame = CGRectMake(-9999, sub.frame.origin.y, sub.frame.size.width, sub.frame.size.height);
        } else {
            [visibles addObject:sub];
        }
    }

    NSUInteger n = visibles.count;
    if (n == 0) return;

    CGFloat W = parent.bounds.size.width;
    CGFloat H = parent.bounds.size.height;
    if (W <= 0) return;

    CGFloat h = visibles.firstObject.frame.size.height;
    if (h <= 0) h = H;
    CGFloat y = visibles.firstObject.frame.origin.y;
    if (isnan(y)) y = 0;

    CGFloat w = W / (CGFloat)n;
    for (NSUInteger i = 0; i < n; i++) {
        UIView *v = visibles[i];
        v.frame = CGRectMake(w * i, y, w, h);
    }
}

// ========== 1. 底栏：隐藏福利 + 剩余 4 项均分 ==========
%hook _TtC9lazyaudio14TabBarItemView

- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        LAFixTabBar(self);
    });
}

- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        LAFixTabBar(self);
    });
}

%end

// ========== 2. 签到按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

// ========== 3. 开屏 Window ==========
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden { hidden = YES; %orig; }
- (void)makeKeyAndVisible { %orig; self.hidden = YES; }
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden { hidden = YES; %orig; }
- (void)makeKeyAndVisible { %orig; self.hidden = YES; }
%end

%hook _TtC13Advertisement22SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

// ========== 4. 弹窗拦截 ==========
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!viewControllerToPresent) { %orig; return; }
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
