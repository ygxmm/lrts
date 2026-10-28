#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 彻底干碎广点通开屏控制器 =================
// 探针实锤类名：TGGDTSplashViewController
static void (*orig_gdt_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_gdt_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_gdt_viewDidAppear) orig_gdt_viewDidAppear(self, _cmd, animated);
    // 只要它出现，直接把它的视图干掉
    UIViewController *vc = (UIViewController *)self;
    vc.view.hidden = YES;
    vc.view.alpha = 0;
}

// ================= 2. 干掉开屏专用 Window =================
// 探针实锤类名：Advertisement.SplashAdWindow
static void (*orig_win_setHidden)(id, SEL, BOOL) = NULL;
static void my_win_setHidden(id self, SEL _cmd, BOOL hidden) {
    if (orig_win_setHidden) orig_win_setHidden(self, _cmd, YES); // 永远强制隐藏
}

static void (*orig_win_makeKey)(id, SEL) = NULL;
static void my_win_makeKey(id self, SEL _cmd) {
    // 拦截一切上屏请求，什么都不做
}

// ================= 3. 完美底栏：只隐藏 tag 3 =================
static void (*orig_tbi_didMove)(id, SEL) = NULL;
static void my_tbi_didMove(id self, SEL _cmd) {
    if (orig_tbi_didMove) orig_tbi_didMove(self, _cmd);
    UIView *v = (UIView *)self;
    if (v.tag == 3) {
        v.hidden = YES;
        v.alpha = 0;
        v.userInteractionEnabled = NO;
    }
}

// ================= 4. 初始化 Hook =================
%ctor {
    // 1. Hook 广点通开屏 VC
    Class gdtVC = NSClassFromString(@"TGGDTSplashViewController");
    if (gdtVC) {
        Method m = class_getInstanceMethod(gdtVC, @selector(viewDidAppear:));
        if (m) {
            orig_gdt_viewDidAppear = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_gdt_viewDidAppear);
        }
    }

    // 2. Hook 开屏专用 Window
    Class splashWin = NSClassFromString(@"Advertisement.SplashAdWindow");
    if (splashWin) {
        Method mHidden = class_getInstanceMethod(splashWin, @selector(setHidden:));
        if (mHidden) {
            orig_win_setHidden = (void *)method_getImplementation(mHidden);
            method_setImplementation(mHidden, (IMP)my_win_setHidden);
        }
        Method mKey = class_getInstanceMethod(splashWin, @selector(makeKeyAndVisible));
        if (mKey) {
            orig_win_makeKey = (void *)method_getImplementation(mKey);
            method_setImplementation(mKey, (IMP)my_win_makeKey);
        }
    }

    // 3. Hook 底栏 Item
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(didMoveToWindow));
        if (m) {
            orig_tbi_didMove = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)my_tbi_didMove);
        }
    }
}
