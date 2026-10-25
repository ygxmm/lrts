#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP orig_tbv_layout = NULL;

static void hook_tbv_layout(id self, SEL _cmd) {
    if (orig_tbv_layout) ((void(*)(id, SEL))orig_tbv_layout)(self, _cmd);
    
    UIView *tbv = (UIView *)self;
    
    // 1. 身份校验：找到该视图所属的 UIViewController，必须是主页面
    UIResponder *responder = tbv;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    if (!responder) return;
    
    NSString *vcName = NSStringFromClass([responder class]);
    if (![vcName containsString:@"AppMainController"]) return; // 不是主页，直接返回

    BOOL hasWelfare = NO;
    
    // 2. 遍历并隐藏福利 (tag == 3)
    for (UIView *sub in tbv.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && sub.tag == 3) {
            hasWelfare = YES;
            sub.hidden = YES;
            sub.alpha = 0;
            sub.userInteractionEnabled = NO;
            
            CGRect f = sub.frame;
            f.origin.x = -9999;
            sub.frame = f;
            sub.transform = CGAffineTransformMakeTranslation(-9999, 0);
        }
    }
    
    if (!hasWelfare) return;
    
    // 3. 异步重排剩下的 4 个 Tab（避开 Swift 内部布局的覆盖）
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat viewW = tbv.bounds.size.width > 0 ? tbv.bounds.size.width : 393.0;
        CGFloat itemW = 60.0;
        CGFloat margin = 15.0;
        
        // 计算间距：4个item，宽度60，间距 = (393 - 30 - 240) / 3 = 41
        CGFloat spacing = (viewW - 2 * margin - 4 * itemW) / 3.0;
        
        for (UIView *sub in tbv.subviews) {
            if ([NSStringFromClass(sub.class) containsString:@"TabBarItemView"] && sub.tag != 3) {
                CGFloat targetX = margin;
                if (sub.tag == 1) targetX = margin + (itemW + spacing);
                else if (sub.tag == 2) targetX = margin + 2 * (itemW + spacing);
                else if (sub.tag == 4) targetX = margin + 3 * (itemW + spacing);
                
                // 改 frame
                CGRect f = sub.frame;
                f.origin.x = targetX;
                sub.frame = f;
                
                // 防止内部约束强制拉扯
                sub.transform = CGAffineTransformIdentity;
            }
        }
    });
}

%ctor {
    Class tbv = NSClassFromString(@"lazyaudio.TabBarView");
    if (tbv) {
        Method m = class_getInstanceMethod(tbv, @selector(layoutSubviews));
        if (m) {
            orig_tbv_layout = method_getImplementation(m);
            method_setImplementation(m, (IMP)hook_tbv_layout);
        }
    }
}

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
