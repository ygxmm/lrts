#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 辅助函数：纯内存安全读取 Ivar =================
static id getIvarSafe(id instance, const char *ivarName) {
    if (!instance) return nil;
    Ivar ivar = class_getInstanceVariable([instance class], ivarName);
    if (ivar) return object_getIvar(instance, ivar);
    return nil;
}

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 击杀 AppPrepareController 开屏 =================
static BOOL (*orig_isSplashVisible)(id, SEL) = NULL;
static BOOL my_isSplashVisible(id self, SEL _cmd) { return NO; } 

static void (*orig_prepare_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_prepare_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_prepare_viewDidAppear) orig_prepare_viewDidAppear(self, _cmd, animated);
    
    // 获取开屏视图和隐私弹窗，直接移除
    id launchView = getIvarSafe(self, "$__lazy_storage_$_launchView");
    if (launchView && [launchView isKindOfClass:[UIView class]]) {
        UIView *v = (UIView *)launchView;
        v.hidden = YES;
        [v removeFromSuperview];
    }
    
    id agreementView = getIvarSafe(self, "$__lazy_storage_$_agreementView");
    if (agreementView && [agreementView isKindOfClass:[UIView class]]) {
        UIView *v = (UIView *)agreementView;
        v.hidden = YES;
        [v removeFromSuperview];
    }
}

// ================= 3. 基于头文件的精准猎杀 =================

// 3.1 拦截 EarningTaskEntryView 的显示请求
// 头文件: - (void)refreshWithIsVisible:(BOOL)arg2;
static void (*orig_refreshWithIsVisible)(id, SEL, BOOL) = NULL;
static void my_refreshWithIsVisible(id self, SEL _cmd, BOOL isVisible) {
    // 不管它传什么，我们强行传 NO，让它永远不显示
    if (orig_refreshWithIsVisible) orig_refreshWithIsVisible(self, _cmd, NO);
}

// 3.2 拦截 EarningTaskBallView 的生命周期
// 只要悬浮球想上屏幕，直接干掉
static void (*orig_ball_didMove)(id, SEL) = NULL;
static void my_ball_didMove(id self, SEL _cmd) {
    if (orig_ball_didMove) orig_ball_didMove(self, _cmd);
    UIView *v = (UIView *)self;
    v.hidden = YES;
    v.alpha = 0;
    v.userInteractionEnabled = NO;
}

// 3.3 针对 OnlineEarningNewEntryView (它是 OnlineEarningEntryView 的子类)
// 头文件有 - (void)updateStateWithIsEnforce:(BOOL)arg2;
// 我们直接 Hook 它的 init 或者 didMoveToWindow 来隐藏
static void (*orig_online_didMove)(id, SEL) = NULL;
static void my_online_didMove(id self, SEL _cmd) {
    if (orig_online_didMove) orig_online_didMove(self, _cmd);
    UIView *v = (UIView *)self;
    v.hidden = YES;
    v.alpha = 0;
}

// ================= 4. 底栏福利隐藏 + 完美 4 等分 =================
static void (*orig_tbi_layout)(id, SEL) = NULL;
static void my_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) orig_tbi_layout(self, _cmd);
    UIView *v = (UIView *)self;
    UIView *tbv = v.superview;

    if (!tbv || ![NSStringFromClass(tbv.class) containsString:@"TabBarView"]) return;
    if (tbv.bounds.size.width < 300) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView performWithoutAnimation:^{
            id contentView = getIvarSafe(tbv, "$__lazy_storage_$_contentView");
            UIView *container = contentView ? (UIView *)contentView : tbv;

            NSMutableArray *items = [NSMutableArray array];
            for (UIView *sub in container.subviews) {
                if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"]) {
                    [items addObject:sub];
                }
            }

            if (items.count >= 5) {
                CGFloat slotWidth = tbv.bounds.size.width / 4.0;
                NSArray *validTags = @[@(0), @(1), @(2), @(4)];

                for (UIView *sub in items) {
                    if (sub.tag == 3) {
                        sub.hidden = YES;
                        sub.alpha = 0;
                        sub.userInteractionEnabled = NO;
                        sub.center = CGPointMake(-9999, 30.0);
                    } else {
                        NSInteger index = [validTags indexOfObject:@(sub.tag)];
                        if (index != NSNotFound) {
                            CGFloat targetCenterX = (slotWidth * index) + (slotWidth / 2.0);
                            sub.center = CGPointMake(targetCenterX, 30.0); 
                            sub.bounds = CGRectMake(0, 0, 60, 60); 
                        }
                    }
                }
            }
        }];
    });
}

// ================= 5. 初始化 Hook =================
%ctor {
    // 老开屏
    Class splashCls = NSClassFromString(@"TMEAdOperateSplash");
    if (splashCls) {
        Method m = class_getClassMethod(splashCls, @selector(needShowSplashWithLaunchType:));
        if (m) { orig_needShowSplash = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_needShowSplash); }
    }
    Class managerCls = NSClassFromString(@"TMEAdOperateSplashManager");
    if (managerCls) {
        Method m = class_getInstanceMethod(managerCls, @selector(hasP0AdSplashCanShow));
        if (m) { orig_hasP0AdSplash = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_hasP0AdSplash); }
    }

    // 新开屏
    Class prepareCls = NSClassFromString(@"lazyaudio.AppPrepareController");
    if (prepareCls) {
        Method mVisible = class_getInstanceMethod(prepareCls, @selector(isSplashVisible));
        if (mVisible) {
            orig_isSplashVisible = (void *)method_getImplementation(mVisible);
            method_setImplementation(mVisible, (IMP)my_isSplashVisible);
        }
        Method mAppear = class_getInstanceMethod(prepareCls, @selector(viewDidAppear:));
        if (mAppear) {
            orig_prepare_viewDidAppear = (void *)method_getImplementation(mAppear);
            method_setImplementation(mAppear, (IMP)my_prepare_viewDidAppear);
        }
    }

    // 🌟 3. 基于头文件精准猎杀
    // 3.1 EarningTaskEntryView 的 refreshWithIsVisible
    Class entryCls = NSClassFromString(@"lazyaudio.EarningTaskEntryView");
    if (entryCls) {
        Method m = class_getInstanceMethod(entryCls, @selector(refreshWithIsVisible:));
        if (m) {
            orig_refreshWithIsVisible = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_refreshWithIsVisible);
        }
    }

    // 3.2 EarningTaskBallView 的 didMoveToWindow
    Class ballCls = NSClassFromString(@"lazyaudio.EarningTaskBallView");
    if (ballCls) {
        Method m = class_getInstanceMethod(ballCls, @selector(didMoveToWindow));
        if (m) {
            orig_ball_didMove = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_ball_didMove);
        }
    }

    // 3.3 OnlineEarningNewEntryView 的 didMoveToWindow
    Class onlineCls = NSClassFromString(@"lazyaudio.OnlineEarningNewEntryView");
    if (onlineCls) {
        Method m = class_getInstanceMethod(onlineCls, @selector(didMoveToWindow));
        if (m) {
            orig_online_didMove = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_online_didMove);
        }
    }

    // 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
