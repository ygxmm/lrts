#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void DBG(NSString *fmt, ...) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = dirs.firstObject ?: NSTemporaryDirectory();
        path = [dir stringByAppendingPathComponent:@"LazyAudioNoSplash.log"];
    });
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(path.UTF8String, "a");
    if (!f) return;
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
    fputs(line.UTF8String, f);
    fclose(f);
}

static IMP install_hook(Class cls, SEL sel, IMP newImp, const char *name) {
    if (!cls) { DBG(@"[hook] %s class=NULL", name); return NULL; }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { DBG(@"[hook] %s method=NULL", name); return NULL; }
    IMP orig = method_setImplementation(m, newImp);
    DBG(@"[hook] %s OK orig=%p", name, orig);
    return orig;
}

static void collectTexts(UIView *v, NSMutableSet<NSString *> *out) {
    if (!v) return;
    if ([v isKindOfClass:[UILabel class]]) {
        UILabel *l = (UILabel *)v;
        if (l.text.length) [out addObject:l.text];
    }
    for (UIView *s in v.subviews) collectTexts(s, out);
}

static BOOL itemIsWelfare(UIView *v) {
    if (!v) return NO;
    NSString *label = v.accessibilityLabel;
    if (label.length && ([label containsString:@"福利"] || [label containsString:@"赚钱"] || [label containsString:@"金币"] || [label containsString:@"免费"])) return YES;
    NSMutableSet *texts = [NSMutableSet set];
    collectTexts(v, texts);
    for (NSString *s in texts) {
        if ([s containsString:@"福利"] || [s containsString:@"赚钱"] || [s containsString:@"金币"] || [s containsString:@"免费"]) return YES;
    }
    return NO;
}

static BOOL isTabItem(UIView *v) { return [NSStringFromClass(v.class) containsString:@"TabBarItemView"]; }
static BOOL isTabView(UIView *v) { return [NSStringFromClass(v.class) containsString:@"TabBarView"]; }

static void relayout(UIView *tbv) {
    if (!tbv) return;
    BOOL hid = NO;
    for (UIView *s in tbv.subviews) {
        if (!isTabItem(s)) continue;
        if (itemIsWelfare(s)) {
            s.hidden = YES;
            s.userInteractionEnabled = NO;
            s.transform = CGAffineTransformMakeTranslation(-5000, 0);
            hid = YES;
        }
    }
    if (!hid) return;
    NSMutableArray *vis = [NSMutableArray array];
    for (UIView *s in tbv.subviews) if (isTabItem(s) && !s.hidden) [vis addObject:s];
    NSUInteger N = vis.count;
    if (N < 2) return;
    CGFloat viewW = tbv.bounds.size.width > 0 ? tbv.bounds.size.width : 393.0;
    CGFloat itemW = 60.0, margin = 15.0;
    CGFloat spacing = (viewW - 2 * margin - N * itemW) / (N - 1);
    if (spacing < 0) spacing = 0;
    for (NSUInteger i = 0; i < N; i++) {
        UIView *item = vis[i];
        item.transform = CGAffineTransformIdentity;
        CGRect f = item.frame;
        f.origin.x = margin + i * (itemW + spacing);
        item.frame = f;
    }
    DBG(@"[relayout] N=%lu", (unsigned long)N);
}

static IMP orig_update = NULL;
static void hook_update(id self, SEL _cmd) {
    DBG(@"[update] ENTER");
    if (orig_update) ((void(*)(id, SEL))orig_update)(self, _cmd);
    relayout((UIView *)self);
}

static IMP orig_setLabel = NULL;
static void hook_setLabel(id self, SEL _cmd, id label) {
    DBG(@"[setLabel] %@", label);
    if (orig_setLabel) ((void(*)(id, SEL, id))orig_setLabel)(self, _cmd, label);
    UIView *v = (UIView *)self;
    if (itemIsWelfare(v) && v.superview && isTabView(v.superview)) {
        v.hidden = YES;
        v.userInteractionEnabled = NO;
        relayout(v.superview);
    }
}

static IMP orig_setFrame = NULL;
static void hook_setFrame(id self, SEL _cmd, CGRect frame) {
    UIView *v = (UIView *)self;
    if (v.superview && isTabView(v.superview) && itemIsWelfare(v)) {
        v.hidden = YES;
        frame.origin.x = -5000;
    }
    if (orig_setFrame) ((void(*)(id, SEL, CGRect))orig_setFrame)(self, _cmd, frame);
}

%ctor {
    DBG(@"=== ctor pid=%d ===", getpid());
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    DBG(@"[class] tbv=%p tbi=%p", tbv, tbi);
    orig_update = install_hook(tbv, sel_registerName("updateNormalTabBarHandler"), (IMP)hook_update, "TBV.updateNormalTabBarHandler");
    orig_setLabel = install_hook(tbi, @selector(setAccessibilityLabel:), (IMP)hook_setLabel, "TBI.setAccessibilityLabel:");
    orig_setFrame = install_hook(tbi, @selector(setFrame:), (IMP)hook_setFrame, "TBI.setFrame:");
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
