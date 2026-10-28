#import <UIKit/UIKit.h>

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

static BOOL IsTabBarItemView(UIView *v) {
    NSString *cls = NSStringFromClass([v class]);
    return [cls containsString:@"TabBarItemView"] && ![cls containsString:@"Player"];
}

// ========== 1. 全局布局修正 ==========
%hook UIView
- (void)layoutSubviews {
    %orig;

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        if (IsTabBarItemView(sub)) {
            [items addObject:sub];
        }
    }
    if (items.count < 2) {
        return;
    }

    NSMutableArray<UIView *> *visible = [NSMutableArray array];
    for (UIView *item in items) {
        if (item.tag == 3) {
            item.hidden = YES;
            item.alpha = 0.0;
            item.userInteractionEnabled = NO;
            item.frame = CGRectZero;
        } else {
            [visible addObject:item];
        }
    }

    NSUInteger count = visible.count;
    if (count == 0) {
        return;
    }

    CGFloat totalW = self.bounds.size.width;
    if (totalW <= 0) {
        return;
    }

    UIView *first = visible.firstObject;
    CGFloat y = first.frame.origin.y;
    CGFloat h = first.frame.size.height;
    if (h <= 0) {
        h = self.bounds.size.height;
    }
    CGFloat w = totalW / (CGFloat)count;

    for (NSUInteger i = 0; i < count; i++) {
        UIView *item = visible[i];
        item.frame = CGRectMake(w * (CGFloat)i, y, w, h);
    }
}
%end

// ========== 2. TabBarItemView 兜底隐藏 + 触发重排 ==========
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
        [self.superview setNeedsLayout];
    }
}
- (void)didMoveToWindow {
    %orig;
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
        [self.superview setNeedsLayout];
    }
}
%end

// ========== 3. 签到按钮 ==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

// ========== 4. 开屏 Window 拦截 ==========
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

// ========== 5. 弹窗拦截（放行探针） ==========
%hook UIViewController
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!vc) {
        %orig;
        return;
    }

    NSString *cls = NSStringFromClass([vc class]);

    NSArray *allow = @[@"Probe", @"FLEX", @"Debug", @"Inspector", @"Console", @"ClassDump", @"Dump"];
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

    NSArray *blocked = @[@"Alert", @"Popup", @"Coin", @"Reward"];
    for (NSString *k in blocked) {
        if ([cls rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
    }
    %orig;
}
%end
