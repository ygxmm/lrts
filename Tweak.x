#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ================= 1. 干掉老版 OC 开屏 =================
static BOOL (*orig_needShowSplash)(id, SEL, NSInteger) = NULL;
static BOOL my_needShowSplash(id self, SEL _cmd, NSInteger type) { return NO; }

static BOOL (*orig_hasP0AdSplash)(id, SEL) = NULL;
static BOOL my_hasP0AdSplash(id self, SEL _cmd) { return NO; }

// ================= 2. 终极杀招：拦截广告 Window 上屏 =================
static void (*orig_makeKeyAndVisible)(id, SEL) = NULL;
static void my_makeKeyAndVisible(id self, SEL _cmd) {
    UIWindow *win = (UIWindow *)self;
    NSString *clsName = NSStringFromClass([win class]);
    
    // 探针实锤：Advertisement.SplashAdWindow
    // 只要是开屏广告 Window，或者名字带 Splash 的 Window，直接拦截，不让它上屏！
    if ([clsName containsString:@"SplashAdWindow"] || [clsName containsString:@"SplashWindow"]) {
        NSLog(@"[Tweak] 成功拦截开屏广告 Window: %@", clsName);
        return; // 直接 return，不执行原方法，窗口永远不显示
    }
    
    if (orig_makeKeyAndVisible) {
        orig_makeKeyAndVisible(self, _cmd);
    }
}

// ================= 3. 极简安全底栏 (只隐藏，底层自动重排) =================
static void (*orig_tbi_layout)(id, SEL) = NULL;
static void my_tbi_layout(id self, SEL _cmd) {
    if (orig_tbi_layout) orig_tbi_layout(self, _cmd);
    UIView *tbv = ((UIView *)self).superview;
    if (!tbv || ![NSStringFromClass(tbv.class) containsString:@"TabBarView"] || tbv.bounds.size.width < 300) return;

    // 极度安全：只隐藏福利 tag 3，绝对不碰坐标
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

    // 拦截 UIWindow 的 makeKeyAndVisible
    Method mkWindow = class_getInstanceMethod([UIWindow class], @selector(makeKeyAndVisible));
    if (mkWindow) {
        orig_makeKeyAndVisible = (void *)method_getImplementation(mkWindow);
        method_setImplementation(mkWindow, (IMP)my_makeKeyAndVisible);
    }

    // 底栏
    Class tbi = NSClassFromString(@"lazyaudio.TabBarItemView");
    if (tbi) {
        Method m = class_getInstanceMethod(tbi, @selector(layoutSubviews));
        if (m) { orig_tbi_layout = (void *)method_getImplementation(m); method_setImplementation(m, (IMP)my_tbi_layout); }
    }
}
