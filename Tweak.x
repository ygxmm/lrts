#import "Tweak.h"

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

// ========== 预加载方法封装 ==========
static void LADoPreload(void) {
    Class bridgeClass = objc_getClass("AudioPlayerBridge");
    if (bridgeClass) {
        SEL sel = NSSelectorFromString(@"loadPlayerButNotAutoPlay");
        if ([bridgeClass respondsToSelector:sel]) {
            ((void (*)(id, SEL))objc_msgSend)(bridgeClass, sel);
        }
    }
}

__attribute__((constructor)) static void LAInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        LADoPreload();
    });
}

// ========== 1. 极早预加载兜底 ==========
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls isEqualToString:@"lazyaudio.AppPrepareController"] || 
        [cls isEqualToString:@"lazyaudio.AppMainController"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LADoPreload();
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls isEqualToString:@"lazyaudio.AppMainController"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LADoPreload();
        });
    }
}
%end

// ========== 2. 弹窗池源头拦截 ==========
%hook AlertPool
+ (void)add:(id)a0 {
    NSString *cls = NSStringFromClass([a0 class]);
    if ([cls containsString:@"FreeMode"] || [cls containsString:@"AdFree"] || 
        [cls containsString:@"Coin"] || [cls containsString:@"Reward"] || 
        [cls containsString:@"PlayerAdFree"]) {
        return;
    }
    %orig;
}
%end

// ========== 3. BaseAlertController 基类拦截 ==========
%hook _TtC9lazyaudio18BaseAlertController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"FreeMode"] || [cls containsString:@"AdFree"] || 
        [cls containsString:@"Coin"] || [cls containsString:@"Reward"] || 
        [cls containsString:@"PlayerAdFree"]) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"FreeMode"] || [cls containsString:@"AdFree"] || 
        [cls containsString:@"Coin"] || [cls containsString:@"Reward"] || 
        [cls containsString:@"PlayerAdFree"]) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}
%end

// ========== 4. UIView 类型弹窗精准拦截 ==========
%hook _TtC9lazyaudio20FreeModeTimeoutAlert
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}
%end

%hook _TtC9lazyaudio17ReaderFreeAdAlert
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}
%end

// ========== 5. 底栏重排 ==========
%hook UIView
- (void)layoutSubviews {
    %orig;

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
            if (!sub.hidden) sub.hidden = YES;
            if (sub.alpha != 0.0) sub.alpha = 0.0;
            if (sub.userInteractionEnabled) sub.userInteractionEnabled = NO;
            if (!CGRectEqualToRect(sub.frame, CGRectZero)) {
                sub.frame = CGRectZero;
            }
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

    CGFloat itemW = first.frame.size.width;
    if (itemW <= 0 || itemW > W) {
        itemW = 60;
    }

    CGFloat margin = first.frame.origin.x;
    if (margin < 0 || margin > W / 4) {
        margin = 15;
    }

    CGFloat totalGap = W - 2 * margin - n * itemW;
    CGFloat gap = (n > 1) ? totalGap / (n - 1) : 0;
    if (gap < 0) {
        gap = 0;
    }

    for (NSUInteger i = 0; i < n; i++) {
        CGFloat x = margin + i * (itemW + gap);
        CGRect target = CGRectMake(x, y, itemW, h);
        if (!CGRectEqualToRect(visible[i].frame, target)) {
            visible[i].frame = target;
        }
    }
}
%end

// ========== 6. TabBarItemView 兜底 ==========
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
        if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
    }
}
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
        if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
    }
}
%end

// ========== 7. 签到按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    if (!self.hidden) self.hidden = YES;
    if (self.alpha != 0.0) self.alpha = 0.0;
    if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
}
%end

// ========== 8. 开屏 Window ==========
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)didMoveToWindow {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
}
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.0;
    self.hidden = YES;
}
%end

// ========== 9. 赚钱悬浮球 / 提示 / 任务入口 ==========
%hook _TtC9lazyaudio25OnlineEarningNewLevitator
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

%hook _TtC9lazyaudio24OnlineEarningNewTipsView
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

%hook _TtC9lazyaudio19EarningTaskBallView
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

%hook _TtC9lazyaudio20EarningTaskEntryView
- (void)refreshWithIsVisible:(BOOL)visible {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
}
%end

%hook _TtC9lazyaudio25OnlineEarningNewEntryView
- (void)updateStateWithIsEnforce:(BOOL)enforce {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
}
%end

// ========== 10. Hippy 弹窗 ==========
%hook HippyViewController
- (void)dialogViewDisplay:(id)arg {
    // 拦截，静默处理
}
- (void)dialogViewDismiss:(id)arg {
    %orig;
}
%end
