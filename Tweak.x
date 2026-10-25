#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void DBG(NSString *fmt, ...) {
    FILE *f = fopen("/var/mobile/Library/Preferences/com.tzyhb.dbg", "a");
    if (!f) return;
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    fputs([s UTF8String], f);
    fputc('\n', f);
    fclose(f);
}

static IMP install_hook(Class cls, SEL sel, IMP newImp) {
    if (!cls) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) return orig;
    return method_setImplementation(m, newImp);
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
           [text containsString:@"金币"] || [text containsString:@"免费"];
}

static BOOL isTabBarItem(UIView *v) {
    return [NSStringFromClass(v.class) containsString:@"TabBarItemView"];
}

static IMP orig_TBI_setFrame = NULL;
static int g_call = 0;

static void hook_TBI_setFrame(id self, SEL _cmd, CGRect frame) {
    UIView *v = (UIView *)self;
    UIView *parent = v.superview;
    g_call++;

    if (g_call <= 15) {
        DBG(@"[setFrame] #%d cls=%s parent=%s frame=(%.1f,%.1f,%.1f,%.1f)",
            g_call, class_getName([v class]),
            parent ? class_getName([parent class]) : "nil",
            frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    }

    if (!parent || ![NSStringFromClass(parent.class) containsString:@"TabBarView"]) {
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
        return;
    }

    if (textLooksLikeWelfare(describeView(v))) {
        DBG(@"[setFrame] WELFARE HIT -> x=-2000");
        v.hidden = YES;
        v.userInteractionEnabled = NO;
        frame.origin.x = -2000;
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
        return;
    }

    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *s in parent.subviews) {
        if (!isTabBarItem(s)) continue;
        if (!textLooksLikeWelfare(describeView(s))) [visible addObject:s];
    }
    NSUInteger N = visible.count;
    NSUInteger idx = [visible indexOfObjectIdenticalTo:v];
    if (idx == NSNotFound || N == 0) {
        if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
        return;
    }
    CGFloat viewW = parent.bounds.size.width > 0 ? parent.bounds.size.width : 393.0;
    CGFloat itemW = frame.size.width > 0 ? frame.size.width : 60.0;
    CGFloat margin = 15.0;
    CGFloat spacing = (N > 1) ? (viewW - 2 * margin - N * itemW) / (N - 1) : 0;
    frame.origin.x = margin + idx * (itemW + spacing);

    if (orig_TBI_setFrame) ((void(*)(id, SEL, CGRect))orig_TBI_setFrame)(self, _cmd, frame);
}

static BOOL g_installed = NO;

static void InstallTabBarHooks(void) {
    if (g_installed) return;
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    DBG(@"[install] tbi=%p", tbi);
    if (!tbi) return;
    Method m = class_getInstanceMethod(tbi, @selector(setFrame:));
    DBG(@"[install] setFrame m=%p enc=%s", m, m ? method_getTypeEncoding(m) : "nil");
    orig_TBI_setFrame = install_hook(tbi, @selector(setFrame:), (IMP)hook_TBI_setFrame);
    DBG(@"[install] orig=%p", orig_TBI_setFrame);
    if (orig_TBI_setFrame) g_installed = YES;
}

%ctor {
    DBG(@"=== ctor loaded pid=%d ===", getpid());
    InstallTabBarHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallTabBarHooks();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallTabBarHooks();
    });
}

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
