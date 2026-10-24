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

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== LazyAudioNoSplash loaded pid=%d home=%@ ===", getpid(), NSHomeDirectory());
}

/* ---------- 第一层：TMEAdOperateSplash 总开关/预加载 ---------- */
%hook TMEAdOperateSplash

+ (BOOL)needShowSplashWithLaunchType:(BOOL)arg0 {
    NSLOG(@"[TMEAdOperateSplash +needShowSplashWithLaunchType:%d] -> NO", arg0);
    return NO;
}

- (BOOL)canPreLoadAMSSplash {
    NSLOG(@"[TMEAdOperateSplash canPreLoadAMSSplash] -> NO");
    return NO;
}

/* 执行方法：只打日志，不改返回值 */
- (void)loadAdAndShowSplashWithCustomUIModel:(id)arg0 {
    NSLOG(@"[TMEAdOperateSplash loadAdAndShowSplashWithCustomUIModel:] (执行方法，不拦)");
    %orig;
}
- (void)loadAdAndShowSplashWithCustomUIModel:(id)arg0 inContainerView:(id)arg1 {
    NSLOG(@"[TMEAdOperateSplash loadAdAndShowSplashWithCustomUIModel:inContainerView:] (执行方法，不拦)");
    %orig;
}

%end

/* ---------- 第二层：TMEAdOperateIntervalManager 间隔控制 ---------- */
%hook TMEAdOperateIntervalManager

- (BOOL)canShowSplash:(BOOL)arg0 {
    NSLOG(@"[TMEAdOperateIntervalManager canShowSplash:%d] -> NO", arg0);
    return NO;
}

%end

/* ---------- 第三层：TMEAdOperateSplashManager 管理器判断 ---------- */
%hook TMEAdOperateSplashManager

- (BOOL)checkAdCanShow:(id)arg0 {
    NSLOG(@"[TMEAdOperateSplashManager checkAdCanShow:] arg=%@ -> NO", arg0);
    return NO;
}
- (BOOL)hasP0AdSplashCanShow {
    NSLOG(@"[TMEAdOperateSplashManager hasP0AdSplashCanShow] -> NO");
    return NO;
}
- (BOOL)hasP1AdSplashCanShow:(id)arg0 {
    NSLOG(@"[TMEAdOperateSplashManager hasP1AdSplashCanShow:] arg=%@ -> NO", arg0);
    return NO;
}

/* 执行方法：只打日志，看最终是不是从这里真的展示 */
- (BOOL)showSplashWithOrder:(id)arg0 withCustomUI:(id)arg1 inContainerView:(id)arg2 {
    BOOL r = %orig;
    NSLOG(@"[TMEAdOperateSplashManager showSplashWithOrder:...] result=%d (执行方法，不拦)", r);
    return r;
}

%end

/* ---------- 第四层：本地 launchAd 数据模型（保留，无害） ---------- */
%hook LMLaunchAd
+ (BOOL)shouldShow:(id)arg0 {
    NSLOG(@"[LMLaunchAd shouldShow:] arg=%@ -> NO", arg0);
    return NO;
}
%end

%hook LMLaunchAdMaxShowCountBridge
+ (BOOL)shouldShow:(id)arg0 {
    NSLOG(@"[LMLaunchAdMaxShowCountBridge shouldShow:] arg=%@ -> NO", arg0);
    return NO;
}
%end
