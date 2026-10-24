#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
           [text containsString:@"金币"] || [text containsString:@"免费"] ||
           [text containsString:@"权益"] || [text containsString:@"红包"] ||
           [text containsString:@"奖励"] || [text containsString:@"提现"];
}

static IMP install_hook(Class cls, SEL sel, IMP newImp) {
    if (!cls) return NULL;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP orig = method_getImplementation(m);
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) return orig;
    return method_setImplementation(m, newImp);
}

/* 隐藏福利 + 重排剩余可见 item（在 TabBarView.layoutSubviews 结束后调用） */
static void hideWelfareAndRelayout(UIView *tabBarView) {
    if (!tabBarView) return;

    for (UIView *sub in tabBarView.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"]) {
            NSString *text = describeView(sub);
            if (textLooksLikeWelfare(text)) {
                sub.hidden = YES;
                sub.userInteractionEnabled = NO;
            }
        }
    }

    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *sub in tabBarView.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && !sub.hidden) {
            [visible addObject:sub];
        }
    }
    NSUInteger N = visible.count;
    if (N == 0) return;
    CGFloat viewW = tabBarView.bounds.size.width;
    CGFloat itemW = 60;
    CGFloat margin = 15;
    CGFloat spacing = (N > 1) ? (viewW - 2 * margin - N * itemW) / (N - 1) : 0;
    for (NSUInteger i = 0; i < N; i++) {
        UIView *item = visible[i];
        CGRect f = item.frame;
        f.origin.x = margin + i * (itemW + spacing);
        item.frame = f;
    }
}

/* ============ 关键：hook TabBarView.layoutSubviews ============ */
static IMP orig_TBV_layout = NULL;
static void hook_TBV_layout(id self, SEL _cmd) {
    if (orig_TBV_layout) ((void(*)(id, SEL))orig_TBV_layout)(self, _cmd);
    hideWelfareAndRelayout((UIView *)self);
}

static BOOL g_installed = NO;
static void InstallSwiftHooks(void) {
    if (g_installed) return;
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    if (!tbv) return;
    orig_TBV_layout = install_hook(tbv, @selector(layoutSubviews), (IMP)hook_TBV_layout);
    g_installed = YES;
}

%ctor {
    InstallSwiftHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InstallSwiftHooks();
    });
}

/* ============ 开屏 hook（保留） ============ */
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
