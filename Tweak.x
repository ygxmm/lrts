#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface _TtC9lazyaudio14TabBarItemView : UIView
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
static char kLAContainerClassKey;

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

static void LARelayout(UIView *container) {
    NSMutableArray<UIView *> *visible = nil;
    for (UIView *sub in container.subviews) {
        if (!LAIsTabItem(sub)) continue;
        if (sub.tag == 3) {
            if (!sub.hidden) sub.hidden = YES;
            if (sub.alpha != 0.0) sub.alpha = 0.0;
            if (sub.userInteractionEnabled) sub.userInteractionEnabled = NO;
            if (!CGRectEqualToRect(sub.frame, CGRectZero)) sub.frame = CGRectZero;
        } else {
            if (!visible) visible = [NSMutableArray array];
            [visible addObject:sub];
        }
    }
    NSUInteger n = visible.count;
    if (n == 0) return;
    CGFloat W = container.bounds.size.width;
    if (W <= 0) return;
    UIView *first = visible.firstObject;
    CGFloat y = first.frame.origin.y;
    CGFloat h = first.frame.size.height;
    if (h <= 0) h = container.bounds.size.height;
    CGFloat itemW = first.frame.size.width;
    if (itemW <= 0 || itemW > W) itemW = 60;
    CGFloat margin = first.frame.origin.x;
    if (margin < 0 || margin > W / 4) margin = 15;
    CGFloat totalGap = W - 2 * margin - n * itemW;
    CGFloat gap = (n > 1) ? totalGap / (n - 1) : 0;
    if (gap < 0) gap = 0;
    for (NSUInteger i = 0; i < n; i++) {
        CGFloat x = margin + i * (itemW + gap);
        CGRect target = CGRectMake(x, y, itemW, h);
        if (!CGRectEqualToRect(visible[i].frame, target)) {
            visible[i].frame = target;
        }
    }
}

%hook UIView
- (void)layoutSubviews {
    %orig;

    Class cls = object_getClass(self);
    NSNumber *cached = objc_getAssociatedObject(cls, &kLAContainerClassKey);
    if (cached) {
        if (cached.boolValue) LARelayout(self);
        return;
    }

    NSArray<UIView *> *subs = self.subviews;
    if (subs.count < 2 || subs.count > 10) {
        objc_setAssociatedObject(cls, &kLAContainerClassKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    BOOL isContainer = NO;
    for (UIView *sub in subs) {
        if (LAIsTabItem(sub)) { isContainer = YES; break; }
    }
    objc_setAssociatedObject(cls, &kLAContainerClassKey, @(isContainer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (isContainer) LARelayout(self);
}
%end

%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
        if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
    }
}
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
        if (self.userInteractionEnabled) self.userInteractionEnabled = NO;
    }
}
%end

%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden { hidden = YES; %orig; }
- (void)makeKeyAndVisible { %orig; self.hidden = YES; }
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden { hidden = YES; %orig; }
- (void)makeKeyAndVisible { %orig; self.hidden = YES; }
%end

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
