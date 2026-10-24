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
    NSLog(@"[NoSplash] %@", s);
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
    if (!m) {
        NSLOG(@"[hook] %@ -%@ NOT found", NSStringFromClass(cls), NSStringFromSelector(sel));
        return NULL;
    }
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) return orig;
    return method_setImplementation(m, newImp);
}

/* ============ 关键：重排剩余可见 tab ============ */
static void relayoutVisibleTabItems(UIView *tabBarView) {
    if (!tabBarView) return;
    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *sub in tabBarView.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && !sub.hidden) {
            [visible addObject:sub];
        }
    }
    NSUInteger N = visible.count;
    if (N == 0) return;
    CGFloat viewW = tabBarView.bounds.size.width;
    CGFloat itemW = 60;
    CGFloat margin = 15;
    CGFloat spacing = (N > 1) ? (viewW - 2 * margin - N * itemW) / (N - 1) : 0;
    for (NSUInteger i = 0; i < N; i++) {
        UIView *item = visible[i];
        CGRect f = item.frame;
        f.origin.x = margin + i * (itemW + spacing);
        item.frame = f;
    }
    NSLOG(@"[relayout] N=%lu spacing=%.2f viewW=%.1f", (unsigned long)N, spacing, viewW);
}

/* ============ Swift: TabBarItemView.layoutSubviews ============ */
static IMP orig_TBI_layout = NULL;
static NSMutableSet<NSString *> *g_hiddenTabTexts = nil;
static void hook_TBI_layout(id self, SEL _cmd) {
    if (orig_TBI_layout) ((void(*)(id, SEL))orig_TBI_layout)(self, _cmd);
    UIView *v = (UIView *)self;
    NSString *text = describeView(v);
    if (text.length == 0) return;

    if (!g_hiddenTabTexts) g_hiddenTabTexts = [NSMutableSet set];

    if (textLooksLikeWelfare(text)) {
        if (!v.hidden) {
            v.hidden = YES;
            v.userInteractionEnabled = NO;
            [g_hiddenTabTexts addObject:text];
            NSLOG(@"[TBI] HIDDEN %@", text);
            UIView *parent = v.superview;
            dispatch_async(dispatch_get_main_queue(), ^{
                relayoutVisibleTabItems(parent);
            });
        }
        return;
    }
    /* 如果父 view 重排过、且我们之前隐藏过福利，就重新重排一遍（防止 Swift 二次 layout 覆盖） */
    if (g_hiddenTabTexts.count > 0) {
        UIView *parent = v.superview;
        dispatch_async(dispatch_get_main_queue(), ^{
            relayoutVisibleTabItems(parent);
        });
    }
}

/* ============ Swift: AppMainController.viewDidLoad ============ */
static IMP orig_AMC_vdl = NULL;
static void hook_AMC_vdl(id self, SEL _cmd) {
    if (orig_AMC_vdl) ((void(*)(id, SEL))orig_AMC_vdl)(self, _cmd);
    NSLOG(@"[AppMain] viewDidLoad");
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        id strongSelf = weakSelf;
        if (!strongSelf) return;
        UIView *root = [(UIViewController *)strongSelf view];
        /* 找到 TabBarView 后主动重排一次 */
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
        while (queue.count > 0) {
            UIView *cur = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([NSStringFromClass(cur.class) containsString:@"TabBarView"]) {
                relayoutVisibleTabItems(cur);
            }
            [queue addObjectsFromArray:cur.subviews];
        }
    });
}

static BOOL g_installed = NO;
static void InstallSwiftHooks(void) {
    if (g_installed) return;
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    Class amc = NSClassFromString(@"lazyaudio.AppMainController");
    if (!tbi || !amc) { NSLOG(@"[hook] missing"); return; }
    orig_TBI_layout = install_hook(tbi, @selector(layoutSubviews), (IMP)hook_TBI_layout);
    orig_AMC_vdl    = install_hook(amc, @selector(viewDidLoad), (IMP)hook_AMC_vdl);
    g_installed = YES;
    NSLOG(@"[hook] installed");
}

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== loaded pid=%d ===", getpid());
    InstallSwiftHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallSwiftHooks();
    });
}

/* ============ 开屏 hook（保留） ============ */
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
