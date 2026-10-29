#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface _TtC9lazyaudio14TabBarItemView : UIView
@end
@interface _TtC9lazyaudio12MeSignButton : UIView
@end
@interface _TtC9lazyaudio18LaunchSplashWindow : UIWindow
@end
@interface _TtC13Advertisement14SplashAdWindow : UIWindow
@end
@interface _TtC9lazyaudio25OnlineEarningNewLevitator : UIView
@end
@interface _TtC9lazyaudio24OnlineEarningNewTipsView : UIView
@end
@interface _TtC9lazyaudio19EarningTaskBallView : UIView
@end
@interface _TtC9lazyaudio20EarningTaskEntryView : UIView
@end
@interface _TtC9lazyaudio25OnlineEarningNewEntryView : UIView
@end
@interface HippyViewController : UIViewController
- (void)dialogViewDisplay:(id)arg;
- (void)dialogViewDismiss:(id)arg;
- (NSString *)pageName;
@end

// 日志用类（只 hook 不干预）
@interface _TtC9lazyaudio16MiniPlayContainer : UIView
@end
@interface _TtC9lazyaudio15MiniBarPlayView : UIView
- (void)updateStatus;
@end
@interface AudioPlayerBridge : NSObject
+ (void)playWithBookId:(long long)a0 entityIndex:(long long)a1 autoSeek:(double)a2 listType:(long long)a3 autoPlay:(BOOL)a4;
+ (void)loadPlayerButNotAutoPlay;
@end

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

static double gLATweakStart = 0;

static void LATimeLog(const char *tag) {
    double now = CACurrentMediaTime();
    NSLog(@"[LA-T] %s  %.3f  (since start %.3f)", tag, now, now - gLATweakStart);
}

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

__attribute__((constructor)) static void LAInit(void) {
    gLATweakStart = CACurrentMediaTime();
    NSLog(@"[LazyAudio] tweak loaded (v6 timing)");
}

// ========== 1. 底栏重排 ==========
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

// ========== 2. TabBarItemView 兜底 ==========
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

// ========== 3. 签到按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    if (!self.hidden) self.hidden = YES;
    if (self.alpha != 0.0) self.alpha = 0.0;
    if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
}
%end

// ========== 4. 开屏 Window ==========
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

// ========== 5. 赚钱悬浮球 / 提示 / 任务入口 ==========
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

// ========== 6. Hippy 弹窗 ==========
%hook HippyViewController
- (void)dialogViewDisplay:(id)arg {
    NSLog(@"[LA-T] Hippy dialogViewDisplay intercepted, pageName=%@", [self pageName]);
}
- (void)dialogViewDismiss:(id)arg {
    %orig;
}
%end

// ========== 7. 播放链路时间戳（只打日志，不改行为） ==========
%hook AudioPlayerBridge
+ (void)playWithBookId:(long long)a0 entityIndex:(long long)a1 autoSeek:(double)a2 listType:(long long)a3 autoPlay:(BOOL)a4 {
    LATimeLog("AudioPlayerBridge.playWithBookId BEGIN");
    %orig;
    LATimeLog("AudioPlayerBridge.playWithBookId END");
}
+ (void)loadPlayerButNotAutoPlay {
    LATimeLog("AudioPlayerBridge.loadPlayerButNotAutoPlay BEGIN");
    %orig;
    LATimeLog("AudioPlayerBridge.loadPlayerButNotAutoPlay END");
}
%end

%hook _TtC9lazyaudio16MiniPlayContainer
- (void)didMoveToWindow {
    %orig;
    LATimeLog("MiniPlayContainer.didMoveToWindow");
}
%end

%hook _TtC9lazyaudio15MiniBarPlayView
- (void)updateStatus {
    %orig;
    LATimeLog("MiniBarPlayView.updateStatus");
}
%end
