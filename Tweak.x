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
%end
