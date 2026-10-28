#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 根据头文件精准干掉开屏 (AppPrepareController) =================
// 拦截 viewDidAppear，直接把 launchView 干掉
static void (*orig_prepare_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_prepare_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_prepare_viewDidAppear) orig_prepare_viewDidAppear(self, _cmd, animated);
    
    // 利用 KVC 取出探针里提到的 launchView，直接隐藏
    UIView *launchView = [self valueForKey:@"launchView"];
    if (launchView) {
        launchView.hidden = YES;
        launchView.alpha = 0;
        [launchView removeFromSuperview];
    }
    
    // 再拦截 isSplashVisible 强制返回 NO
    if ([self respondsToSelector:@selector(setIsSplashVisible:)]) {
        [self setValue:@(NO) forKey:@"isSplashVisible"];
    }
}

// ================= 3. 拦截所有“签到/赚钱”弹窗 (底层大招) =================
// 任何弹窗最终都会走 UIViewController 的 presentViewController 方法
static void (*orig_presentVC)(id, SEL, UIViewController *, BOOL, void (^)(void)) = NULL;
static void my_presentVC(id self, SEL _cmd, UIViewController *viewControllerToPresent, BOOL flag, void (^completion)(void)) {
    if (viewControllerToPresent) {
        NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
        // 通杀关键字：签到、任务、奖励、赚钱、金币、活动
        NSArray *junkKeywords = @[@"Sign", @"CheckIn", @"Task", @"Reward", @"Earning", @"Coin", @"Activity", @"Popup"];
        for (NSString *keyword in junkKeywords) {
            if ([clsName containsString:keyword]) {
                NSLog(@"[Tweak] 成功拦截弹窗: %@", clsName);
                return; // 直接 return，取消弹窗
            }
        }
    }
    if (orig_presentVC) orig_presentVC(self, _cmd, viewControllerToPresent, flag, completion);
}

// ================= 4. 拦截赚钱悬浮球的初始化 =================
// 探针提供的类名，在 init 阶段直接拦截，连内存都不给它分配
static id (*orig_earning_init)(id, SEL, CGRect) = NULL;
static id my_earning_init(id self, SEL _cmd, CGRect frame) {
    return nil; // 直接返回 nil，让悬浮球创建失败
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

    // 新开屏 (AppPrepareController)
    Class prepareCls = NSClassFromString(@"lazyaudio.AppPrepareController");
    if (prepareCls) {
        Method m = class_getInstanceMethod(prepareCls, @selector(viewDidAppear:));
        if (m) { orig_prepare_viewDidAppear = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_prepare_viewDidAppear); }
    }

    // 拦截所有弹窗
    Class vcCls = [UIViewController class];
    Method mPresent = class_getInstanceMethod(vcCls, @selector(presentViewController:animated:completion:));
    if (mPresent) {
        orig_presentVC = (void *)method_getImplementation(mPresent);
        method_setImplementation(mPresent, (IMP)my_presentVC);
    }

    // 拦截赚钱悬浮球 (探针给的类名)
    NSArray *earningClasses = @[@"lazyaudio.EarningTaskBallView", @"lazyaudio.OnlineEarningNewLevitator", @"lazyaudio.EarningTaskEntryView"];
    for (NSString *clsStr in earningClasses) {
        Class cls = NSClassFromString(clsStr);
        if (cls) {
            Method m = class_getInstanceMethod(cls, @selector(initWithFrame:));
            if (m) {
                orig_earning_init = (void *)method_getImplementation(m);
                method_setImplementation(m, (IMP)my_earning_init);
            }
        }
    }

    // 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
