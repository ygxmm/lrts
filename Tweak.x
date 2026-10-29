#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <stdarg.h>
#import <string.h>
#import <objc/message.h>

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
@interface AudioPlayerBridge : NSObject
+ (void)loadPlayerButNotAutoPlay;
@end

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

// ========== 沙盒日志 ==========
static void LALog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSArray<NSString *> *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = docs.firstObject;
    if (!dir.length) return;

    NSString *path = [dir stringByAppendingPathComponent:@"lazyaudio-tweak.log"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        @try {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        } @catch (NSException *e) {}
    }
}

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

// ========== 预加载方法封装 ==========
static void LADoPreload(const char *source) {
    Class bridgeClass = objc_getClass("AudioPlayerBridge");
    if (bridgeClass) {
        SEL sel = NSSelectorFromString(@"loadPlayerButNotAutoPlay");
        if ([bridgeClass respondsToSelector:sel]) {
            ((void (*)(id, SEL))objc_msgSend)(bridgeClass, sel);
            LALog(@"[LA-T] 预加载触发 (%s)", source);
        }
    }
}

__attribute__((constructor)) static void LAInit(void) {
    LALog(@"tweak loaded (v11 fix-tap)");
    
    // 启动时即刻向主线程发送预加载请求
    dispatch_async(dispatch_get_main_queue(), ^{
        LADoPreload("Launch");
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
            LADoPreload("viewDidLoad");
        });
    }
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    if ([cls isEqualToString:@"lazyaudio.AppMainController"]) {
        // 回到首页时再刷新一次数据
        dispatch_async(dispatch_get_main_queue(), ^{
            LADoPreload("viewDidAppear");
        });
    }
}
%end

// ========== 2. 底栏重排 ==========
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
            if (sub.userInteractionEnabled) sub.userInteractionEnabled = NO; // 修复了这里的笔误
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

// ========== 3. TabBarItemView 兜底 ==========
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

// ========== 4. 签到按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    if (!self.hidden) self.hidden = YES;
    if (self.alpha != 0.0) self.alpha = 0.0;
    if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
}
%end

// ========== 5. 开屏 Window ==========
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

// ========== 6. 赚钱悬浮球 / 提示 / 任务入口 ==========
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

// ========== 7. Hippy 弹窗 ==========
%hook HippyViewController
- (void)dialogViewDisplay:(id)arg {
    LALog(@"[LA-T] Hippy dialogViewDisplay intercepted, pageName=%@", [self pageName]);
}
- (void)dialogViewDismiss:(id)arg {
    %orig;
}
%end
