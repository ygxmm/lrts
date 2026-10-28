#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

static BOOL gEnableTabBar = YES;
static BOOL gEnableSignButton = YES;
static BOOL gEnableSplash = YES;
static BOOL gEnablePopup = YES;

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

__attribute__((constructor)) static void LAInitSwitches(void) {
    NSString *path = @"/var/mobile/dyyy/lazyaudio-nosplash/switches.plist";
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!d) {
        NSLog(@"[LazyAudio] switches.plist 未找到，全部功能默认开启: %@", path);
        return;
    }
    gEnableTabBar     = d[@"tabbar"]     ? [d[@"tabbar"] boolValue]     : YES;
    gEnableSignButton = d[@"signbutton"] ? [d[@"signbutton"] boolValue] : YES;
    gEnableSplash     = d[@"splash"]     ? [d[@"splash"] boolValue]     : YES;
    gEnablePopup      = d[@"popup"]      ? [d[@"popup"] boolValue]      : YES;
    NSLog(@"[LazyAudio] 开关 tabbar=%d sign=%d splash=%d popup=%d",
          gEnableTabBar, gEnableSignButton, gEnableSplash, gEnablePopup);
}

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

// ========== 1. 底栏重排（开关 tabbar）==========
%hook UIView
- (void)layoutSubviews {
    %orig;

    if (!gEnableTabBar) {
        return;
    }
    if (objc_getAssociatedObject(self, &kLAIgnoredKey)) {
        return;
    }

    NSArray<UIView *> *subs = self.subviews;
    NSUInteger cnt = subs.count;
    if (cnt < 2 || cnt > 10) {
        objc_setAssociatedObject(self, &kLAIgnoredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSMutableArray<UIView *> *visible = nil;
    for (UIView *sub in subs) {
        if (!LAIsTabItem(sub)) {
            continue;
        }
        if (sub.tag == 3) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
            sub.frame = CGRectZero;
        } else {
            if (!visible) {
                visible = [NSMutableArray array];
            }
            [visible addObject:sub];
        }
    }

    if (!visible || visible.count == 0) {
        objc_setAssociatedObject(self, &kLAIgnoredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSUInteger n = visible.count;
    CGFloat W = self.bounds.size.width;
    if (W <= 0) {
        return;
    }
    UIView *first = visible.firstObject;
    CGFloat y = first.frame.origin.y;
    CGFloat h = first.frame.size.height;
    if (h <= 0) {
        h = self.bounds.size.height;
    }
    CGFloat w = W / (CGFloat)n;
    for (NSUInteger i = 0; i < n; i++) {
        visible[i].frame = CGRectMake(w * (CGFloat)i, y, w, h);
    }
}
%end

// ========== 2. TabBarItemView 隐藏 tag==3（开关 tabbar）==========
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (!gEnableTabBar) {
        return;
    }
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
- (void)didMoveToWindow {
    %orig;
    if (!gEnableTabBar) {
        return;
    }
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
%end

// ========== 3. 签到按钮（开关 signbutton）==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    if (!gEnableSignButton) {
        return;
    }
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

// ========== 4. 开屏 Window / VC（开关 splash）==========
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden {
    if (gEnableSplash) {
        hidden = YES;
    }
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    if (gEnableSplash) {
        self.hidden = YES;
    }
}
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden {
    if (gEnableSplash) {
        hidden = YES;
    }
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    if (gEnableSplash) {
        self.hidden = YES;
    }
}
%end

%hook _TtC13Advertisement22SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gEnableSplash) {
        return;
    }
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gEnableSplash) {
        return;
    }
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

// ========== 5. 弹窗拦截（开关 popup）==========
%hook UIViewController
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!gEnablePopup || !vc) {
        %orig;
        return;
    }
    NSString *cls = NSStringFromClass([vc class]);
    static NSArray *allow = nil;
    static NSArray *blocked = nil;
    if (!allow) {
        allow = @[@"Probe", @"FLEX", @"Debug", @"Inspector", @"Console", @"ClassDump", @"Dump"];
        blocked = @[@"Alert", @"Popup", @"Coin", @"Reward"];
    }
    for (NSString *k in allow) {
        if ([cls rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
            %orig;
            return;
        }
    }
    if ([vc isKindOfClass:[UIAlertController class]]) {
        %orig;
        return;
    }
    for (NSString *k in blocked) {
        if ([cls rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
    }
    %orig;
}
%end
