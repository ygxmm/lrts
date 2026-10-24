#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h>

static os_log_t gLog;

static NSString *GetLogPath(void) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = dirs.firstObject ?: NSTemporaryDirectory();
        path = [dir stringByAppendingPathComponent:@"LazyAudioNoSplash.log"];
    });
    return path;
}

static void NSLOG(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (gLog) os_log(gLog, "%{public}@", s);
    NSString *path = GetLogPath();
    if (path) {
        FILE *f = fopen(path.UTF8String, "a");
        if (f) {
            NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
            fputs(line.UTF8String, f);
            fclose(f);
        }
    }
}

static void collectTexts(UIView *v, NSMutableSet<NSString *> *out) {
    if (!v) return;
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel *)v;
        if (l.text.length) [out addObject:l.text];
    }
    for (UIView *s in v.subviews) collectTexts(s, out);
}

static NSString *describeView(UIView *v) {
    NSMutableSet *texts = [NSMutableSet set];
    collectTexts(v, texts);
    return [texts.allObjects componentsJoinedByString:@"|"];
}

static BOOL textLooksLikeWelfare(NSString *text) {
    if (text.length == 0) return NO;
    return [text containsString:@"福利"] || [text containsString:@"赚钱"] ||
           [text containsString:@"金币"] || [text containsString:@"免费"] ||
           [text containsString:@"权益"] || [text containsString:@"红包"] ||
           [text containsString:@"奖励"] || [text containsString:@"提现"];
}

static IMP install_hook(Class cls, SEL sel, IMP newImp) {
    if (!cls) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) return orig;
    return method_setImplementation(m, newImp);
}

static BOOL isTabBarItem(UIView *v) {
    return [NSStringFromClass(v.class) containsString:@"TabBarItemView"];
}

/* ============ 关键：hook setFrame: ============ */
static IMP orig_TBI_setFrame = NULL;
static void hook_TBI_setFrame(id self, SEL _cmd, CGRect frame) {
    UIView *v = (UIView *)self;
    UIView *parent = v.superview;

    if (!parent || ![NSStringFromClass(parent.class) containsString:@"TabBarView"]) {
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
        return;
    }

    /* 1. 如果这是福利 item → 扔到屏幕外 */
    if (textLooksLikeWelfare(describeView(v))) {
        v.hidden = YES;
        v.userInteractionEnabled = NO;
        CGRect off = frame;
        off.origin.x = -1000;
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, off);
        return;
    }

    /* 2. 按 parent.subviews 里的原始顺序，找出当前可见项列表 */
    NSMutableArray<UIView *> *allItems = [NSMutableArray array];
    for (UIView *s in parent.subviews) {
        if (isTabBarItem(s)) [allItems addObject:s];
    }
    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *s in allItems) {
        if (!textLooksLikeWelfare(describeView(s))) [visible addObject:s];
    }
    NSUInteger N = visible.count;
    NSUInteger idx = [visible indexOfObjectIdenticalTo:v];
    if (idx == NSNotFound || N == 0) {
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
        return;
    }

    /* 3. 计算新位置 */
    CGFloat viewW = parent.bounds.size.width;
    if (viewW <= 0) viewW = 393.0;
    CGFloat itemW = frame.size.width;
    if (itemW <= 0) itemW = 60.0;
    CGFloat margin = 15.0;
    CGFloat spacing = (N > 1) ? (viewW - 2 * margin - N * itemW) / (N - 1) : 0;
    frame.origin.x = margin + idx * (itemW + spacing);

    if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
}

static BOOL g_installed = NO;
static void InstallHooks(void) {
    if (g_installed) return;
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (!tbi) return;
    orig_TBI_setFrame = install_hook(tbi, @selector(setFrame:), (IMP)hook_TBI_setFrame);
    if (orig_TBI_setFrame) {
        g_installed = YES;
        NSLOG(@"[hook] TBI.setFrame: installed");
    }
}

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== loaded pid=%d ===", getpid());
    InstallHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
    });
}

/* ============ 开屏 hook ============ */
%hook TMEAdOperateSplash
+ (BOOL)needShowSplashWithLaunchType:(BOOL)arg0 { return NO; }
- (BOOL)canPreLoadAMSSplash { return NO; }
%end
%hook TMEAdOperateIntervalManager
- (BOOL)canShowSplash:(BOOL)arg0 { return NO; }
%end
%hook TMEAdOperateSplashManager
- (BOOL)checkAdCanShow:(id)arg0 { return NO; }
- (BOOL)hasP0AdSplashCanShow { return NO; }
- (BOOL)hasP1AdSplashCanShow:(id)arg0 { return NO; }
%end
%hook LMLaunchAd
+ (BOOL)shouldShow:(id)arg0 { return NO; }
%end
%hook LMLaunchAdMaxShowCountBridge
+ (BOOL)shouldShow:(id)arg0 { return NO; }
%end
