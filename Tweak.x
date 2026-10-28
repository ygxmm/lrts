#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 精准干掉新开屏 (AppPrepareController) =================
// 探针给的：- (BOOL)isSplashVisible;
// 直接骗系统说开屏不可见，它自然就不显示了，绝对不碰任何 KVC
static BOOL (*orig_isSplashVisible)(id, SEL) = NULL;
static BOOL my_isSplashVisible(id self, SEL _cmd) {
    return NO;
}

// ================= 3. 弹窗拦截 (安全版：让它弹出来，但秒关掉) =================
static void (*orig_presentVC)(id, SEL, UIViewController *, BOOL, void (^)(void)) = NULL;
static void my_presentVC(id self, SEL _cmd, UIViewController *viewControllerToPresent, BOOL flag, void (^completion)(void)) {
    if (viewControllerToPresent) {
        NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
        // 签到、任务、赚钱弹窗关键词
        NSArray *junkKeywords = @[@"Sign", @"CheckIn", @"Task", @"Reward", @"Earning", @"Coin", @"Activity", @"Popup"];
        for (NSString *keyword in junkKeywords) {
            if ([clsName containsString:keyword]) {
                NSLog(@"[Tweak] 发现恶心弹窗，即将秒关: %@", clsName);
                // 绝不直接 return，因为那样会引发 UIKit 状态崩溃
                // 先正常弹出来，并在 completion 里瞬间把它关掉
                if (orig_presentVC) {
                    orig_presentVC(self, _cmd, viewControllerToPresent, NO, ^{
                        if (completion) completion();
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                }
                return;
            }
        }
    }
    if (orig_presentVC) orig_presentVC(self, _cmd, viewControllerToPresent, flag, completion);
}

// ================= 4. 悬浮球清扫 (安全版) =================
static void removeJunkViews(UIView *view) {
    if (!view) return;
    NSString *clsName = NSStringFromClass([view class]);
    NSArray *junkKeywords = @[@"EarningTaskBallView", @"OnlineEarningNewLevitator", @"EarningTaskEntryView"];
    for (NSString *keyword in junkKeywords) {
        if ([clsName containsString:keyword]) {
            view.hidden = YES;
            view.alpha = 0;
            break;
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
    if (!tbv.superview || ![NSStringFromClass(tbv.superview.class) containsString:@"LMTabBar"]) return;
    if (tbv.bounds.size.width < 300) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView performWithoutAnimation:^{
            UIView *contentView = nil;
            for (UIView *sub in tbv.subviews) {
                if ([sub isMemberOfClass:[UIView class]] && fabs(sub.frame.size.height - 80) < 1.0) {
                    contentView = sub;
                    break;
                }
            }
            UIView *container = contentView ? contentView : tbv;

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

    // 2. 根据探针精准 Hook
    Class prepareCls = NSClassFromString(@"lazyaudio.AppPrepareController");
    if (prepareCls) {
        Method m = class_getInstanceMethod(prepareCls, @selector(isSplashVisible));
        if (m) {
            orig_isSplashVisible = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_isSplashVisible);
        }
    }

    Class vcCls = [UIViewController class];
    Method mPresent = class_getInstanceMethod(vcCls, @selector(presentViewController:animated:completion:));
    if (mPresent) {
        orig_presentVC = (void *)method_getImplementation(mPresent);
        method_setImplementation(mPresent, (IMP)my_presentVC);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        startCleaner();
    });

    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
