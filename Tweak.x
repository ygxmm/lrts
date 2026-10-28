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

// ================= 3. 赚钱/签到挂件与悬浮球拦截 =================
// 3.1 拦截 EarningTaskEntryView 的显示刷新
static void (*orig_refreshWithIsVisible)(id, SEL, BOOL) = NULL;
static void my_refreshWithIsVisible(id self, SEL _cmd, BOOL isVisible) {
    if (orig_refreshWithIsVisible) orig_refreshWithIsVisible(self, _cmd, NO); // 强制传 NO
}

// 3.2 拦截 EarningTaskBallView 的生命周期
static void (*orig_ball_didMove)(id, SEL) = NULL;
static void my_ball_didMove(id self, SEL _cmd) {
    if (orig_ball_didMove) orig_ball_didMove(self, _cmd);
    UIView *v = (UIView *)self;
    v.hidden = YES;
    v.alpha = 0;
    v.userInteractionEnabled = NO;
}

// 3.3 拦截 OnlineEarningDrawer 单例拉出抽屉
static id (*orig_drawer_shared)(id, SEL) = NULL;
static id my_drawer_shared(id self, SEL _cmd) {
    id instance = orig_drawer_shared(self, _cmd);
    if (instance) {
        [instance performSelector:@selector(close) withObject:nil];
    }
    return instance;
}

// ================= 4. 全局弹窗拦截 (基于分类 PopDialogView) =================
static void (*orig_lmr_showPopDialog)(id, SEL) = NULL;
static void my_lmr_showPopDialog(id self, SEL _cmd) {
    NSString *clsName = NSStringFromClass([self class]);
    
    // 拦截包含 Reward, Sign, Task, Coin, PremiumFreeListen 的弹窗
    NSArray *junkKeywords = @[@"Reward", @"Sign", @"Task", @"Coin", @"Gold", @"PremiumFreeListen"];
    BOOL isJunk = NO;
    for (NSString *kw in junkKeywords) {
        if ([clsName localizedCaseInsensitiveContainsString:kw]) {
            isJunk = YES;
            break;
        }
    }
    
    if (isJunk) {
        NSLog(@"[Tweak] 成功拦截弹窗 VC: %@", clsName);
        // 如果它自身响应隐藏方法，直接隐藏；否则不调用原方法即可
        if ([self respondsToSelector:@selector(lmr_hidePopDialogView:)]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:@selector(lmr_hidePopDialogView:) withObject:nil];
            #pragma clang diagnostic pop
        }
        return;
    }
    
    if (orig_lmr_showPopDialog) orig_lmr_showPopDialog(self, _cmd);
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
    // 1. 老版开屏
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

    // 2. 新版开屏
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

    // 3. 赚钱组件拦截
    Class entryCls = NSClassFromString(@"lazyaudio.EarningTaskEntryView");
    if (entryCls) {
        Method m = class_getInstanceMethod(entryCls, @selector(refreshWithIsVisible:));
        if (m) {
            orig_refreshWithIsVisible = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_refreshWithIsVisible);
        }
    }
    Class ballCls = NSClassFromString(@"lazyaudio.EarningTaskBallView");
    if (ballCls) {
        Method m = class_getInstanceMethod(ballCls, @selector(didMoveToWindow));
        if (m) {
            orig_ball_didMove = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_ball_didMove);
        }
    }
    Class drawerCls = NSClassFromString(@"lazyaudio.OnlineEarningDrawer");
    if (drawerCls) {
        Method m = class_getClassMethod(drawerCls, @selector(shared));
        if (m) {
            orig_drawer_shared = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_drawer_shared);
        }
    }

    // 4. 弹窗拦截 (PopDialogView 分类方法)
    Class vcCls = [UIViewController class];
    Method mPop = class_getInstanceMethod(vcCls, @selector(lmr_showPopDialogView));
    if (mPop) {
        orig_lmr_showPopDialog = (void *)method_getImplementation(mPop);
        method_setImplementation(mPop, (IMP)my_lmr_showPopDialog);
    }

    // 5. 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
