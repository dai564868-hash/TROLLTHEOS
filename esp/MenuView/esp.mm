#import "esp.h"
#import "mahoa.h"
#import "../lib/pid.h"
#import "../lib/libUE4.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h> 
#include <sys/mman.h>
#include <string>
#include <vector>
#include <cmath>

mach_vm_address_t LDVQuangBase;
static Vector2 CanvasSize;

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

long GWorld;
static MinimalViewInfo POV;

static bool isBox = YES;
static bool isBone = YES;
static bool isHealth = YES;
static bool isName = YES;
static bool isDis = YES;

@interface CustomSwitch : UIControl
@property (nonatomic, assign, getter=isOn) BOOL on;
@end

@implementation CustomSwitch { UIView *_thumb; }
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _thumb = [[UIView alloc] initWithFrame:CGRectMake(2, 2, 22, 22)];
        _thumb.backgroundColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        _thumb.layer.cornerRadius = 11;
        [self addSubview:_thumb];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
        [self addGestureRecognizer:tap];
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.bounds.size.height/2];
    CGContextSetFillColorWithColor(context, (self.isOn ? [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor colorWithWhite:0.15 alpha:1.0]).CGColor); // Xanh lá khi bật
    [path fill];
}
- (void)setOn:(BOOL)on {
    if (_on != on) { _on = on; [self setNeedsDisplay]; [self updateThumbPosition]; }
}
- (void)toggle {
    self.on = !self.on;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)updateThumbPosition {
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self->_thumb.frame;
        frame.origin.x = self.isOn ? self.bounds.size.width - frame.size.width - 2 : 2;
        self->_thumb.frame = frame;
        self->_thumb.backgroundColor = self.isOn ? UIColor.whiteColor : [UIColor colorWithWhite:0.75 alpha:1.0];
    }];
}
@end

// core main

@interface MenuView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray<CALayer *> *drawingLayers;
@end

@implementation MenuView {
    UIView *menuContainer;
    UIView *floatingButton;
    CGPoint _initialTouchPoint;
    
    UIView *previewView;
    UIView *previewContentContainer;
    
    // Các container cho Preview
    UILabel *previewNameLabel;
    UILabel *previewDistLabel;
    UIView *healthBarContainer;
    UIView *boxContainer;
    UIView *skeletonContainer;
    
    float previewScale;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.drawingLayers = [NSMutableArray array];
        
        [self SetUpBase];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

        [self setupFloatingButton];
        [self setupMenuUI];
        [self layoutSubviews];
    }
    return self;
}

- (void)setupFloatingButton {
    floatingButton = [[UIView alloc] initWithFrame:CGRectMake(50, 50, 50, 50)];
    floatingButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0];
    floatingButton.layer.cornerRadius = 25;
    floatingButton.layer.borderWidth = 2;
    floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    floatingButton.clipsToBounds = YES;
    
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:floatingButton.bounds];
    iconLabel.text = @"M";
    iconLabel.textColor = [UIColor whiteColor];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.font = [UIFont boldSystemFontOfSize:20];
    [floatingButton addSubview:iconLabel];
    
    UITapGestureRecognizer *openTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu)];
    [floatingButton addGestureRecognizer:openTap];
    
    UIPanGestureRecognizer *iconPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingButton addGestureRecognizer:iconPan];
    
    [self addSubview:floatingButton];
}

- (void)addFeatureToView:(UIView *)view withTitle:(NSString *)title atY:(CGFloat)y initialValue:(BOOL)isOn andAction:(SEL)action {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 150, 26)];
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    [view addSubview:label];
    
    CustomSwitch *customSwitch = [[CustomSwitch alloc] initWithFrame:CGRectMake(240, y, 52, 26)];
    customSwitch.on = isOn;
    [customSwitch addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [view addSubview:customSwitch];
}

- (void)setupMenuUI {
    CGFloat menuWidth = 550;
    CGFloat menuHeight = 320;
    
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.95];
    menuContainer.layer.cornerRadius = 15;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor;
    menuContainer.layer.borderWidth = 2;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;
    [self addSubview:menuContainer];
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 40)];
    headerView.backgroundColor = [UIColor clearColor];
    [menuContainer addSubview:headerView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 5, 200, 30)];
    titleLabel.text = @"MENU TIPA";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:22];
    [headerView addSubview:titleLabel];
    
    UILabel *subTitle = [[UILabel alloc] initWithFrame:CGRectMake(350, 12, 150, 20)];
    subTitle.text = @"Cheat by LDVQuang";
    subTitle.textColor = [UIColor lightGrayColor];
    subTitle.font = [UIFont systemFontOfSize:10];
    [headerView addSubview:subTitle];
    
    // Buttons (Close, Min, etc.)
    NSArray *colors = @[[UIColor greenColor], [UIColor yellowColor], [UIColor redColor]];
    for (int i = 0; i < 3; i++) {
        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(menuWidth - 80 + (i * 25), 10, 18, 18)];
        circle.backgroundColor = colors[i];
        circle.layer.cornerRadius = 9;
        
        UILabel *btnIcon = [[UILabel alloc] initWithFrame:circle.bounds];
        btnIcon.textAlignment = NSTextAlignmentCenter;
        btnIcon.font = [UIFont boldSystemFontOfSize:12];
        btnIcon.textColor = [UIColor blackColor];
        
        if (i == 0) btnIcon.text = @"□";
        if (i == 1) btnIcon.text = @"-";
        if (i == 2) {
            btnIcon.text = @"X";
            UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideMenu)];
            [circle addGestureRecognizer:closeTap];
        }
        [circle addSubview:btnIcon];
        [headerView addSubview:circle];
    }
    
    UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [headerView addGestureRecognizer:menuPan];
    
    UIView *previewBorder = [[UIView alloc] initWithFrame:CGRectMake(15, 50, 130, 250)];
    previewBorder.layer.borderColor = [UIColor whiteColor].CGColor;
    previewBorder.layer.borderWidth = 1;
    previewBorder.layer.cornerRadius = 10;
    [menuContainer addSubview:previewBorder];
    
    UILabel *pvTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 130, 20)];
    pvTitle.text = @"Preview";
    pvTitle.textColor = [UIColor whiteColor];
    pvTitle.textAlignment = NSTextAlignmentCenter;
    pvTitle.font = [UIFont boldSystemFontOfSize:14];
    [previewBorder addSubview:pvTitle];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, 28, 110, 1)];
    line.backgroundColor = [UIColor whiteColor];
    [previewBorder addSubview:line];
    
    previewView = [[UIView alloc] initWithFrame:CGRectMake(0, 30, 130, 220)];
    previewView.backgroundColor = [UIColor blackColor];
    previewView.clipsToBounds = YES;
    [previewBorder addSubview:previewView];
    
    previewContentContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewView addSubview:previewContentContainer];
    
    [self drawPreviewElements];
    
    [self updatePreviewVisibility];

    UILabel *previewNote = [[UILabel alloc] initWithFrame:CGRectMake(15, 305, 130, 15)];
    previewNote.text = @"Preview khi bật chức năng";
    previewNote.textColor = [UIColor lightGrayColor];
    previewNote.textAlignment = NSTextAlignmentCenter;
    previewNote.font = [UIFont systemFontOfSize:9];
    [menuContainer addSubview:previewNote];

    UIView *featureBox = [[UIView alloc] initWithFrame:CGRectMake(155, 50, 300, 250)];
    featureBox.layer.borderColor = [UIColor whiteColor].CGColor;
    featureBox.layer.borderWidth = 1;
    featureBox.layer.cornerRadius = 10;
    featureBox.backgroundColor = [UIColor blackColor];
    [menuContainer addSubview:featureBox];
    
    UILabel *ftTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 200, 20)];
    ftTitle.text = @"ESP Feature";
    ftTitle.textColor = [UIColor whiteColor];
    ftTitle.font = [UIFont boldSystemFontOfSize:16];
    [featureBox addSubview:ftTitle];
    
    UIView *ftLine = [[UIView alloc] initWithFrame:CGRectMake(15, 35, 270, 1)];
    ftLine.backgroundColor = [UIColor whiteColor];
    [featureBox addSubview:ftLine];
    
    [self addFeatureToView:featureBox withTitle:@"Box" atY:45 initialValue:isBox andAction:@selector(toggleBox:)];
    [self addFeatureToView:featureBox withTitle:@"Bone" atY:80 initialValue:isBone andAction:@selector(toggleBone:)];
    [self addFeatureToView:featureBox withTitle:@"Health" atY:115 initialValue:isHealth andAction:@selector(toggleHealth:)];
    [self addFeatureToView:featureBox withTitle:@"Name" atY:150 initialValue:isName andAction:@selector(toggleName:)];
    [self addFeatureToView:featureBox withTitle:@"Distance" atY:185 initialValue:isDis andAction:@selector(toggleDist:)];

    UILabel *sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 220, 40, 20)];
    sliderLabel.text = @"Size:";
    sliderLabel.textColor = [UIColor whiteColor];
    sliderLabel.font = [UIFont systemFontOfSize:12];
    [featureBox addSubview:sliderLabel];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(55, 220, 225, 20)];
    slider.minimumValue = 0.5;
    slider.maximumValue = 1.3;
    slider.value = 1.0;
    slider.thumbTintColor = [UIColor whiteColor];
    slider.minimumTrackTintColor = [UIColor greenColor];
    slider.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [featureBox addSubview:slider];
    
    UIView *sidebar = [[UIView alloc] initWithFrame:CGRectMake(465, 50, 75, 250)];
    sidebar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    sidebar.layer.cornerRadius = 10;
    [menuContainer addSubview:sidebar];
    
    NSArray *tabs = @[@"Main", @"AIM", @"Setting"];
    for (int i = 0; i < tabs.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(5, 10 + (i * 50), 65, 35);
        btn.backgroundColor = (i == 0) ? [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0] : [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
        [btn setTitle:tabs[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.layer.cornerRadius = 17.5;
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [sidebar addSubview:btn];
    }
}

- (void)drawPreviewElements {
    CGFloat w = previewView.frame.size.width;  
    CGFloat h = previewView.frame.size.height; 
    CGFloat cx = w / 2;
    CGFloat startY = 45; 
    
    // 1. NAME
    previewNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, w, 15)];
    previewNameLabel.text = @"ID PlayerName";
    previewNameLabel.textColor = [UIColor greenColor];
    previewNameLabel.textAlignment = NSTextAlignmentCenter;
    previewNameLabel.font = [UIFont boldSystemFontOfSize:11];
    [previewContentContainer addSubview:previewNameLabel];
    
    // 2. HEALTH
    CGFloat barW = 70;
    healthBarContainer = [[UIView alloc] initWithFrame:CGRectMake(cx - barW/2, 38, barW, 2)];
    healthBarContainer.backgroundColor = [UIColor greenColor];
    [previewContentContainer addSubview:healthBarContainer];
    
    // 3. BOX
    CGFloat boxW = 70;
    CGFloat boxH = 130;
    CGFloat bx = cx - boxW/2;
    CGFloat by = startY;
    
    boxContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewContentContainer addSubview:boxContainer];
    
    CGFloat lineLen = 15;
    UIColor *boxColor = [UIColor whiteColor];
    [self addLineRect:CGRectMake(bx, by, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW - lineLen, by, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW, by, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by + boxH, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by + boxH - lineLen, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW - lineLen, by + boxH, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW, by + boxH - lineLen, 1, lineLen) color:boxColor parent:boxContainer];

    // 4. SKELETON
    skeletonContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewContentContainer addSubview:skeletonContainer];
    
    UIColor *skelColor = [UIColor whiteColor];
    CGFloat skelThick = 1.0;
    
    CGFloat headRad = 7;
    CGFloat headY = by + 15;
    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(cx - headRad, headY - headRad, headRad*2, headRad*2)];
    head.layer.borderColor = skelColor.CGColor;
    head.layer.borderWidth = skelThick;
    head.layer.cornerRadius = headRad;
    [skeletonContainer addSubview:head];
    
    CGPoint pNeck = CGPointMake(cx, headY + headRad);
    CGPoint pPelvis = CGPointMake(cx, by + 65);
    CGPoint pShoulderL = CGPointMake(cx - 15, by + 30);
    CGPoint pShoulderR = CGPointMake(cx + 15, by + 30);
    CGPoint pElbowL = CGPointMake(cx - 20, by + 50);
    CGPoint pElbowR = CGPointMake(cx + 20, by + 50);
    CGPoint pHandL = CGPointMake(cx - 20, by + 70);
    CGPoint pHandR = CGPointMake(cx + 20, by + 70);
    CGPoint pKneeL = CGPointMake(cx - 12, by + 95);
    CGPoint pKneeR = CGPointMake(cx + 12, by + 95);
    CGPoint pFootL = CGPointMake(cx - 15, by + 125);
    CGPoint pFootR = CGPointMake(cx + 15, by + 125);
    
    [self addLineFrom:pNeck to:pPelvis color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderL to:pShoulderR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:CGPointMake(cx, by+30) to:pShoulderL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderL to:pElbowL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pElbowL to:pHandL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:CGPointMake(cx, by+30) to:pShoulderR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderR to:pElbowR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pElbowR to:pHandR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pPelvis to:pKneeL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pKneeL to:pFootL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pPelvis to:pKneeR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pKneeR to:pFootR color:skelColor width:skelThick inView:skeletonContainer];
    
    // 5. DISTANCE
    previewDistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, by + boxH + 5, w, 15)];
    previewDistLabel.text = @"Distance";
    previewDistLabel.textColor = [UIColor whiteColor];
    previewDistLabel.textAlignment = NSTextAlignmentCenter;
    previewDistLabel.font = [UIFont systemFontOfSize:10];
    [previewContentContainer addSubview:previewDistLabel];
}

- (void)updatePreviewVisibility {
    boxContainer.hidden = !isBox;
    skeletonContainer.hidden = !isBone;
    healthBarContainer.hidden = !isHealth;
    previewNameLabel.hidden = !isName;
    previewDistLabel.hidden = !isDis;
    
    if (isBox && isBone) {
        [previewContentContainer bringSubviewToFront:boxContainer];
    }
}

- (void)toggleBox:(CustomSwitch *)sender {
    isBox = sender.isOn;
    boxContainer.hidden = !isBox;
}

- (void)toggleBone:(CustomSwitch *)sender {
    isBone = sender.isOn;
    skeletonContainer.hidden = !isBone;
}

- (void)toggleHealth:(CustomSwitch *)sender {
    isHealth = sender.isOn;
    healthBarContainer.hidden = !isHealth;
}

- (void)toggleName:(CustomSwitch *)sender {
    isName = sender.isOn;
    previewNameLabel.hidden = !isName;
}

- (void)toggleDist:(CustomSwitch *)sender {
    isDis = sender.isOn;
    previewDistLabel.hidden = !isDis;
}

// Helpers
- (void)addLineRect:(CGRect)frame color:(UIColor *)color parent:(UIView *)parent {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = color;
    [parent addSubview:v];
}
- (void)addLineFrom:(CGPoint)p1 to:(CGPoint)p2 color:(UIColor *)color width:(CGFloat)width inView:(UIView *)view {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = color;
    CGFloat dx = p2.x - p1.x;
    CGFloat dy = p2.y - p1.y;
    CGFloat len = sqrt(dx*dx + dy*dy);
    CGFloat angle = atan2(dy, dx);
    line.frame = CGRectMake(p1.x, p1.y, len, width);
    line.layer.anchorPoint = CGPointMake(0, 0.5);
    line.center = p1;
    line.transform = CGAffineTransformMakeRotation(angle);
    [view addSubview:line];
}

- (void)sliderValueChanged:(UISlider *)sender {
    previewScale = sender.value;
    [UIView animateWithDuration:0.1 animations:^{
        self->previewContentContainer.transform = CGAffineTransformMakeScale(self->previewScale, self->previewScale);
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
    CGRect screenBounds = self.bounds;
    if (!menuContainer.hidden) {
        menuContainer.center = CGPointMake(screenBounds.size.width / 2, screenBounds.size.height / 2);
    }
    CGPoint btnCenter = floatingButton.center;
    CGFloat halfW = floatingButton.bounds.size.width / 2;
    CGFloat halfH = floatingButton.bounds.size.height / 2;
    if (btnCenter.x < halfW) btnCenter.x = halfW;
    if (btnCenter.x > screenBounds.size.width - halfW) btnCenter.x = screenBounds.size.width - halfW;
    if (btnCenter.y < halfH) btnCenter.y = halfH;
    if (btnCenter.y > screenBounds.size.height - halfH) btnCenter.y = screenBounds.size.height - halfH;
    floatingButton.center = btnCenter;
}

- (void)showMenu {
    menuContainer.hidden = NO;
    floatingButton.hidden = YES;
    menuContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
    [self centerMenu];
    [UIView animateWithDuration:0.3 animations:^{
        self->menuContainer.transform = CGAffineTransformIdentity;
    }];
    [self updatePreviewVisibility];
}

- (void)hideMenu {
    [UIView animateWithDuration:0.3 animations:^{
        self->menuContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        self->menuContainer.hidden = YES;
        self->floatingButton.hidden = NO;
        self->menuContainer.transform = CGAffineTransformIdentity;
    }];
}

- (void)centerMenu {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    menuContainer.center = CGPointMake(screenBounds.size.width / 2, screenBounds.size.height / 2);
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint touchPoint = [gesture locationInView:self];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _initialTouchPoint = touchPoint;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaX = touchPoint.x - _initialTouchPoint.x;
        CGFloat deltaY = touchPoint.y - _initialTouchPoint.y;
        UIView *viewToMove = (gesture.view == floatingButton) ? floatingButton : menuContainer;
        viewToMove.center = CGPointMake(viewToMove.center.x + deltaX, viewToMove.center.y + deltaY);
        _initialTouchPoint = touchPoint;
    }
}

// get base binary game here
- (void)SetUpBase {
    pid_t pid = get_pid_by_name("DeltaForceClient");
    if (pid > 0){
        initialize_task_port(pid);
        task_t task = global_task_port;
        if (task != MACH_PORT_NULL) {
            LDVQuangBase = get_image_base_address(task, "DeltaForceClient");
        }
    }
}

- (void)updateFrame {
    if (!self.window) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in self.drawingLayers) {
        [layer removeFromSuperlayer];
    }
    [self.drawingLayers removeAllObjects];
    
    // call ESP
    RenderESP(self.drawingLayers);
    
    for (CALayer *layer in self.drawingLayers) {
        [self.layer addSublayer:layer];
    }
    [CATransaction commit];
    [self setNeedsDisplay];
}

- (void)dealloc {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

static void RenderESP(NSMutableArray<CALayer *> *layers) {
    CanvasSize.X = kWidth;
    CanvasSize.Y = kHeight;
    GWorld = QuangRead<long>(LDVQuangBase + 0x12DC0E48);
    if (!IsValidAddress(GWorld)) return;
    
    // Tại đây bạn sử dụng các biến toàn cục isBox, isBone để vẽ ESP thực tế
    // Ví dụ:
    // if (isBox) { /* Code vẽ Box */ }
    // if (isBone) { /* Code vẽ Bone */ }

    // Logic esp here (quang dep trai vcl dm tipa)
}

/*
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* ________________________________________LDVQuang__________________________________________________
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* 
* 
* create on 31/12/2025 by @quangmodmap
*/

@end