#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP replaceMethod(Class cls, SEL sel, IMP newImp) {
    if (!cls) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
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

static BOOL itemIsWelfare(UIView *v) {
    if (!v) return NO;
    NSString *label = v.accessibilityLabel;
    if (label.length) {
        if ([label containsString:@"福利"] || [label containsString:@"赚钱"] ||
            [label containsString:@"金币"] || [label containsString:@"免费"]) return YES;
    }
    NSMutableSet *texts = [NSMutableSet set];
    collectTexts(v, texts);
    for (NSString *s in texts) {
        if ([s containsString:@"福利"] || [s containsString:@"赚钱"] ||
            [s containsString:@"金币"] || [s containsString:@"免费"]) return YES;
    }
    return NO;
}

static BOOL isTabBarItem(UIView *v) {
    return [NSStringFromClass(v.class) containsString:@"TabBarItemView"];
}

static BOOL isTabBarView(UIView *v) {
    return [NSStringFromClass(v.class) containsString:@"TabBarView"];
}

static void relayoutTabBar(UIView *tabBarView) {
    if (!tabBarView) return;

    BOOL hid = NO;
    for (UIView *sub in tabBarView.subviews) {
        if (!isTabBarItem(sub)) continue;
        if (itemIsWelfare(sub)) {
            if (!sub.hidden) {
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
                hid = YES;
            }
        }
    }
    if (!hid) return;

    NSMutableArray<UIView *> *vis = [NSMutableArray array];
    for (UIView *s in tabBarView.subviews) {
        if (isTabBarItem(s) && !s.hidden) [vis addObject:s];
    }
    NSUInteger N = vis.count;
    if (N < 2) return;

    CGFloat viewW = tabBarView.bounds.size.width;
    if (viewW <= 0) return;
    CGFloat itemW = 60.0, margin = 15.0;
    CGFloat spacing = (viewW - 2 * margin - N * itemW) / (N - 1);
    if (spacing < 0) spacing = 0;
    for (NSUInteger i = 0; i < N; i++) {
        UIView *item = vis[i];
        CGRect f = item.frame;
        f.origin.x = margin + i * (itemW + spacing);
        item.frame = f;
    }
}

/* ============ hook 1: TabBarView.updateNormalTabBarHandler ============ */
static IMP orig_update = NULL;
static void my_update(id self, SEL _cmd) {
    if (orig_update) ((void(*)(id, SEL))orig_update)(self, _cmd);
    relayoutTabBar((UIView *)self);
}

/* ============ hook 2: TabBarItemView.setAccessibilityLabel: ============ */
static IMP orig_setLabel = NULL;
static void my_setLabel(id self, SEL _cmd, id label) {
    if (orig_setLabel) ((void(*)(id, SEL, id))orig_setLabel)(self, _cmd, label);
    UIView *v = (UIView *)self;
    if (!itemIsWelfare(v)) return;
    v.hidden = YES;
    v.userInteractionEnabled = NO;
    UIView *parent = v.superview;
    if (parent && isTabBarView(parent)) {
        relayoutTabBar(parent);
    }
}

/* ============ hook 3: TabBarItemView.setFrame: ============ */
static IMP orig_setFrame = NULL;
static void my_setFrame(id self, SEL _cmd, CGRect frame) {
    UIView *v = (UIView *)self;
    UIView *parent = v.superview;
    if (parent && isTabBarView(parent) && itemIsWelfare(v)) {
        v.hidden = YES;
        v.userInteractionEnabled = NO;
        frame.origin.x = -5000;
    }
    if (orig_setFrame) ((void(*)(id, SEL, CGRect))orig_setFrame)(self, _cmd, frame);
}

%ctor {
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");

    if (tbv) {
        orig_update = replaceMethod(tbv, sel_registerName("updateNormalTabBarHandler"), (IMP)my_update);
    }
    if (tbi) {
        orig_setLabel = replaceMethod(tbi, @selector(setAccessibilityLabel:), (IMP)my_setLabel);
        orig_setFrame = replaceMethod(tbi, @selector(setFrame:), (IMP)my_setFrame);
    }
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
