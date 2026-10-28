#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 日志写入函数
static void writeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *path = @"/var/mobile/Documents/lazyaudio_probe.txt";
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, msg];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [logLine writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

// 递归遍历视图树
static void dumpView(UIView *view, int depth) {
    if (!view) return;
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    NSString *clsName = NSStringFromClass([view class]);
    
    // 只记录关键信息：类名、tag、hidden、frame
    writeLog(@"%@-> %@ | tag:%ld | hidden:%d | frame:%@", indent, clsName, (long)view.tag, view.hidden, NSStringFromCGRect(view.frame));
    
    for (UIView *sub in view.subviews) {
        dumpView(sub, depth + 1);
    }
}

// 定时扫描器
static void startProbe() {
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        writeLog(@"\n================ 开始扫描 ================");
        NSArray *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *win in windows) {
            writeLog(@"找到 Window: %@ | level:%f | hidden:%d", NSStringFromClass([win class]), win.windowLevel, win.hidden);
            
            // 如果是广告窗口或者层级很高的窗口，深度打印
            if ([NSStringFromClass([win class]) containsString:@"Splash"] || win.windowLevel > 0) {
                dumpView(win, 1);
            }
            
            // 找底栏
            for (UIView *sub in win.subviews) {
                if ([NSStringFromClass([sub class]) containsString:@"LMTabBar"] || [NSStringFromClass([sub class]) containsString:@"TabBarView"]) {
                    writeLog(@"--- 发现底栏 ---");
                    dumpView(sub, 1);
                }
            }
        }
        writeLog(@"================ 扫描结束 ================\n");
    }];
}

%ctor {
    // 延迟 3 秒启动，等待 App 和广告加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        writeLog(@"\n\n🎉 Tweak 探针已启动！");
        startProbe();
    });
}
