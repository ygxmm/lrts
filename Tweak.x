#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 底栏福利隐藏 + 完美 4 等分 =================
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

// ================= 3. 初始化 Hook =================
%ctor {
    // 老版开屏
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

    // 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
