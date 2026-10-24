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
    const char *enc = method_getTypeEncoding(m);
    NSLOG(@"[hook] %@ -%@ enc=%s", NSStringFromClass(cls), NSStringFromSelector(sel), enc);
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, newImp, enc)) return orig;
    return method_setImplementation(m, newImp);
}

/* ==================== 扫描函数（普通 C 函数，不再用 category） ==================== */
static void scanTabBarInView(UIView *v, int depth) {
    if (!v) return;
    NSString *cls = NSStringFromClass(v.class);
    if ([cls containsString:@"TabBarItemView"] ||
        [cls containsString:@"TabBarItemImageView"] ||
        [cls containsString:@"TabBarPlayerItemView"]) {
        NSString *text = describeView(v);
        NSLOG(@"[scan] %@ frame=%@ text=%@", cls, NSStringFromCGRect(v.frame), text);
        if (textLooksLikeWelfare(text)) {
            v.hidden = YES;
            v.userInteractionEnabled = NO;
            NSLOG(@"[scan] HIDDEN %@", text);
        }
    }
    for (UIView *s in v.subviews) scanTabBarInView(s, depth + 1);
}

/* ==================== Swift: TabBarItemView.layoutSubviews ==================== */
static IMP orig_TBI_layout = NULL;
static void hook_TBI_layout(id self, SEL _cmd) {
    if (orig_TBI_layout) ((void(*)(id, SEL))orig_TBI_layout)(self, _cmd);
    UIView *v = (UIView *)self;
    NSString *text = describeView(v);
    if (text.length == 0) return;
    NSLOG(@"[TBI] texts=%@ frame=%@ hidden=%d", text, NSStringFromCGRect(v.frame), v.hidden);
    if (textLooksLikeWelfare(text)) {
        if (!v.hidden) {
            v.hidden = YES;
            v.userInteractionEnabled = NO;
            NSLOG(@"[TBI] HIDDEN %@", text);
        }
    }
}

/* ==================== Swift: OnlineEarningController.initWithIsTabBarInset ==================== */
static IMP orig_OEC_init = NULL;
static id hook_OEC_init(id self, SEL _cmd, BOOL arg0) {
    NSLOG(@"[OEC] init insets=%d", arg0);
    if (orig_OEC_init) return ((id(*)(id, SEL, BOOL))orig_OEC_init)(self, _cmd, arg0);
    return nil;
}

/* ==================== Swift: AppMainController.viewDidLoad ==================== */
static IMP orig_AMC_vdl = NULL;
static void hook_AMC_vdl(id self, SEL _cmd) {
    if (orig_AMC_vdl) ((void(*)(id, SEL))orig_AMC_vdl)(self, _cmd);
    NSLOG(@"[AppMain] viewDidLoad");
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        id strongSelf = weakSelf;
        if (!strongSelf) return;
        UIView *root = [(UIViewController *)strongSelf view];
        scanTabBarInView(root, 0);
    });
}

static BOOL g_installed = NO;
static void InstallSwiftHooks(void) {
    if (g_installed) return;
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    Class oec = NSClassFromString(@"lazyaudio.OnlineEarningController");
    Class amc = NSClassFromString(@"lazyaudio.AppMainController");
    if (!tbi || !oec || !amc) {
        NSLOG(@"[hook] class missing tbi=%d oec=%d amc=%d", !!tbi, !!oec, !!amc);
        return;
    }
    orig_TBI_layout = install_hook(tbi, @selector(layoutSubviews), (IMP)hook_TBI_layout);
    orig_OEC_init   = install_hook(oec, @selector(initWithIsTabBarInset:), (IMP)hook_OEC_init);
    orig_AMC_vdl    = install_hook(amc, @selector(viewDidLoad), (IMP)hook_AMC_vdl);
    g_installed = YES;
    NSLOG(@"[hook] ALL installed");
}

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== LazyAudioNoSplash loaded pid=%d ===", getpid());
    InstallSwiftHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallSwiftHooks();
    });
}

/* ==================== OC 类：打 tab 数据源日志 ==================== */
%hook LMPageTabBarControllerChildVM
- (id)segmentName {
    id r = %orig;
    NSLOG(@"[ChildVM] segmentName=%@", r);
    return r;
}
- (Class)viewControllerClass {
    Class c = %orig;
    if (c) NSLOG(@"[ChildVM] vcClass=%s", class_getName(c));
    return c;
}
%end

%hook LMPageTabBarControllerModel
- (id)viewModels {
    id r = %orig;
    if ([r isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)r;
        NSMutableArray *names = [NSMutableArray array];
        for (id item in arr) {
            if ([item respondsToSelector:@selector(segmentName)]) {
                id n = [item performSelector:@selector(segmentName)];
                if (n) [names addObject:n];
            }
        }
        NSLOG(@"[Model] viewModels count=%lu names=%@", (unsigned long)arr.count, [names componentsJoinedByString:@"|"]);
    }
    return r;
}
%end

%hook LMPageTabBarController
- (long long)numberOfItemsIn:(id)arg0 {
    long long n = %orig;
    NSLOG(@"[PTBC] numberOfItemsIn=%lld", n);
    return n;
}
%end

/* ==================== 开屏 hook（保留） ==================== */
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
