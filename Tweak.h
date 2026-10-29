#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <string.h>
#import <objc/message.h>

// ==========================================
// 1. 基础 UI 与 功能组件 声明
// ==========================================
@interface _TtC9lazyaudio14TabBarItemView : UIView
@end
@interface _TtC9lazyaudio12MeSignButton : UIView
@end
@interface _TtC9lazyaudio18LaunchSplashWindow : UIWindow
@end
@interface _TtC13Advertisement14SplashAdWindow : UIWindow
@end
@interface _TtC9lazyaudio25OnlineEarningNewLevitator : UIView
@end
@interface _TtC9lazyaudio24OnlineEarningNewTipsView : UIView
@end
@interface _TtC9lazyaudio19EarningTaskBallView : UIView
@end
@interface _TtC9lazyaudio20EarningTaskEntryView : UIView
@end
@interface _TtC9lazyaudio25OnlineEarningNewEntryView : UIView
@end

// ==========================================
// 2. 播放器与预加载 声明
// ==========================================
@interface AudioPlayerBridge : NSObject
+ (void)loadPlayerButNotAutoPlay;
@end

// ==========================================
// 3. Hippy 跨端渲染与弹窗 声明
// ==========================================
@interface HippyViewController : UIViewController
- (void)dialogViewDisplay:(id)arg;
- (void)dialogViewDismiss:(id)arg;
- (NSString *)pageName;
@end

// ==========================================
// 4. 弹窗拦截器 声明
// ==========================================
@interface AlertPool : NSObject
+ (void)add:(id)a0;
@end
@interface _TtC9lazyaudio18BaseAlertController : UIViewController
@end
@interface _TtC9lazyaudio20FreeModeTimeoutAlert : UIView
@end
@interface _TtC9lazyaudio17ReaderFreeAdAlert : UIView
@end
