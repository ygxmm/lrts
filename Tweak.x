#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void DBG(NSString *fmt, ...) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = dirs.firstObject ?: NSTemporaryDirectory();
        path = [dir stringByAppendingPathComponent:@"LazyAudioNoSplash.log"];
    });
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(path.UTF8String, "a");
    if (!f) return;
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
    fputs(line.UTF8String, f);
    fclose(f);
}

static IMP install_hook(Class cls, SEL sel, IMP newImp, const char *name) {
    if (!cls) { DBG(@"[hook] %s class=NULL", name); return NULL; }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { DBG(@"[hook] %s method=NULL", name); return NULL; }
    IMP orig = method_setImplementation(m, newImp);
    DBG(@"[hook] %s OK orig=%p", name, orig);
    return orig;
}

/* ============ 核心：只 Hook 底栏的 layoutSubviews ============ */
static IMP orig_tbv_layout = NULL;
static void hook_tbv_layout(id self, SEL _cmd) {
    // 让 Swift 先完成它自己的排布
    if (orig_tbv_layout) ((void(*)(id, SEL))orig_tbv_layout)(self, _cmd);
    
    UIView *tbv = (UIView *)self;
    BOOL hasWelfare = NO;
    
    // 1. 隐藏福利，并打上标记
    for (UIView *sub in tbv.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"]) {
            if (sub.tag == 3) { // 由 FLEX 截图确认：tag == 3 是福利
                hasWelfare = YES;
                sub.hidden = YES;
                sub.alpha = 0;
                sub.userInteractionEnabled = NO;
                sub.transform = CGAffineTransformMakeTranslation(-9999, 0);
            }
        }
    }
    
    // 2. 安全隔离：如果这个 TabBarView 里没有福利，说明是别的页面（整合页），直接 return
    if (!hasWelfare) return;
    
    // 3. 重排剩下的 4 个 Tab（0:听吧, 1:书架, 2:分类, 4:我的）
    // 根据 393 宽度计算：间距为 41，x 坐标依次为 15, 116, 217, 318
    for (UIView *sub in tbv.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && sub.tag != 3) {
            CGFloat targetX = 15.0;
            if (sub.tag == 1) targetX = 116.0;
            else if (sub.tag == 2) targetX = 217.0;
            else if (sub.tag == 4) targetX = 318.0;
            
            // 用 transform 定位，不会被底层的 AutoLayout 重置
            sub.transform = CGAffineTransformIdentity;
            CGFloat dx = targetX - sub.frame.origin.x;
            if (fabs(dx) > 0.5) {
                sub.transform = CGAffineTransformMakeTranslation(dx, 0);
            }
        }
    }
    DBG(@"[relayout] TabBarView 重排完成");
}

%ctor {
    DBG(@"=== ctor pid=%d ===", getpid());
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    if (tbv) {
        orig_tbv_layout = install_hook(tbv, @selector(layoutSubviews), (IMP)hook_tbv_layout, "TBV.layoutSubviews");
    }
}

/* ============ 开屏拦截（保持不变） ============ */
%hook TMEAdOperateSplash
+ (BOOL)needShowSplashWithLaunchType:(BOOL)arg0 { return NO; }
- (BOOL)canPreLoadAMSSplash { return NO; }
%end
%hook TMEAdOperateIntervalManager
- (BOOL)canShowSplash:(BOOL)arg0 { return NO; }
%end
%hook TMEAdOperateSplashManager
- (BOOL)checkAdCanShow:(id)arg0 { return NO; }
- (BOOL)hasP0AdSplashCanShow { return NO; }
- (BOOL)hasP1AdSplashCanShow:(id)arg0 { return NO; }
%end
%hook LMLaunchAd
+ (BOOL)shouldShow:(id)arg0 { return NO; }
%end
%hook LMLaunchAdMaxShowCountBridge
+ (BOOL)shouldShow:(id)arg0 { return NO; }
%end
