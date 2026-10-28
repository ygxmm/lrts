#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdarg.h>

static void LALog(NSString *fmt, ...);

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

static void LALog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    LALog(@"%@", msg);
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!dir.length) return;
    NSString *path = [dir stringByAppendingPathComponent:@"lazyaudio-tweak.log"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

static BOOL gEnableTabBar = YES;
static BOOL gEnableSignButton = YES;
static BOOL gEnableSplash = YES;
static BOOL gEnablePopup = YES;

static Class gTabItemClass = Nil;
static char kLAIgnoredKey;

static NSDictionary *LALoadSwitches(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    NSString *home = NSHomeDirectory();
    if (home.length > 0) {
        [paths addObject:[home stringByAppendingPathComponent:@"Documents/switches.plist"]];
    }
    NSString *group = @"/var/mobile/Containers/Shared/AppGroup/C1A22E1E-A0E8-4602-B053-AFDDB8B982E0/Documents/switches.plist";
    [paths addObject:group];
    [paths addObject:@"/var/mobile/dyyy/lazyaudio-nosplash/switches.plist"];
    [paths addObject:@"/var/jb/var/mobile/dyyy/lazyaudio-nosplash/switches.plist"];

    for (NSString *p in paths) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if (d) {
            LALog(@"读取开关成功: %@", p);
            return d;
        }
    }
    LALog(@"未找到 switches.plist，尝试过: %@", paths);
    return nil;
}

__attribute__((constructor)) static void LAInitSwitches(void) {
    LALog(@"tweak loaded, home=%@", NSHomeDirectory());
    NSDictionary *d = LALoadSwitches();
    if (!d) {
        LALog(@"全部功能默认开启");
        return;
    }
    gEnableTabBar     = d[@"tabbar"]     ? [d[@"tabbar"] boolValue]     : YES;
    gEnableSignButton = d[@"signbutton"] ? [d[@"signbutton"] boolValue] : YES;
    gEnableSplash     = d[@"splash"]     ? [d[@"splash"] boolValue]     : YES;
    gEnablePopup      = d[@"popup"]      ? [d[@"popup"] boolValue]      : YES;
    LALog(@"开关 tabbar=%d sign=%d splash=%d popup=%d",
          gEnableTabBar, gEnableSignButton, gEnableSplash, gEnablePopup);
}

static BOOL LAIsTabItem(UIView *v) {
    if (!gTabItemClass) {
        gTabItemClass = objc_getClass("_TtC9lazyaudio14TabBarItemView");
    }
    return gTabItemClass && [v class] == gTabItemClass;
}

// ========== 1. 底栏重排（开关 tabbar）==========
%hook UIView
- (void)layoutSubviews {
    %orig;

    if (!gEnableTabBar) {
        return;
    }
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

// ========== 2. TabBarItemView 隐藏 tag==3（开关 tabbar）==========
%hook _TtC9lazyaudio14TabBarItemView
- (void)setTag:(NSInteger)tag {
    %orig;
    if (!gEnableTabBar) {
        return;
    }
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
- (void)didMoveToWindow {
    %orig;
    if (!gEnableTabBar) {
        return;
    }
    if (self.tag == 3) {
        self.hidden = YES;
        self.alpha = 0.0;
        self.userInteractionEnabled = NO;
    }
}
%end

// ========== 3. 签到按钮（开关 signbutton）==========
%hook _TtC9lazyaudio12MeSignButton
- (void)didMoveToWindow {
    %orig;
    if (!gEnableSignButton) {
        return;
    }
    self.hidden = YES;
    self.alpha = 0.0;
    self.userInteractionEnabled = NO;
}
%end

// ========== 4. 开屏 Window / VC（开关 splash）==========
%hook _TtC9lazyaudio18LaunchSplashWindow
- (void)setHidden:(BOOL)hidden {
    if (gEnableSplash) {
        hidden = YES;
    }
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    if (gEnableSplash) {
        self.hidden = YES;
    }
}
%end

%hook _TtC13Advertisement14SplashAdWindow
- (void)setHidden:(BOOL)hidden {
    if (gEnableSplash) {
        hidden = YES;
    }
    %orig;
}
- (void)makeKeyAndVisible {
    %orig;
    if (gEnableSplash) {
        self.hidden = YES;
    }
}
%end

%hook _TtC13Advertisement22SplashAdViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gEnableSplash) {
        return;
    }
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook TGGDTSplashViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gEnableSplash) {
        return;
    }
    self.view.hidden = YES;
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

// ========== 5. 弹窗拦截（开关 popup）==========
%hook UIViewController
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (!gEnablePopup || !vc) {
        %orig;
        return;
    }

    if ([vc isKindOfClass:[UIAlertController class]]) {
        %orig;
        return;
    }

    const char *name = class_getName([vc class]);

    static const char *allowWords[] = {"Probe", "FLEX", "Debug", "Inspector", "Console", "ClassDump", "Dump", NULL};
    for (int i = 0; allowWords[i]; i++) {
        if (strcasestr(name, allowWords[i])) {
            %orig;
            return;
        }
    }

    static const char *blockWords[] = {"Alert", "Popup", "Coin", "Reward", NULL};
    for (int i = 0; blockWords[i]; i++) {
        if (strcasestr(name, blockWords[i])) {
            LALog(@"拦截弹窗: %s", name);
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
            return;
        }
    }

    %orig;
}
%end
