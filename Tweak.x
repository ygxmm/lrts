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

static void DumpClassMethods(NSString *clsName) {
    Class cls = NSClassFromString(clsName);
    if (!cls) { NSLOG(@"[dump] %@ NOT FOUND", clsName); return; }
    NSLOG(@"[dump] ===== %@ =====", clsName);
    Class cur = cls;
    int depth = 0;
    while (cur && depth < 6) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cur, &count);
        if (methods) {
            for (unsigned int i = 0; i < count; i++) {
                NSLOG(@"[dump]   %s%s", class_isMetaClass(cur) ? "+" : "-", sel_getName(method_getName(methods[i])));
            }
            free(methods);
        }
        cur = class_getSuperclass(cur);
        depth++;
    }
}

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== LazyAudioNoSplash loaded pid=%d home=%@ ===", getpid(), NSHomeDirectory());
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSLOG(@"[dump] ==== 开始 dump TabBar 相关类 ====");
        DumpClassMethods(@"lazyaudio.LMTabBar");
        DumpClassMethods(@"lazyaudio.TabBarView");
        DumpClassMethods(@"lazyaudio.TabBarItemView");
        DumpClassMethods(@"lazyaudio.TabBarItemImageView");
        DumpClassMethods(@"lazyaudio.OnlineEarningController");
        DumpClassMethods(@"lazyaudio.AppMainController");
        NSLOG(@"[dump] ==== dump 结束 ====");
    });
}

/* ===== 开屏 hook（保留成功的那一版） ===== */
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
