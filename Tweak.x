#import <UIKit/UIKit.h>

%hook UIViewController
- (void)viewDidLoad {
    %orig;
}
%end
