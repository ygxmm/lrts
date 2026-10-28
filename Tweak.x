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

// ================= 2. 基于头文件击杀 AppPrepareController =================
static BOOL (*orig_isSplashVisible)(id, SEL) = NULL;
static BOOL my_isSplashVisible(id self, SEL _cmd) { return NO; } // 强制返回不可见

static void (*orig_prepare_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_prepare_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_prepare_viewDidAppear) orig_prepare_viewDidAppear(self, _cmd, animated);
    
    // 根据头文件精准定位 $__lazy_storage_$_launchView 和 $__lazy_storage_$_agreementView
    id launchView = getIvarSafe(self, "$__lazy_storage_$_launchView");
    if (launchView && [launchView isKindOfClass:[UIView class]]) {
        UIView *v = (UIView *)launchView;
        v.hidden = YES;
        v.alpha = 0;
        [v removeFromSuperview];
    }
    
    id agreementView = getIvarSafe(self, "$__lazy_storage_$_agreementView");
    if (agreementView && [agreementView isKindOfClass:[UIView class]]) {
        UIView *v = (UIView *)agreementView;
        v.hidden = YES;
        v.alpha = 0;
        [v removeFromSuperview];
    }
}

// ================= 3. 基于头文件击杀赚钱悬浮窗 =================
static void (*orig_ball_didMove)(id, SEL) = NULL;
static void my_ball_didMove(id self, SEL _cmd) {
    if (orig_ball_didMove) orig_ball_didMove(self, _cmd);
    UIView *v = (UIView *)self;
    v.hidden = YES;
    v.alpha = 0;
    v.userInteractionEnabled = NO;
}

// ================= 4. 弹窗拦截（安全秒关法） =================
static void (*orig_presentVC)(id, SEL, UIViewController *, BOOL, void (^)(void)) = NULL;
static void my_presentVC(id self, SEL _cmd, UIViewController *vcToPresent, BOOL flag, void (^completion)(void)) {
    if (vcToPresent) {
        NSString *clsName = NSStringFromClass([vcToPresent class]);
        NSArray *junkKeywords = @[@"Sign", @"CheckIn", @"Reward", @"Task", @"Coin", @"Gold", @"Popup", @"Activity"];
        BOOL isJunk = NO;
        for (NSString *keyword in junkKeywords) {
            if ([clsName localizedCaseInsensitiveContainsString:keyword]) {
                isJunk = YES;
                break;
            }
        }
        if (isJunk) {
            if (orig_presentVC) {
                orig_presentVC(self, _cmd, vcToPresent, NO, ^{
                    if (completion) completion();
                    [vcToPresent dismissViewControllerAnimated:NO completion:nil];
                });
            }
            return;
        }
    }
    if (orig_presentVC) orig_presentVC(self, _cmd, vcToPresent, flag, completion);
}

// ================= 5. 底栏重排（利用头文件的 contentView） =================
static void (*orig_tbi_layout)(id, SEL) = NULL;
static void my_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) orig_tbi_layout(self, _cmd);
    UIView *v = (UIView *)self;
    UIView *tbv = v.superview;

    if (!tbv || ![NSStringFromClass(tbv.class) containsString:@"TabBarView"]) return;
    if (tbv.bounds.size.width < 300) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView performWithoutAnimation:^{
            // 根据头文件直接获取 contentView
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
    // 1. 老开屏
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

    // 2. 基于头文件精准击杀 AppPrepareController
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

    // 3. 基于头文件击杀赚钱悬浮窗
    NSArray *earningClasses = @[@"lazyaudio.EarningTaskBallView", @"lazyaudio.OnlineEarningNewLevitator", @"lazyaudio.OnlineEarningNewEntryView"];
    for (NSString *clsStr in earningClasses) {
        Class cls = NSClassFromString(clsStr);
        if (cls) {
            Method m = class_getInstanceMethod(cls, @selector(didMoveToWindow));
            if (m) {
                orig_ball_didMove = (void *)method_getImplementation(m);
                method_setImplementation(m, (IMP)my_ball_didMove);
            }
        }
    }

    // 4. 弹窗拦截
    Class vcCls = [UIViewController class];
    Method mPresent = class_getInstanceMethod(vcCls, @selector(presentViewController:animated:completion:));
    if (mPresent) {
        orig_presentVC = (void *)method_getImplementation(mPresent);
        method_setImplementation(mPresent, (IMP)my_presentVC);
    }

    // 5. 底栏重排
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
