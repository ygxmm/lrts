#import <UIKit/UIKit.h>

@interface _TtC9lazyaudio10TabBarView : UIView
@end
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

// ========== 1. 底栏重排：父视图布局后手动修正 4 个可见 item ==========
%hook _TtC9lazyaudio10TabBarView
- (void)layoutSubviews {
    %orig;

    NSMutableArray<UIView *> *visibleItems = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"TabBarItemView"]) {
            if (sub.tag == 3) {
                sub.hidden = YES;
                sub.alpha = 0.0;
                sub.userInteractionEnabled = NO;
                sub.frame = CGRectZero;
            } else {
                [visibleItems addObject:sub];
            }
        }
    }

    NSUInteger count = visibleItems.count;
    if (count == 0) return;

    CGFloat totalW = self.bounds.size.width;
    if (totalW <= 0) return;

    UIView *firstItem = visibleItems.firstObject;
    CGFloat itemY = firstItem.frame.origin.y;
    CGFloat itemH = firstItem.frame.size.height;
    if (itemH <= 0) itemH = self.bounds.size.height;
    CGFloat itemW = totalW / (CGFloat)count;

    for (NSUInteger i = 0; i < count; i++) {
        UIView *item = visibleItems[i];
        item.frame = CGRectMake(itemW * (CGFloat)i, itemY, itemW, itemH);
    }
}
%end

// ========== 2. TabBarItemView 兜底 ==========
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
    }
}
- (void)setFrame:(CGRect)frame {
    if (self.tag == 3) {
        frame = CGRectZero;
    }
    %orig;
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

// ========== 5. 弹窗拦截 ==========
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!viewControllerToPresent) {
        %orig;
        return;
    }
    NSString *className = NSStringFromClass([viewControllerToPresent class]);
    NSArray<NSString *> *blockedKeywords = @[@"Alert", @"Popup", @"Coin", @"Reward"];
    for (NSString *keyword in blockedKeywords) {
        if ([className rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
    }
    %orig;
}
%end
