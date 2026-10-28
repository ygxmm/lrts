#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 辅助函数：纯内存安全读取 Ivar =================
static id getIvarSafe(id instance, const char *ivarName) {
    if (!instance) return nil;
    Ivar ivar = class_getInstanceVariable([instance class], ivarName);
    if (ivar) {
        return object_getIvar(instance, ivar);
    }
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

// ================= 3. 拦截弹窗 =================
static void (*orig_presentVC)(id, SEL, UIViewController *, BOOL, void (^)(void)) = NULL;
static void my_presentVC(id self, SEL _cmd, UIViewController *vcToPresent, BOOL flag, void (^completion)(void)) {
    if (vcToPresent) {
        NSString *clsName = NSStringFromClass([vcToPresent class]);
        NSArray *junkKeywords = @[@"Reward", @"Task", @"Coin", @"Gold", @"Earning"];
        for (NSString *keyword in junkKeywords) {
            if ([clsName localizedCaseInsensitiveContainsString:keyword]) {
                if (orig_presentVC) {
                    orig_presentVC(self, _cmd, vcToPresent, NO, ^{
                        if (completion) completion();
                        [vcToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                }
                return;
            }
        }
    }
    if (orig_presentVC) orig_presentVC(self, _cmd, vcToPresent, flag, completion);
}

// ================= 4. 终极清扫器 (类名+文字双重猎杀) =================
static void removeJunkViews(UIView *view) {
    if (!view) return;
    NSString *clsName = NSStringFromClass([view class]);
    
    // 4.1 类名黑名单（悬浮球、诱导挂件）
    NSArray *junkClasses = @[
        @"lazyaudio.EarningTaskBallView",
        @"lazyaudio.EarningTaskEntryView",
        @"lazyaudio.OnlineEarningEntryView",
        @"lazyaudio.OnlineEarningNewEntryView",
        @"lazyaudio.OnlineEarningNewLevitator",
        @"lazyaudio.OnlineEarningNewTipsView",
        @"lazyaudio.PendingOrderCountdownView",
        @"lazyaudio.PendingOrderEnterView",
        @"lazyaudio.PendingOrderTipsView",
        @"lazyaudio.GlobalFreeEnterView"
    ];
    
    if ([junkClasses containsObject:clsName]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        return;
    }
    
    // 4.2 探针精准打击：寻找文字为“签到领钱”的 UIButton 或 UILabel
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: btn.currentTitle;
        if (title && ([title containsString:@"签到"] || [title containsString:@"领钱"] || [title containsString:@"金币"])) {
            // 杀掉按钮本身，并且尝试杀掉它的父视图（因为通常有个背板）
            view.hidden = YES;
            view.alpha = 0;
            if (view.superview && view.superview.frame.size.width < 150) {
                view.superview.hidden = YES;
            }
            return;
        }
    }
    
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        if (lbl.text && ([lbl.text containsString:@"签到"] || [lbl.text containsString:@"领钱"])) {
            view.hidden = YES;
            view.alpha = 0;
            return;
        }
    }
    
    for (UIView *sub in view.subviews) {
        removeJunkViews(sub);
    }
}

static void startCleaner() {
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            removeJunkViews(window);
        }
    }];
}

// ================= 5. 底栏福利隐藏 + 完美 4 等分 =================
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

// ================= 6. 初始化 Hook =================
%ctor {
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

    Class vcCls = [UIViewController class];
    Method mPresent = class_getInstanceMethod(vcCls, @selector(presentViewController:animated:completion:));
    if (mPresent) {
        orig_presentVC = (void *)method_getImplementation(mPresent);
        method_setImplementation(mPresent, (IMP)my_presentVC);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        startCleaner();
    });

    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
