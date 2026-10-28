#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void writeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths firstObject] stringByAppendingPathComponent:@"lazyaudio_probe.txt"];
    NSString *logLine = [NSString stringWithFormat:@"%@\n", msg];
    
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

// 递归寻找关键视图
static void findKeyViews(UIView *view, int depth) {
    if (!view || depth > 20) return; // 深度限制放宽到 20 层
    NSString *clsName = NSStringFromClass([view class]);
    
    // 只要类名带这些关键字，就重点记录
    NSArray *keys = @[@"TabBar", @"Splash", @"AdWindow", @"Earning", @"GDT"];
    BOOL isKey = NO;
    for (NSString *k in keys) {
        if ([clsName containsString:k]) {
            isKey = YES;
            break;
        }
    }
    
    if (isKey) {
        NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
        writeLog(@"%@-> %@ | tag:%ld | hidden:%d | frame:%@", indent, clsName, (long)view.tag, view.hidden, NSStringFromCGRect(view.frame));
    }
    
    for (UIView *sub in view.subviews) {
        findKeyViews(sub, isKey ? depth + 1 : depth); // 如果不是关键字，递归时不增加缩进，保持扁平
    }
}

static void startProbe() {
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        // 每次扫描前清空旧日志，只保留最新状态，防止文件过大
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [[paths firstObject] stringByAppendingPathComponent:@"lazyaudio_probe.txt"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        
        writeLog(@"\n================ 开始扫描 ================");
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            writeLog(@"Window: %@ | level:%f | hidden:%d", NSStringFromClass([win class]), win.windowLevel, win.hidden);
            findKeyViews(win, 1);
        }
        writeLog(@"================ 扫描结束 ================\n");
    }];
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        startProbe();
    });
}
