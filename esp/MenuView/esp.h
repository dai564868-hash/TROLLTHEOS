#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface MenuView : UIView

- (instancetype)initWithFrame:(CGRect)frame;
- (void)hideMenu;
- (void)showMenu;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)layoutSubviews;
- (void)centerMenu;

@end