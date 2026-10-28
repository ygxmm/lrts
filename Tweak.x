#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 拦截所有带 Splash 的 Window =================
static void (*orig_setHidden)(id, SEL, BOOL) = NULL;
static void my_setHidden(id self, SEL _cmd, BOOL hidden) {
    UIWindow *win = (UIWindow *)self;
    NSString *clsName = NSStringFromClass([win class]);
    if ([clsName containsString:@"Splash"] || [clsName containsString:@"AdWindow"]) {
        hidden = YES; // 只要是广告窗口，强制隐藏
    }
    if (orig_setHidden) orig_setHidden(self, _cmd, hidden);
}

static void (*orig_makeKeyAndVisible)(id, SEL) = NULL;
static void my_makeKeyAndVisible(id self, SEL _cmd) {
    UIWindow *win = (UIWindow *)self;
    NSString *clsName = NSStringFromClass([win class]);
    if ([clsName containsString:@"Splash"] || [clsName containsString:@"AdWindow"]) {
        return; // 拒绝上屏
    }
    if (orig_makeKeyAndVisible) orig_makeKeyAndVisible(self, _cmd);
}

// ================= 3. 拦截广点通/Advertisement 开屏 VC =================
static void (*orig_splash_viewDidAppear)(id, SEL, BOOL) = NULL;
static void my_splash_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_splash_viewDidAppear) orig_splash_viewDidAppear(self, _cmd, animated);
    
    UIViewController *vc = (UIViewController *)self;
    vc.view.hidden = YES;
    vc.view.alpha = 0;
    [vc.view removeFromSuperview];
}

// ================= 4. 递归寻找并隐藏底栏福利 =================
static void hideTab3(UIView *view) {
    if (!view) return;
    if (view.tag == 3 && [NSStringFromClass([view class]) containsString:@"TabBarItemView"]) {
        view.hidden = YES;
        view.alpha = 0;
        view.userInteractionEnabled = NO;
        return;
    }
    for (UIView *sub in view.subviews) {
        hideTab3(sub);
    }
}

static void (*orig_tbi_layout)(id, SEL) = NULL;
static void my_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) orig_tbi_layout(self, _cmd);
    UIView *tbv = ((UIView *)self).superview;
    if (!tbv || ![NSStringFromClass(tbv.class) containsString:@"TabBarView"] || tbv.bounds.size.width < 300) return;

    // 延迟异步执行，保证底层把 5 个都创建好了
    dispatch_async(dispatch_get_main_queue(), ^{
        hideTab3(tbv); // 递归遍历把 tag 3 干掉
    });
}

// ================= 5. 初始化 Hook =================
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

    // 新版开屏 Window 拦截
    Method setHiddenM = class_getInstanceMethod([UIWindow class], @selector(setHidden:));
    if (setHiddenM) {
        orig_setHidden = (void *)method_getImplementation(setHiddenM);
        method_setImplementation(setHiddenM, (IMP)my_setHidden);
    }
    Method makeKeyM = class_getInstanceMethod([UIWindow class], @selector(makeKeyAndVisible));
    if (makeKeyM) {
        orig_makeKeyAndVisible = (void *)method_getImplementation(makeKeyM);
        method_setImplementation(makeKeyM, (IMP)my_makeKeyAndVisible);
    }

    // 新版开屏 VC 拦截
    NSArray *splashVCs = @[@"TGGDTSplashViewController", @"Advertisement.SplashAdViewController"];
    for (NSString *clsStr in splashVCs) {
        Class cls = NSClassFromString(clsStr);
        if (cls) {
            Method m = class_getInstanceMethod(cls, @selector(viewDidAppear:));
            if (m) {
                orig_splash_viewDidAppear = (void *)method_getImplementation(m);
                method_setImplementation(m, (IMP)my_splash_viewDidAppear);
            }
        }
    }

    // 底栏拦截
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
