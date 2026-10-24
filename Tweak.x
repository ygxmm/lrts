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

static UIView *FindViewByClassName(UIView *root, NSString *className) {
    if (!root) return nil;
    if ([NSStringFromClass(root.class) containsString:className]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = FindViewByClassName(sub, className);
        if (found) return found;
    }
    return nil;
}

static IMP install_hook(Class cls, SEL sel, IMP newImp) {
    if (!cls) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        NSLOG(@"[hook] method %@ NOT found on %@", NSStringFromSelector(sel), NSStringFromClass(cls));
        return NULL;
    }
    // 如果方法来自父类，先用 class_addMethod 覆盖到自己身上
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) {
        return method_getImplementation(m);
    }
    return method_setImplementation(m, newImp);
}

/* ===== Swift 类 runtime hook ===== */

static IMP orig_TBI_setAccLabel_imp = NULL;
static void hook_TBI_setAccLabel(id self, SEL _cmd, id arg0) {
    if (orig_TBI_setAccLabel_imp) ((void(*)(id, SEL, id))orig_TBI_setAccLabel_imp)(self, _cmd, arg0);
    if (arg0) NSLOG(@"[tab-item] setAccessibilityLabel: %@ frame=%@", arg0, NSStringFromCGRect([(UIView*)self frame]));
}

static IMP orig_OEC_init_imp = NULL;
static id hook_OEC_init(id self, SEL _cmd, BOOL arg0) {
    NSLOG(@"[OnlineEarning] initWithIsTabBarInset: %d", arg0);
    if (orig_OEC_init_imp) return ((id(*)(id, SEL, BOOL))orig_OEC_init_imp)(self, _cmd, arg0);
    return nil;
}

static IMP orig_AMC_viewDidLoad_imp = NULL;
static void hook_AMC_viewDidLoad(id self, SEL _cmd) {
    if (orig_AMC_viewDidLoad_imp) ((void(*)(id, SEL))orig_AMC_viewDidLoad_imp)(self, _cmd);
    NSLOG(@"[AppMain] viewDidLoad");
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        id strongSelf = weakSelf;
        if (!strongSelf) return;
        UIView *v = [(UIViewController*)strongSelf view];
        UIView *tabBarView = FindViewByClassName(v, @"TabBarView");
        NSLOG(@"[AppMain] TabBarView = %@", tabBarView);
        if (!tabBarView) return;
        for (UIView *sub in tabBarView.subviews) {
            if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"]) {
                NSString *label = sub.accessibilityLabel;
                NSLOG(@"[tab-item] label=%@ frame=%@", label, NSStringFromCGRect(sub.frame));
                if (label && ([label containsString:@"福利"] || [label containsString:@"赚钱"] || [label containsString:@"免费"] || [label containsString:@"金币"] || [label containsString:@"权益"])) {
                    NSLOG(@"[tab-item] 隐藏: %@", label);
                    sub.hidden = YES;
                }
            }
        }
    });
}

static BOOL g_TBI_installed = NO;
static BOOL g_OEC_installed = NO;
static BOOL g_AMC_installed = NO;

static void InstallSwiftHooks(void) {
    if (!g_TBI_installed) {
        Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
        if (tbi) {
            orig_TBI_setAccLabel_imp = install_hook(tbi, @selector(setAccessibilityLabel:), (IMP)hook_TBI_setAccLabel);
            g_TBI_installed = YES;
            NSLOG(@"[hook] TabBarItemView installed orig=%p", orig_TBI_setAccLabel_imp);
        }
    }
    if (!g_OEC_installed) {
        Class oec = NSClassFromString(@"lazyaudio.OnlineEarningController");
        if (oec) {
            orig_OEC_init_imp = install_hook(oec, @selector(initWithIsTabBarInset:), (IMP)hook_OEC_init);
            g_OEC_installed = YES;
            NSLOG(@"[hook] OnlineEarningController installed orig=%p", orig_OEC_init_imp);
        }
    }
    if (!g_AMC_installed) {
        Class amc = NSClassFromString(@"lazyaudio.AppMainController");
        if (amc) {
            orig_AMC_viewDidLoad_imp = install_hook(amc, @selector(viewDidLoad), (IMP)hook_AMC_viewDidLoad);
            g_AMC_installed = YES;
            NSLOG(@"[hook] AppMainController installed orig=%p", orig_AMC_viewDidLoad_imp);
        }
    }
}

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== LazyAudioNoSplash loaded pid=%d ===", getpid());
    InstallSwiftHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallSwiftHooks();
    });
}

/* ===== 开屏 hook（保留成功那版，都是纯 OC 类，不触发 Swift 警告） ===== */
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
