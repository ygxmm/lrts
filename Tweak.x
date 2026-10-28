#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface _TtC9lazyaudio14TabBarItemView : UIView
@end
@interface _TtC9lazyaudio12MeSignButton : UIView
@end
@interface _TtC9lazyaudio18LaunchSplashWindow : UIWindow
@end
@interface _TtC13Advertisement22SplashAdViewController : UIViewController
@end
@interface _TtC13Advertisement14SplashAdWindow : UIWindow
@end
@interface TGGDTSplashViewController : UIViewController
@end

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

__attribute__((constructor)) static void LAInit(void) {
    NSLog(@"[LazyAudio] tweak loaded");
}

// ========== 1. 底栏重排：隐藏 tag==3，剩余 4 个均分 ==========
%hook UIView
- (void)layoutSubviews {
    %orig;

    if (objc_getAssociatedObject(self, &kLAIgnoredKey)) {
        return;
    }

    NSArray<UIView *> *subs = self.subviews;
    NSUInteger cnt = subs.count;
    if (cnt < 2 || cnt > 10) {
        objc_setAssociatedObject(self, &kLAIgnoredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSMutableArray<UIView *> *visible = nil;
    for (UIView *sub in subs) {
        if (!LAIsTabItem(sub)) {
            continue;
        }
        if (sub.tag == 3) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
            sub.frame = CGRectZero;
        } else {
            if (!visible) {
                visible = [NSMutableArray array];
            }
            [visible addObject:sub];
        }
    }

    if (!visible || visible.count == 0) {
        objc_setAssociatedObject(self, &kLAIgnoredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSUInteger n = visible.count;
    CGFloat W = self.bounds.size.width;
    if (W <= 0) {
        return;
    }
    UIView *first = visible.firstObject;
    CGFloat y = first.frame.origin.y;
    CGFloat h = first.frame.size.height;
    if (h <= 0) {
        h = self.bounds.size.height;
    }
    CGFloat w = W / (CGFloat)n;
    for (NSUInteger i = 0; i < n; i++) {
        visible[i].frame = CGRectMake(w * (CGFloat)i, y, w, h);
    }
}
%end

// ========== 2. TabBarItemView 兜底隐藏 tag==3 ==========
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
%end

// ========== 3. 签到领钱按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

// ========== 4. 开屏 Window ==========
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    self.hidden = YES;
}
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden {
    hidden = YES;
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    self.hidden = YES;
}
%end

// ========== 5. 开屏 VC ==========
%hook _TtC13Advertisement22SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end
