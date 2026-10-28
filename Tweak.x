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
static BOOL LAIsTabItemView(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v isKindOfClass:gTabItemClass];
}

%hook UIView
- (void)layoutSubviews {
    %orig;

    // 快速过滤：子视图少于 2 个直接返回，不创建任何对象
    NSArray<UIView *> *subs = self.subviews;
    if (subs.count < 2) {
        return;
    }

    // 只有直接子视图里出现 TabBarItemView 才进入重排
    NSMutableArray<UIView *> *visible = nil;
    for (UIView *sub in subs) {
        if (!LAIsTabItemView(sub)) {
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

    NSUInteger n = visible.count;
    if (n == 0) {
        return;
    }
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

%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

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

%hook UIViewController
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!vc) {
        %orig;
        return;
    }
    NSString *cls = NSStringFromClass([vc class]);
    static NSArray *allow = nil;
    static NSArray *blocked = nil;
    if (!allow) {
        allow = @[@"Probe", @"FLEX", @"Debug", @"Inspector", @"Console", @"ClassDump", @"Dump"];
        blocked = @[@"Alert", @"Popup", @"Coin", @"Reward"];
    }
    for (NSString *k in allow) {
        if ([cls rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
            %orig;
            return;
        }
    }
    if ([vc isKindOfClass:[UIAlertController class]]) {
        %orig;
        return;
    }
    for (NSString *k in blocked) {
        if ([cls rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
    }
    %orig;
}
%end
