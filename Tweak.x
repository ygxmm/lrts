#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

static void doRelayout(UIView *tabBarView) {
    if (!tabBarView) return;

    BOOL hasWelfare = NO;
    for (UIView *sub in tabBarView.subviews) {
        if (!isTabBarItem(sub)) continue;
        if (textLooksLikeWelfare(describeView(sub))) {
            if (!sub.hidden) {
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
                sub.transform = CGAffineTransformMakeTranslation(-3000, 0);
            }
            hasWelfare = YES;
        }
    }
    if (!hasWelfare) return;

    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *sub in tabBarView.subviews) {
        if (isTabBarItem(sub) && !sub.hidden) [visible addObject:sub];
    }
    NSUInteger N = visible.count;
    if (N == 0) return;

    CGFloat viewW = tabBarView.bounds.size.width > 0 ? tabBarView.bounds.size.width : 393.0;
    CGFloat itemW = 60.0;
    CGFloat margin = 15.0;
    CGFloat spacing = (N > 1) ? (viewW - 2 * margin - N * itemW) / (N - 1) : 0;

    for (NSUInteger i = 0; i < N; i++) {
        UIView *item = visible[i];
        item.transform = CGAffineTransformIdentity;
        CGFloat origX = item.frame.origin.x;
        CGFloat targetX = margin + i * (itemW + spacing);
        CGFloat dx = targetX - origX;
        if (fabs(dx) > 0.5) {
            item.transform = CGAffineTransformMakeTranslation(dx, 0);
        }
    }
}

/* ============ hook TabBarView.updateNormalTabBarHandler ============ */
static IMP orig_TBV_update = NULL;
static void hook_TBV_update(id self, SEL _cmd) {
    if (orig_TBV_update) ((void(*)(id, SEL))orig_TBV_update)(self, _cmd);
    __weak UIView *weakSelf = (UIView *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongSelf = weakSelf;
        if (strongSelf) doRelayout(strongSelf);
    });
}

/* ============ 定时器兜底（300ms） ============ */
static UIWindow *currentKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return nil;
}

static void timerTick(void) {
    UIWindow *window = currentKeyWindow();
    if (!window) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
    while (queue.count > 0) {
        UIView *cur = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(cur.class) containsString:@"TabBarView"]) {
            doRelayout(cur);
        }
        [queue addObjectsFromArray:cur.subviews];
    }
}

static BOOL g_installed = NO;
static void InstallHooks(void) {
    if (g_installed) return;
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    if (!tbv) return;
    orig_TBV_update = install_hook(tbv, sel_registerName("updateNormalTabBarHandler"), (IMP)hook_TBV_update);
    if (orig_TBV_update) g_installed = YES;
}

%ctor {
    InstallHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallHooks();
    });

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC, 30 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        timerTick();
    });
    dispatch_resume(timer);
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
