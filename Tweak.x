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

/* 唯一的修正：view 层隐藏 + 重排 */
static void relayoutView(UIView *tabBarView) {
    if (!tabBarView) return;
    BOOL hid = NO;
    for (UIView *sub in tabBarView.subviews) {
        if (!isTabBarItem(sub)) continue;
        if (textLooksLikeWelfare(describeView(sub))) {
            sub.hidden = YES;
            sub.alpha = 0;
            sub.userInteractionEnabled = NO;
            sub.transform = CGAffineTransformMakeTranslation(-5000, 0);
            hid = YES;
        }
    }
    if (!hid) return;

    NSMutableArray<UIView *> *vis = [NSMutableArray array];
    for (UIView *s in tabBarView.subviews) {
        if (isTabBarItem(s) && !s.hidden) [vis addObject:s];
    }
    NSUInteger N = vis.count;
    if (N < 2) return;

    CGFloat viewW = tabBarView.bounds.size.width > 0 ? tabBarView.bounds.size.width : 393.0;
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

/* hook updateNormalTabBarHandler：打印 items 结构 + 在 %orig 后重排 */
static IMP orig_update = NULL;
static void hook_update(id self, SEL _cmd) {
    DBG(@"[update] ENTER");
    id items = nil;
    @try {
        items = [self valueForKey:@"items"];
    } @catch (NSException *e) {
        DBG(@"[update] KVC items throw: %@", e.reason);
    }
    if ([items isKindOfClass:[NSArray class]]) {
        NSArray *arr = items;
        DBG(@"[update] items count=%lu", (unsigned long)arr.count);
        for (NSUInteger i = 0; i < arr.count && i < 10; i++) {
            id it = arr[i];
            DBG(@"[update] item[%lu] class=%@ desc=%@", (unsigned long)i, NSStringFromClass([it class]), it);
        }
    } else {
        DBG(@"[update] items=%@ class=%@", items, items ? NSStringFromClass([items class]) : @"nil");
    }

    if (orig_update) ((void(*)(id, SEL))orig_update)(self, _cmd);

    __weak UIView *w = (UIView *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *s = w;
        if (s) relayoutView(s);
    });
}

/* hook TabBarItemView.layoutSubviews 兜底（每次 item 布局也尝试重排） */
static IMP orig_tbi_layout = NULL;
static void hook_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) ((void(*)(id, SEL))orig_tbi_layout)(self, _cmd);
    UIView *v = (UIView *)self;
    UIView *p = v.superview;
    if (p && [NSStringFromClass(p.class) containsString:@"TabBarView"]) {
        relayoutView(p);
    }
}

static BOOL g_update_ok = NO, g_tbi_ok = NO;

static void InstallHooks(void) {
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    if (tbv && !g_update_ok) {
        SEL s = sel_registerName("updateNormalTabBarHandler");
        Method m = class_getInstanceMethod(tbv, s);
        DBG(@"[install] TBV.updateNormalTabBarHandler m=%p enc=%s", m, m ? method_getTypeEncoding(m) : "nil");
        if (m) {
            orig_update = method_setImplementation(m, (IMP)hook_update);
            g_update_ok = YES;
            DBG(@"[install] update hooked orig=%p", orig_update);
        }
    }
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi && !g_tbi_ok) {
        SEL s = @selector(layoutSubviews);
        Method m = class_getInstanceMethod(tbi, s);
        DBG(@"[install] TBI.layoutSubviews m=%p", m);
        if (m) {
            orig_tbi_layout = method_setImplementation(m, (IMP)hook_tbi_layout);
            g_tbi_ok = YES;
            DBG(@"[install] TBI.layoutSubviews hooked orig=%p", orig_tbi_layout);
        }
    }
}

%ctor {
    DBG(@"=== ctor pid=%d ===", getpid());
    InstallHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
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
