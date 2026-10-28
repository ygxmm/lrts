#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 精准干掉新版开屏 (纯方法 Hook，绝不 KVC) =================
// 根据探针头文件：lazyaudio.AppPrepareController
static BOOL (*orig_isSplashVisible)(id, SEL) = NULL;
static BOOL my_isSplashVisible(id self, SEL _cmd) {
    return NO; // 只要系统问“开屏可见吗”，直接回答 NO，系统自己会跳过
}

// ================= 3. 拦截签到 / 金币弹窗 (防崩溃终极版) =================
static void (*orig_presentVC)(id, SEL, UIViewController *, BOOL, void (^)(void)) = NULL;
static void my_presentVC(id self, SEL _cmd, UIViewController *vcToPresent, BOOL flag, void (^completion)(void)) {
    if (vcToPresent) {
        NSString *clsName = NSStringFromClass([vcToPresent class]);
        // 根据头文件和常见命名拦截：签到、打卡、任务、奖励、金币、弹窗
        NSArray *junkKeywords = @[@"Sign", @"CheckIn", @"Reward", @"Task", @"Coin", @"Gold", @"Popup", @"Activity"];
        
        BOOL isJunk = NO;
        for (NSString *keyword in junkKeywords) {
            if ([clsName localizedCaseInsensitiveContainsString:keyword]) {
                isJunk = YES;
                break;
            }
        }
        
        if (isJunk) {
            NSLog(@"[Tweak] 成功拦截弹窗: %@", clsName);
            // 防闪退核心：正常走 present 流程（无动画），弹出来一瞬间立马把它关掉
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

// ================= 4. 定时清扫赚钱悬浮球 (防崩静默版) =================
static void removeJunkViews(UIView *view) {
    if (!view) return;
    NSString *clsName = NSStringFromClass([view class]);
    
    // 探针头文件里真实的恶心类名
    NSArray *junkClasses = @[
        @"lazyaudio.EarningTaskBallView",
        @"lazyaudio.OnlineEarningNewLevitator",
        @"lazyaudio.EarningTaskEntryView",
        @"lazyaudio.OnlineEarningNewTipsView"
    ];
    
    if ([junkClasses containsObject:clsName]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        return; // 整个隐藏掉，不用再遍历它的子视图了
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

    // 根据头文件直接 Hook
    Class prepareCls = NSClassFromString(@"lazyaudio.AppPrepareController");
    if (prepareCls) {
        Method m = class_getInstanceMethod(prepareCls, @selector(isSplashVisible));
        if (m) {
            orig_isSplashVisible = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_isSplashVisible);
        }
    }

    // 拦截弹窗
    Class vcCls = [UIViewController class];
    Method mPresent = class_getInstanceMethod(vcCls, @selector(presentViewController:animated:completion:));
    if (mPresent) {
        orig_presentVC = (void *)method_getImplementation(mPresent);
        method_setImplementation(mPresent, (IMP)my_presentVC);
    }

    // 启动悬浮球清扫器
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        startCleaner();
    });

    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
