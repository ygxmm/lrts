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

%ctor {
    gLog = os_log_create("com.tzyhb.lazyaudio-nosplash", "tweak");
    NSLOG(@"=== LazyAudioNoSplash loaded pid=%d home=%@ ===", getpid(), NSHomeDirectory());
}

/* ---------- 开屏 hook（保留成功那版） ---------- */
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

/* ---------- 福利 tab：探测 + 尝试隐藏 ---------- */
%hook lazyaudio.TabBarItemView
- (void)setAccessibilityLabel:(id)arg0 {
    %orig;
    if (arg0) {
        NSLOG(@"[tab-item] setAccessibilityLabel: %@ frame=%@", arg0, NSStringFromCGRect(self.frame));
    }
}
%end

%hook lazyaudio.OnlineEarningController
- (id)initWithIsTabBarInset:(BOOL)arg0 {
    NSLOG(@"[OnlineEarning] initWithIsTabBarInset: %d", arg0);
    return %orig;
}
%end

%hook lazyaudio.AppMainController
- (void)viewDidLoad {
    %orig;
    NSLOG(@"[AppMain] viewDidLoad");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIView *tabBarView = FindViewByClassName(self.view, @"TabBarView");
        NSLOG(@"[AppMain] TabBarView = %@", tabBarView);
        if (!tabBarView) return;
        NSMutableArray *items = [NSMutableArray array];
        for (UIView *sub in tabBarView.subviews) {
            if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"]) {
                [items addObject:sub];
            }
        }
        NSLOG(@"[AppMain] found %lu TabBarItemView", (unsigned long)items.count);
        for (UIView *sub in items) {
            NSString *label = sub.accessibilityLabel;
            NSString *value = sub.accessibilityValue;
            NSLOG(@"[tab-item] label=%@ value=%@ frame=%@", label, value, NSStringFromCGRect(sub.frame));
            BOOL isWelfare = NO;
            if (label) {
                if ([label containsString:@"福利"] ||
                    [label containsString:@"赚钱"] ||
                    [label containsString:@"免费"] ||
                    [label containsString:@"金币"] ||
                    [label containsString:@"权益"]) {
                    isWelfare = YES;
                }
            }
            if (isWelfare) {
                NSLOG(@"[tab-item] 隐藏福利 tab: %@", label);
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
            }
        }
    });
}
%end
