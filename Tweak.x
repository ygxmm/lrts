#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 视觉欺骗干掉新版 Swift 开屏 =================
// 不拦截状态，只拦截视图出现，直接让它透明
static void (*orig_splash_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_splash_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_splash_viewDidAppear) orig_splash_viewDidAppear(self, _cmd, animated);
    
    // 只要这个控制器出现了，直接把它的 view 隐藏并移出层级
    UIViewController *vc = (UIViewController *)self;
    vc.view.hidden = YES;
    vc.view.alpha = 0;
    vc.view.userInteractionEnabled = NO;
}

// ================= 3. 极简安全底栏隐藏 =================
static void (*orig_tbi_layout)(id, SEL) = NULL;
static void my_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) orig_tbi_layout(self, _cmd);
    UIView *v = (UIView *)self;
    UIView *tbv = v.superview;

    if (!tbv || ![NSStringFromClass(tbv.class) containsString:@"TabBarView"]) return;
    if (tbv.bounds.size.width < 300) return;

    // 极度安全：只隐藏福利 tag 3，不修改坐标，底层会自动重排
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *sub in tbv.subviews) {
            if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && sub.tag == 3) {
                sub.hidden = YES;
                sub.alpha = 0;
                sub.userInteractionEnabled = NO;
            }
        }
    });
}

// ================= 4. 初始化 Hook =================
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

    // 新版开屏 (探针头文件里的 Advertisement.SplashAdViewController)
    Class newSplashCls = NSClassFromString(@"Advertisement.SplashAdViewController");
    if (newSplashCls) {
        Method m = class_getInstanceMethod(newSplashCls, @selector(viewDidAppear:));
        if (m) {
            orig_splash_viewDidAppear = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_splash_viewDidAppear);
        }
    }

    // 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
