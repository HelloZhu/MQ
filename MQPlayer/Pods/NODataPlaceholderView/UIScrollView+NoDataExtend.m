//
//  UIScrollView+NoDataExtend.m
//  NODataPlaceholderView
//
//  Created by alpface on 2017/5/29.
//  Copyright © 2017年 alpface. All rights reserved.
//

#import "UIScrollView+NoDataExtend.h"
#import <objc/runtime.h>

typedef NSString * ImplementationKey NS_EXTENSIBLE_STRING_ENUM;

static const CGFloat NoDataPlaceholderHorizontalSpaceRatioValue = 16.0;

#pragma mark *** _WeakObjectContainer ***

@interface _WeakObjectContainer : NSObject

@property (nonatomic, weak, readonly) id weakObject;

- (instancetype)initWithWeakObject:(__weak id)weakObject;

@end

#pragma mark *** _SwizzlingObject ***

@interface _SwizzlingObject : NSObject

@property (nonatomic) Class swizzlingClass;
@property (nonatomic) SEL orginSelector;
@property (nonatomic) SEL swizzlingSelector;
@property (nonatomic) NSValue *swizzlingImplPointer;

@end

@interface NSObject (SwizzlingExtend)

@property (nonatomic, class, readonly) NSMutableDictionary<ImplementationKey, _SwizzlingObject *> *implementationDictionary;

- (Class)xy_baseClassToSwizzling;
- (void)hockSelector:(SEL)orginSelector swizzlingSelector:(SEL)swizzlingSelector;

@end

@interface UIView (NoDataPlaceholderViewEdgeInsetsExtend)

@property (nonatomic) UIEdgeInsets noDataPlaceholderViewContentEdgeInsets;

@end

#pragma mark *** NoDataPlaceholderView ***

@interface NoDataPlaceholderView : UIView

/** 内容视图 */
@property (nonatomic, weak) UIView *contentView;
/** 标题label */
@property (nonatomic, weak) UILabel *titleLabel;
/** 详情label */
@property (nonatomic, weak) UILabel *detailLabel;
/** 图片视图 */
@property (nonatomic, weak) UIImageView *imageView;
/** 重新加载的button */
@property (nonatomic, weak) UIButton *reloadButton;
/** 自定义视图 */
@property (nonatomic, strong) UIView *customView;
/** 点按手势 */
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
/** self顶部距离父控件scrollView 顶部的偏移量 */
@property (nonatomic, assign) CGFloat contentOffsetY;
/** self顶部距离父控件scrollView 左侧的偏移量 */
@property (nonatomic, assign) CGFloat contentOffsetX;
/** contentView 左右距离父控件的间距 */
@property (nonatomic, assign) CGFloat contentViewHorizontalSpace;
/** 所有子控件之间垂直间距 */
@property (nonatomic, assign) CGFloat globalVerticalSpace;
/** 各子控件之间的边距，若设置此边距则 */
@property (nonatomic, assign) UIEdgeInsets titleEdgeInsets;
@property (nonatomic, assign) UIEdgeInsets imageEdgeInsets;
@property (nonatomic, assign) UIEdgeInsets detailEdgeInsets;
@property (nonatomic, assign) UIEdgeInsets buttonEdgeInsets;
/** imageView的size, 有的时候图片本身太大，导致imageView的尺寸并不是我们想要的，可以通过此方法设置, 当为CGSizeZero时不设置,默认为CGSizeZero */
@property (nonatomic, assign) CGSize imageViewSize;
@property (nonatomic, assign) UIScrollViewNoDataContentLayouAttribute contentLayouAttribute;
/** tap手势回调block */
@property (nonatomic, copy) void (^tapGestureRecognizerBlock)(UITapGestureRecognizer *tap);

@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *viewsConstraints;

/// 移除所有子控件及其约束
- (void)resetSubviews;
/// 设置tap手势
- (void)tapGestureRecognizer:(void (^)(UITapGestureRecognizer *))tapBlock;

- (instancetype)initWithView:(UIView *)view;
+ (instancetype)showTo:(UIView *)view animated:(BOOL)animated;
@end

#pragma mark *** UIScrollView (NoDataPlaceholder) ***

@interface UIScrollView () <UIGestureRecognizerDelegate>

@property (nonatomic, readonly) NoDataPlaceholderView *noDataPlaceholderView;
@property (nonatomic, assign) BOOL registerNoDataPlaceholder;
//@property (nonatomic, assign) NoDataPlaceholderDelegateFlags delegateFlags;

@property (nonatomic, copy) UILabel * _Nullable(^noDataTextLabel)(void);
@property (nonatomic, copy) UILabel * _Nullable(^noDataDetailTextLabel)(void);
@property (nonatomic, copy) UIImageView * _Nullable(^noDataImageView)(void);
@property (nonatomic, copy) UIButton * _Nullable(^noDataReloadButton)(void);

@end

@implementation UIScrollView (NoDataExtend)

////////////////////////////////////////////////////////////////////////
#pragma mark - Private methods (delegate private api)
////////////////////////////////////////////////////////////////////////

// 是否需要淡入淡出
- (BOOL)xy_noDataPlacehodlerShouldFadeInOnDisplay {
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderShouldFadeInOnDisplay:)]) {
        return [self.noDataPlaceholderDelegate noDataPlaceholderShouldFadeInOnDisplay:self];
    }
    return YES;
}

// 是否符合显示
- (BOOL)xy_noDataPlacehodlerCanDisplay {
    if ([self isKindOfClass:[UITableView class]] ||
        [self isKindOfClass:[UICollectionView class]] ||
        [self isKindOfClass:[UIScrollView class]]) {
        return YES;
    }
    return NO;
}

// 获取UITableView或UICollectionView的所有item的总数
- (NSInteger)xy_itemCount {
    NSInteger itemCount = 0;
    
    if (![self respondsToSelector:@selector(dataSource)]) {
        return itemCount;
    }
    
    // UITableView
    if ([self isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)self;
        id<UITableViewDataSource> dataSource = tableView.dataSource;
        
        NSInteger sections = 1;
        if (dataSource && [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
            sections = [dataSource numberOfSectionsInTableView:tableView];
        }
        if (dataSource && [dataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)]) {
            // 遍历所有组获取每组的行数，就相加得到所有item的数量
            for (NSInteger section = 0; section < sections; ++section) {
                itemCount += [dataSource tableView:tableView numberOfRowsInSection:section];
            }
        }
    }
    
    // UICollectionView
    if ([self isKindOfClass:[UICollectionView class]]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
        
        NSInteger sections = 1;
        if (dataSource && [dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
            sections = [dataSource numberOfSectionsInCollectionView:collectionView];
        }
        if (dataSource && [dataSource respondsToSelector:@selector(collectionView:numberOfItemsInSection:)]) {
            // 遍历所有组获取每组的行数，就相加得到所有item的数量
            for (NSInteger section = 0; section < sections; ++section) {
                itemCount += [dataSource collectionView:collectionView numberOfItemsInSection:section];
            }
        }
    }
    
    return itemCount;
}

/// 是否应该显示
- (BOOL)xy_noDataPlacehodlerShouldDisplay {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderShouldDisplay:)]) {
        return [self.noDataPlaceholderDelegate noDataPlaceholderShouldDisplay:self];
    }
    return YES;
}

/// 是否应该强制显示,默认不需要的
- (BOOL)xy_noDataPlacehodlerShouldBeForcedToDisplay {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderShouldBeForcedToDisplay:)]) {
        return [self.noDataPlaceholderDelegate noDataPlaceholderShouldBeForcedToDisplay:self];
    }
    return NO;
}

- (void)xy_noDataPlaceholderViewWillAppear {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderWillAppear:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholderWillAppear:self];
    }
}

/// 是否允许响应事件
- (BOOL)xy_noDataPlacehodlerIsAllowedResponseEvent {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderShouldAllowResponseEvent:)]) {
        return [self.noDataPlaceholderDelegate noDataPlaceholderShouldAllowResponseEvent:self];
    }
    return YES;
}

/// 是否运行滚动
- (BOOL)xy_noDataPlacehodlerIsAllowedScroll  {
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderShouldAllowScroll:)]) {
        return [self.noDataPlaceholderDelegate noDataPlaceholderShouldAllowScroll:self];
    }
    return YES;
}


- (void)xy_noDataPlacehodlerDidAppear {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderDidAppear:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholderDidAppear:self];
    }
}

- (void)xy_noDataPlacehodlerWillDisappear {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderWillDisappear:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholderWillDisappear:self];
    }
}

- (void)xy_noDataPlacehodlerDidDisappear {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholderDidDisappear:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholderDidDisappear:self];
    }
}

- (void)setXy_loading:(BOOL)xy_loading {
    if (self.xy_loading == xy_loading) {
        return;
    }
    
    objc_setAssociatedObject(self, @selector(xy_loading), @(xy_loading), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self xy_reloadNoData];
    
}
- (BOOL)xy_loading {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}



////////////////////////////////////////////////////////////////////////
#pragma mark - Private methods (block privete api)
////////////////////////////////////////////////////////////////////////

- (UIView *)xy_noDataPlacehodlerCustomView {
    UIView *view = nil;
    if (self.customNoDataView) {
        view = self.customNoDataView();
    }
    else if (self.xy_loading) {
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityView startAnimating];
        return activityView;
    }
    if (view) {
        NSParameterAssert([view isKindOfClass:[UIView class]]);
        return view;
    }
    return view;
}


- (CGFloat)xy_noDataPlacehodlerGlobalVerticalSpace {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(contentSubviewsGlobalVerticalSpaceFoNoDataPlaceholder:)]) {
        return [self.noDataPlaceholderDelegate contentSubviewsGlobalVerticalSpaceFoNoDataPlaceholder:self];
    }
    return 10.0;
}

- (CGFloat)xy_noDataPlacehodlerContenViewHorizontalSpace {
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(contentViewHorizontalSpaceFoNoDataPlaceholder:)]) {
        return [self.noDataPlaceholderDelegate contentViewHorizontalSpaceFoNoDataPlaceholder:self];
    }
    return 0.0;
}


- (CGPoint)xy_noDataPlacehodlerContentOffset {
    CGPoint offset = CGPointZero;
    
    if (self.noDataPlaceholderDelegate &&
        [self.noDataPlaceholderDelegate respondsToSelector:@selector(contentOffsetForNoDataPlaceholder:)]) {
        offset = [self.noDataPlaceholderDelegate contentOffsetForNoDataPlaceholder:self];
    }
    else {
        if (self.xy_loading) {
            return CGPointMake(0.0, 80.0);
        }
    }
    return offset;
}

- (CGSize)xy_noDataPlaceholderImageViewSize {
    CGSize imageViewSize = CGSizeZero;
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(imageViewSizeForNoDataPlaceholder:)]) {
        imageViewSize = [self.noDataPlaceholderDelegate imageViewSizeForNoDataPlaceholder:self];
    }
    return imageViewSize;
}

- (UIScrollViewNoDataContentLayouAttribute)xy_contentLayouAttribute {
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(contentLayouAttributeOfNoDataPlaceholder:)]) {
        return [self.noDataPlaceholderDelegate contentLayouAttributeOfNoDataPlaceholder:self];
    }
    return UIScrollViewNoDataContentLayouAttributeCenterY;
}

- (UILabel *)xy_noDataPlacehodlerTitleLabel {
    UILabel *titleLabel = nil;
    if (self.noDataTextLabel) {
        titleLabel = self.noDataTextLabel();
    }
    else {
        titleLabel = self.noDataPlaceholderView.titleLabel;
    }
    if (titleLabel) {
        NSParameterAssert([titleLabel isKindOfClass:[UILabel class]]);
    }
    return titleLabel;
}

- (UILabel *)xy_noDataPlacehodlerDetailLabel {
    UILabel *detailLabel = nil;
    if (self.noDataDetailTextLabel) {
        detailLabel = self.noDataDetailTextLabel();
    }
    else {
        detailLabel = self.noDataPlaceholderView.detailLabel;
    }
    if (detailLabel) {
        NSParameterAssert([detailLabel isKindOfClass:[UILabel class]]);
    }
    return detailLabel;
}

- (UIImageView *)xy_noDataPlacehodlerImageView {
    UIImageView *imageView = nil;
    if (self.noDataImageView) {
        imageView = self.noDataImageView();
    }
    else {
        imageView = self.noDataPlaceholderView.imageView;
    }
    if (imageView) {
        NSParameterAssert([imageView isKindOfClass:[UIImageView class]]);
    }
    return imageView;
}

- (UIButton *)xy_noDataPlacehodlerReloadButton {
    UIButton *btn = nil;
    if (self.noDataReloadButton) {
        btn = self.noDataReloadButton();
    }
    else {
        btn = self.noDataPlaceholderView.reloadButton;
    }
    if (btn) {
        NSParameterAssert([btn isKindOfClass:[UIButton class]]);
    }
    return btn;
}

/// 点击NODataPlaceholderView contentView的回调
- (void)xy_didTapContentView:(UITapGestureRecognizer *)tap {
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholder:didTapOnContentView:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholder:self didTapOnContentView:tap];
    }
}

- (void)xy_clickReloadBtn:(UIButton *)btn {
    if (self.noDataPlaceholderDelegate && [self.noDataPlaceholderDelegate respondsToSelector:@selector(noDataPlaceholder:didClickReloadButton:)]) {
        [self.noDataPlaceholderDelegate noDataPlaceholder:self didClickReloadButton:btn];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Swizzling
////////////////////////////////////////////////////////////////////////

/// 由当前类所在的基类来完成Swizzling
/// 基类分别为：UITableView  UICollectionView  UIScrollView
- (Class)xy_baseClassToSwizzling {
    if ([self isKindOfClass:[UITableView class]]) {
        return [UITableView class];
    }
    if ([self isKindOfClass:[UICollectionView class]]) {
        return [UICollectionView class];
    }
    if ([self isKindOfClass:[UIScrollView class]]) {
        return [UIScrollView class];
    }
    return nil;
}


////////////////////////////////////////////////////////////////////////
#pragma mark - UIGestureRecognizerDelegate
////////////////////////////////////////////////////////////////////////


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer.view isEqual:self.noDataPlaceholderView]) {
        return [self xy_noDataPlacehodlerIsAllowedResponseEvent];
    }
    
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UIGestureRecognizer *tapGesture = self.noDataPlaceholderView.tapGesture;
    
    if ([gestureRecognizer isEqual:tapGesture] || [otherGestureRecognizer isEqual:tapGesture]) {
        return YES;
    }
    
    if ( (self.noDataPlaceholderDelegate != (id)self) && [self.noDataPlaceholderDelegate respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)]) {
        return [(id)self.noDataPlaceholderDelegate gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
    }
    
    return NO;
}



////////////////////////////////////////////////////////////////////////
#pragma mark - Public method (reload subviews)
////////////////////////////////////////////////////////////////////////

- (void)xy_beginLoading {
    [self setXy_loading:YES];
}

- (void)xy_endLoading {
    [self setXy_loading:NO];
}

- (void)xy_reloadNoData {
    
    if (![self xy_noDataPlacehodlerCanDisplay]) {
        return;
    }
    
    if (([self xy_noDataPlacehodlerShouldDisplay] && ![self xy_itemCount]) ||
        [self xy_noDataPlacehodlerShouldBeForcedToDisplay]) {
        
        // 通知代理即将显示
        [self xy_noDataPlaceholderViewWillAppear];
        
        NoDataPlaceholderView *noDataPlaceholderView = self.noDataPlaceholderView;
        if (!noDataPlaceholderView) {
            noDataPlaceholderView = [self setupNoDataPlaceholderView];
        }
        
        // 重置视图及其约束
        [noDataPlaceholderView resetSubviews];
        
        UIView *customView = [self xy_noDataPlacehodlerCustomView];
        if (customView) {
            noDataPlaceholderView.customView = customView;
        } else {
            
            // customView为nil时，则通过block回到获取子控件 设置
            if (self.noDataTextLabelBlock) {
                self.noDataTextLabelBlock(noDataPlaceholderView.titleLabel);
            } else {
                noDataPlaceholderView.titleLabel = [self xy_noDataPlacehodlerTitleLabel];
            }
            if (self.noDataDetailTextLabelBlock) {
                self.noDataDetailTextLabelBlock(noDataPlaceholderView.detailLabel);
            } else {
                noDataPlaceholderView.detailLabel = [self xy_noDataPlacehodlerDetailLabel];
            }
            
            if (self.noDataImageViewBlock) {
                self.noDataImageViewBlock(noDataPlaceholderView.imageView);
            } else {
                noDataPlaceholderView.imageView = [self xy_noDataPlacehodlerImageView];
            }
            
            if (self.noDataReloadButtonBlock) {
                self.noDataReloadButtonBlock(noDataPlaceholderView.reloadButton);
            } else {
                noDataPlaceholderView.reloadButton = [self xy_noDataPlacehodlerReloadButton];
            }
            
            // 设置子控件之间的边距
            noDataPlaceholderView.titleEdgeInsets = self.noDataTextEdgeInsets;
            noDataPlaceholderView.detailEdgeInsets = self.noDataDetailEdgeInsets;
            noDataPlaceholderView.imageEdgeInsets = self.noDataImageEdgeInsets;
            noDataPlaceholderView.buttonEdgeInsets = self.noDataButtonEdgeInsets;
            // 设置noDataPlaceholderView子控件垂直间的间距
            noDataPlaceholderView.globalVerticalSpace = [self xy_noDataPlacehodlerGlobalVerticalSpace];
            
        }
        
        noDataPlaceholderView.contentOffsetY = [self xy_noDataPlacehodlerContentOffset].y;
        noDataPlaceholderView.contentOffsetX = [self xy_noDataPlacehodlerContentOffset].x;
        noDataPlaceholderView.contentViewHorizontalSpace = [self xy_noDataPlacehodlerContenViewHorizontalSpace];
        noDataPlaceholderView.backgroundColor = [self xy_noDataPlacehodlerBackgroundColor];
        noDataPlaceholderView.contentView.backgroundColor = [self xy_noDataPlacehodlerContentBackgroundColor];
        noDataPlaceholderView.hidden = NO;
        noDataPlaceholderView.clipsToBounds = YES;
        noDataPlaceholderView.imageViewSize = [self xy_noDataPlaceholderImageViewSize];
        noDataPlaceholderView.contentLayouAttribute = [self xy_contentLayouAttribute];
        noDataPlaceholderView.userInteractionEnabled = [self xy_noDataPlacehodlerIsAllowedResponseEvent];
        
        [noDataPlaceholderView setNeedsUpdateConstraints];
        
        // 此方法会先检查动画当前是否启用，然后禁止动画，执行block块语句
        [UIView performWithoutAnimation:^{
            [noDataPlaceholderView layoutIfNeeded];
        }];
        
        self.scrollEnabled = [self xy_noDataPlacehodlerIsAllowedScroll];
        
        // 通知代理完全显示
        [self xy_noDataPlacehodlerDidAppear];
        
    } else {
        [self xy_removeNoDataPlacehodlerView];
    }
    
}


- (void)xy_removeNoDataPlacehodlerView {
    // 通知代理即将消失
    [self xy_noDataPlacehodlerWillDisappear];
    
    if (self.noDataPlaceholderView) {
        [self.noDataPlaceholderView resetSubviews];
        [self.noDataPlaceholderView removeFromSuperview];
        
        [self setNoDataPlaceholderView:nil];
    }
    
    self.scrollEnabled = YES;
    
    // 通知代理完全消失
    [self xy_noDataPlacehodlerDidDisappear];
}

- (UIColor *)xy_noDataPlacehodlerBackgroundColor {
    return self.noDataViewBackgroundColor ?: [UIColor clearColor];
}

- (UIColor *)xy_noDataPlacehodlerContentBackgroundColor {
    return self.noDataViewContentBackgroundColor ?: [UIColor clearColor];
}

- (BOOL)registerNoDataPlaceholder {
    
    BOOL flag = [objc_getAssociatedObject(self, _cmd) boolValue];
    if (!flag) {
        flag = NO;
        if (![self xy_noDataPlacehodlerCanDisplay]) {
            [self xy_removeNoDataPlacehodlerView];
        }
        else {
            flag = YES;
            [self setupNoDataPlaceholderView];
            
            // 对reloadData方法的实现进行处理, 为加载reloadData时注入额外的实现
            [self hockSelector:@selector(reloadData) swizzlingSelector:@selector(xy_reloadNoData)];
            
            if ([self isKindOfClass:[UITableView class]]) {
                [self hockSelector:@selector(endUpdates) swizzlingSelector:@selector(xy_reloadNoData)];
            }
        }
        objc_setAssociatedObject(self, _cmd, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return flag;
}

- (NoDataPlaceholderView *)setupNoDataPlaceholderView {
    NoDataPlaceholderView *view = self.noDataPlaceholderView;
    if (view == nil) {
        view = [NoDataPlaceholderView showTo:self animated:[self xy_noDataPlacehodlerShouldFadeInOnDisplay]];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        view.hidden = YES;
        view.tapGesture.delegate = self;
        __weak typeof(self) weakSelf = self;
        [view tapGestureRecognizer:^(UITapGestureRecognizer *tap) {
            [weakSelf xy_didTapContentView:tap];
        }];
        self.noDataPlaceholderView = view;
    }
    return view;
}


////////////////////////////////////////////////////////////////////////
#pragma mark - get
////////////////////////////////////////////////////////////////////////

- (NoDataPlaceholderView *)noDataPlaceholderView {
    return objc_getAssociatedObject(self, _cmd);
}

- (id<NoDataPlaceholderDelegate>)noDataPlaceholderDelegate {
    _WeakObjectContainer *container = objc_getAssociatedObject(self, _cmd);
    return container.weakObject;
}

- (UIView * _Nonnull (^)(void))customNoDataView {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (UILabel * _Nonnull (^)(void))noDataTextLabel {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (UILabel * _Nonnull (^)(void))noDataDetailTextLabel {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (UIImageView * _Nonnull (^)(void))noDataImageView {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (UIButton * _Nonnull (^)(void))noDataReloadButton {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (UIColor *)noDataViewBackgroundColor {
    return objc_getAssociatedObject(self, _cmd);
}

- (UIColor *)noDataViewContentBackgroundColor {
    return objc_getAssociatedObject(self, _cmd);
}


- (UIEdgeInsets)noDataTextEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, _cmd);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (UIEdgeInsets)noDataDetailEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, _cmd);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (UIEdgeInsets)noDataImageEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, _cmd);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (UIEdgeInsets)noDataButtonEdgeInsets {
    NSValue *value = objc_getAssociatedObject(self, _cmd);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsZero;
}


////////////////////////////////////////////////////////////////////////
#pragma mark - set
////////////////////////////////////////////////////////////////////////


- (void)setNoDataTextLabelBlock:(void (^)(UILabel * _Nonnull))noDataTextLabelBlock {
    objc_setAssociatedObject(self, @selector(noDataTextLabelBlock), noDataTextLabelBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}

- (void (^)(UILabel * _Nonnull))noDataTextLabelBlock {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setNoDataDetailTextLabelBlock:(void (^)(UILabel * _Nonnull))noDataDetailTextLabelBlock {
    objc_setAssociatedObject(self, @selector(noDataDetailTextLabelBlock), noDataDetailTextLabelBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}

- (void (^)(UILabel * _Nonnull))noDataDetailTextLabelBlock {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setNoDataImageViewBlock:(void (^)(UIImageView * _Nonnull))noDataImageViewBlock {
    objc_setAssociatedObject(self, @selector(noDataImageViewBlock), noDataImageViewBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}

- (void (^)(UIImageView * _Nonnull))noDataImageViewBlock {
    [self registerNoDataPlaceholder];
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setNoDataReloadButtonBlock:(void (^)(UIButton * _Nonnull))noDataReloadButtonBlock {
    objc_setAssociatedObject(self, @selector(noDataReloadButtonBlock), noDataReloadButtonBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}

- (void (^)(UIButton * _Nonnull))noDataReloadButtonBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCustomNoDataView:(UIView * _Nonnull (^)(void))customNoDataView {
    objc_setAssociatedObject(self, @selector(customNoDataView), customNoDataView, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}


- (void)setNoDataTextLabel:(UILabel * _Nonnull (^)(void))noDataTextLabel {
    objc_setAssociatedObject(self, @selector(noDataTextLabel), noDataTextLabel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}


- (void)setNoDataDetailTextLabel:(UILabel * _Nonnull (^)(void))noDataDetailTextLabel {
    objc_setAssociatedObject(self, @selector(noDataDetailTextLabel), noDataDetailTextLabel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}



- (void)setNoDataImageView:(UIImageView * _Nonnull (^)(void))noDataImageView {
    objc_setAssociatedObject(self, @selector(noDataImageView), noDataImageView, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}



- (void)setNoDataReloadButton:(UIButton * _Nonnull (^)(void))noDataReloadButton {
    objc_setAssociatedObject(self, @selector(noDataReloadButton), noDataReloadButton, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self registerNoDataPlaceholder];
}



- (void)setNoDataViewBackgroundColor:(UIColor *)noDataViewBackgroundColor {
    objc_setAssociatedObject(self, @selector(noDataViewBackgroundColor), noDataViewBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNoDataViewContentBackgroundColor:(UIColor *)noDataViewContentBackgroundColor {
    objc_setAssociatedObject(self, @selector(noDataViewContentBackgroundColor), noDataViewContentBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (void)setNoDataPlaceholderDelegate:(id<NoDataPlaceholderDelegate>)noDataPlaceholderDelegate {
    
    if (noDataPlaceholderDelegate == self.noDataPlaceholderDelegate) {
        return;
    }
    
    if (!noDataPlaceholderDelegate || ![self xy_noDataPlacehodlerCanDisplay]) {
        [self xy_removeNoDataPlacehodlerView];
    }
    _WeakObjectContainer *container = [[_WeakObjectContainer alloc] initWithWeakObject:noDataPlaceholderDelegate];
    objc_setAssociatedObject(self, @selector(noDataPlaceholderDelegate), container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self registerNoDataPlaceholder];
}

- (void)setNoDataPlaceholderView:(NoDataPlaceholderView *)noDataPlaceholderView {
    objc_setAssociatedObject(self, @selector(noDataPlaceholderView), noDataPlaceholderView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNoDataTextEdgeInsets:(UIEdgeInsets)noDataTextEdgeInsets {
    objc_setAssociatedObject(self, @selector(noDataTextEdgeInsets), [NSValue valueWithUIEdgeInsets:noDataTextEdgeInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNoDataDetailEdgeInsets:(UIEdgeInsets)noDataDetailEdgeInsets {
    objc_setAssociatedObject(self, @selector(noDataDetailEdgeInsets), [NSValue valueWithUIEdgeInsets:noDataDetailEdgeInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNoDataImageEdgeInsets:(UIEdgeInsets)noDataImageEdgeInsets {
    objc_setAssociatedObject(self, @selector(noDataImageEdgeInsets), [NSValue valueWithUIEdgeInsets:noDataImageEdgeInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNoDataButtonEdgeInsets:(UIEdgeInsets)noDataButtonEdgeInsets {
    objc_setAssociatedObject(self, @selector(noDataButtonEdgeInsets), [NSValue valueWithUIEdgeInsets:noDataButtonEdgeInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark *** NoDataPlaceholderView ***

@implementation NoDataPlaceholderView

@synthesize
contentView = _contentView,
titleLabel = _titleLabel,
detailLabel = _detailLabel,
imageView = _imageView,
reloadButton = _reloadButton,
customView = _customView,
titleEdgeInsets = _titleEdgeInsets,
detailEdgeInsets = _detailEdgeInsets,
imageEdgeInsets = _imageEdgeInsets,
buttonEdgeInsets = _buttonEdgeInsets;


////////////////////////////////////////////////////////////////////////
#pragma mark - Initialize
////////////////////////////////////////////////////////////////////////

+ (instancetype)showTo:(UIView *)view animated:(BOOL)animated {
    NoDataPlaceholderView *noDataView = [[self alloc] initWithView:view];
    [noDataView showAnimated:animated];
    return noDataView;
}

- (instancetype)initWithView:(UIView *)view {
    self = [self initWithFrame:view.bounds];
    if (!self) {
        return nil;
    }
    self.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.superview == nil) {
        if (([view isKindOfClass:[UITableView class]] || [view isKindOfClass:[UICollectionView class]]) &&
            [view.subviews count] > 1) {
            [view insertSubview:self atIndex:0];
        } else {
            [view addSubview:self];
        }
    }
    CGFloat widthConstant = 0.0;
    if ([view isKindOfClass:[UICollectionView class]]) {
        UICollectionView *collectionView = (UICollectionView *)view;
        widthConstant = collectionView.contentInset.left + collectionView.contentInset.right;
    }
    else if ([view isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)view;
        widthConstant = tableView.contentInset.left + tableView.contentInset.right;
    }
    
    NSMutableArray *selfArray = @[].mutableCopy;
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:widthConstant]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.0]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0.0]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0]];
    [selfArray addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0]];
    [NSLayoutConstraint activateConstraints:selfArray];
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    [self contentView];
    self.globalVerticalSpace = 10.0;
}

- (void)showAnimated:(BOOL)animated {
    void (^ animatedBlock)(void) = ^{
        _contentView.alpha = 1.0;
    };
    
    [UIView animateWithDuration:animated ? 0.3 : 0.0 animations:animatedBlock];
    
}


////////////////////////////////////////////////////////////////////////
#pragma mark - set
////////////////////////////////////////////////////////////////////////

- (void)setTitleEdgeInsets:(UIEdgeInsets)titleEdgeInsets {
    _titleEdgeInsets = titleEdgeInsets;
    _titleLabel.noDataPlaceholderViewContentEdgeInsets = titleEdgeInsets;
}

- (void)setImageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {
    _imageEdgeInsets = imageEdgeInsets;
    _imageView.noDataPlaceholderViewContentEdgeInsets = imageEdgeInsets;
}

- (void)setDetailEdgeInsets:(UIEdgeInsets)detailEdgeInsets {
    _detailEdgeInsets = detailEdgeInsets;
    _detailLabel.noDataPlaceholderViewContentEdgeInsets = detailEdgeInsets;
}

- (void)setButtonEdgeInsets:(UIEdgeInsets)buttonEdgeInsets {
    _buttonEdgeInsets = buttonEdgeInsets;
    _reloadButton.noDataPlaceholderViewContentEdgeInsets = buttonEdgeInsets;
}

- (void)setCustomView:(UIView *)customView {
    if ([_customView isEqual:customView]) {
        if (!customView.superview) {
            [self.contentView addSubview:_customView];
        }
        return;
    }
    
    if (_customView) {
        [_customView removeFromSuperview];
        _customView = nil;
    }
    _customView = customView;
    if (!customView) {
        return;
    }
    //    [customView removeConstraints:customView.constraints];
    _customView.translatesAutoresizingMaskIntoConstraints = NO;
    _customView.accessibilityIdentifier = @"customView";
    [self.contentView addSubview:_customView];
    
}


- (void)setImageView:(UIImageView *)imageView {
    if ([_imageView isEqual:imageView]) {
        return;
    }
    [_imageView removeFromSuperview];
    _imageView = nil;
    
    if (!imageView) {
        return;
    }
    
    [imageView removeConstraints:imageView.constraints];
    _imageView = imageView;
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.accessibilityIdentifier = @"imageView";
    [self.contentView addSubview:_imageView];
    
}

- (void)setTitleLabel:(UILabel *)titleLabel {
    
    if (_titleLabel == titleLabel) {
        return;
    }
    [_titleLabel removeFromSuperview];
    _titleLabel = nil;
    
    if (!titleLabel) {
        return;
    }
    [titleLabel removeConstraints:titleLabel.constraints];
    _titleLabel = titleLabel;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.accessibilityIdentifier = @"titleLabel";
    [self.contentView addSubview:_titleLabel];
}

- (void)setDetailLabel:(UILabel *)detailLabel {
    if (_detailLabel == detailLabel) {
        return;
    }
    [_detailLabel removeFromSuperview];
    _detailLabel = nil;
    
    if (!detailLabel) {
        return;
    }
    [detailLabel removeConstraints:detailLabel.constraints];
    _detailLabel = detailLabel;
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.accessibilityIdentifier = @"detailLabel";
    [self.contentView addSubview:_detailLabel];
}

- (void)setReloadButton:(UIButton *)reloadButton {
    if (_reloadButton == reloadButton) {
        return;
    }
    [_reloadButton removeFromSuperview];
    _reloadButton = nil;
    
    if (!reloadButton) {
        return;
    }
    [reloadButton removeConstraints:reloadButton.constraints];
    _reloadButton = reloadButton;
    _reloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    _reloadButton.accessibilityIdentifier = NSStringFromSelector(@selector(reloadButton));
    [_reloadButton addTarget:self action:@selector(clickReloadBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_reloadButton];
}


////////////////////////////////////////////////////////////////////////
#pragma mark - get
////////////////////////////////////////////////////////////////////////
- (UIView *)contentView {
    if (_contentView == nil) {
        UIView *contentView = [UIView new];
        contentView.translatesAutoresizingMaskIntoConstraints = NO;
        contentView.backgroundColor = [UIColor clearColor];
        contentView.userInteractionEnabled = YES;
        contentView.alpha = 0;
        contentView.accessibilityIdentifier = NSStringFromSelector(_cmd);
        _contentView = contentView;
        [self addSubview:contentView];
    }
    return _contentView;
}

- (UIImageView *)imageView {
    if (_imageView == nil) {
        UIImageView *imageView = [UIImageView new];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.userInteractionEnabled = NO;
        _imageView = imageView;
        _imageView.accessibilityIdentifier = NSStringFromSelector(_cmd);
        [[self contentView] addSubview:_imageView];
    }
    return _imageView;
}

- (UILabel *)titleLabel {
    if (_titleLabel == nil) {
        UILabel *titleLabel = [UILabel new];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont systemFontOfSize:27.0];
        titleLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        titleLabel.numberOfLines = 0;
        // 通过accessibilityIdentifier来定位元素,相当于这个控件的id
        titleLabel.accessibilityIdentifier = NSStringFromSelector(_cmd);
        _titleLabel = titleLabel;
        
        [[self contentView] addSubview:_titleLabel];
    }
    return _titleLabel;
}

- (UILabel *)detailLabel {
    if (_detailLabel == nil) {
        UILabel *detailLabel = [UILabel new];
        detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        detailLabel.backgroundColor = [UIColor clearColor];
        
        detailLabel.font = [UIFont systemFontOfSize:17.0];
        detailLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        detailLabel.textAlignment = NSTextAlignmentCenter;
        detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
        detailLabel.numberOfLines = 0;
        detailLabel.accessibilityIdentifier = NSStringFromSelector(_cmd);
        _detailLabel = detailLabel;
        
        [[self contentView] addSubview:_detailLabel];
    }
    return _detailLabel;
}

- (UIButton *)reloadButton {
    if (_reloadButton == nil) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.backgroundColor = [UIColor clearColor];
        btn.contentVerticalAlignment = UIControlContentHorizontalAlignmentCenter;
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [btn addTarget:self action:@selector(clickReloadBtn:) forControlEvents:UIControlEventTouchUpInside];
        _reloadButton = btn;
        [[self contentView] addSubview:btn];
    }
    return _reloadButton;
}

- (UITapGestureRecognizer *)tapGesture {
    if (_tapGesture == nil) {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureOnSelf:)];
        [self addGestureRecognizer:_tapGesture];
    }
    return _tapGesture;
}


- (BOOL)canShowImage {
    return _imageView.image && _imageView.superview;
}

- (BOOL)canShowTitle {
    return _titleLabel.text.length > 0 && _titleLabel.superview;
}

- (BOOL)canShowDetail {
    return _detailLabel.text.length > 0 && _detailLabel.superview;
}

- (BOOL)canShowReloadButton {
    if ([_reloadButton titleForState:UIControlStateNormal] || [_reloadButton attributedTitleForState:UIControlStateNormal].string.length > 0 || [_reloadButton imageForState:UIControlStateNormal]) {
        return _reloadButton.superview != nil;
    }
    return NO;
}

- (BOOL)canChangeInsets:(UIEdgeInsets)insets {
    return !UIEdgeInsetsEqualToEdgeInsets(insets, UIEdgeInsetsZero);
}

- (UIEdgeInsets)titleEdgeInsets {
    return _titleEdgeInsets = self.titleLabel.noDataPlaceholderViewContentEdgeInsets;
}

- (UIEdgeInsets)detailEdgeInsets {
    return _detailEdgeInsets = self.detailLabel.noDataPlaceholderViewContentEdgeInsets;
}

- (UIEdgeInsets)imageEdgeInsets {
    return _imageEdgeInsets = self.imageView.noDataPlaceholderViewContentEdgeInsets;
}

- (UIEdgeInsets)buttonEdgeInsets {
    return _buttonEdgeInsets = self.reloadButton.noDataPlaceholderViewContentEdgeInsets;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Events
////////////////////////////////////////////////////////////////////////

- (void)tapGestureRecognizer:(void (^)(UITapGestureRecognizer *))tapBlock {
    
    self.tapGestureRecognizerBlock = tapBlock;
}

/// 点击刷新按钮时处理事件
- (void)clickReloadBtn:(UIButton *)btn {
    SEL selector = NSSelectorFromString(@"xy_clickReloadBtn:");
    UIView *superView = self.superview;
    while (superView) {
        if ([superView isKindOfClass:[UIScrollView class]]) {
            [superView performSelector:selector withObject:btn afterDelay:0.0];
            superView = nil;
        }
        else {
            superView = superView.superview;
        }
    }
}

- (void)tapGestureOnSelf:(UITapGestureRecognizer *)tap {
    if (self.tapGestureRecognizerBlock) {
        self.tapGestureRecognizerBlock(tap);
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Auto Layout
////////////////////////////////////////////////////////////////////////
/// 移除所有约束
- (void)clearConstraints {
    //    [self.superview removeConstraints:self.constraints];
    //    [self removeConstraints:self.constraints];
    //    [_contentView removeConstraints:_contentView.constraints];
    if (_viewsConstraints.count) {
        [NSLayoutConstraint deactivateConstraints:_viewsConstraints];
    }
    
}

- (NSLayoutConstraint *)getSelfTopConstraint {
    NSArray *superViewConstraints = self.superview.constraints;
    if (!superViewConstraints.count) {
        return nil;
    }
    NSEnumerator *enumerator = superViewConstraints.reverseObjectEnumerator;
    NSLayoutConstraint *constraint = nil;
    while ((constraint = enumerator.nextObject)) {
        if ([constraint.firstItem isEqual:self] && constraint.firstAttribute == NSLayoutAttributeTop) {
            return constraint;
        }
    }
    @throw nil;
}

- (NSLayoutConstraint *)getSelfBottomConstraint {
    NSArray *superViewConstraints = self.superview.constraints;
    if (!superViewConstraints.count) {
        return nil;
    }
    NSEnumerator *enumerator = superViewConstraints.reverseObjectEnumerator;
    NSLayoutConstraint *constraint = nil;
    while ((constraint = enumerator.nextObject)) {
        if ([constraint.firstItem isEqual:self] && constraint.firstAttribute == NSLayoutAttributeBottom) {
            return constraint;
        }
    }
    @throw nil;
}

- (NSLayoutConstraint *)getSelfLeftConstraint {
    NSArray *superViewConstraints = self.superview.constraints;
    if (!superViewConstraints.count) {
        return nil;
    }
    NSEnumerator *enumerator = superViewConstraints.reverseObjectEnumerator;
    NSLayoutConstraint *constraint = nil;
    while ((constraint = enumerator.nextObject)) {
        if ([constraint.firstItem isEqual:self] && constraint.firstAttribute == NSLayoutAttributeLeading) {
            return constraint;
        }
    }
    @throw nil;
}

- (NSLayoutConstraint *)getSelfRightConstraint {
    NSArray *superViewConstraints = self.superview.constraints;
    if (!superViewConstraints.count) {
        return nil;
    }
    NSEnumerator *enumerator = superViewConstraints.reverseObjectEnumerator;
    NSLayoutConstraint *constraint = nil;
    while ((constraint = enumerator.nextObject)) {
        if ([constraint.firstItem isEqual:self] && constraint.firstAttribute == NSLayoutAttributeTrailing) {
            return constraint;
        }
    }
    @throw nil;
}

- (void)updateConstraints {
    
    [self clearConstraints];
    
    // contentView 与 父视图 保持一致, 根据子控件的高度而改变
    NSArray *contentViewConstraints = @[
                                        @[[NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0],
                                          
                                          ],
                                        [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(contentViewHorizontalSpace)-[contentView]-(contentViewHorizontalSpace)-|"
                                                                                options:0
                                                                                metrics:@{@"contentViewHorizontalSpace": @(_contentViewHorizontalSpace)}
                                                                                  views:@{@"contentView": self.contentView}]
                                        ];
    
    NSArray *constraints = [contentViewConstraints valueForKeyPath:@"@unionOfArrays.self"];
    [self addConstraints:constraints];
    [self.viewsConstraints addObjectsFromArray:constraints];
    
    // 根据contentLayouAttribute确定contentView的顶部或中心点
    switch (self.contentLayouAttribute) {
        case UIScrollViewNoDataContentLayouAttributeCenterY: {
            NSLayoutConstraint *contentY = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0];
            [self addConstraint:contentY];
            [self.viewsConstraints addObject:contentY];
            break;
        }
        case UIScrollViewNoDataContentLayouAttributeTop: {
            NSLayoutConstraint *contentTop = [NSLayoutConstraint constraintWithItem:self.contentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
            [self addConstraint:contentTop];
            [self.viewsConstraints addObject:contentTop];
            break;
        }
        default:
            break;
    }
    
    // 需要调整self 相对父控件顶部和左侧 的偏移量
    NSLayoutConstraint *getSelfTopConstraint, *getSelfBottomConstraint, *getSelfLeftConstraint, *getSelfRightConstraint;
    if ((getSelfTopConstraint = self.getSelfTopConstraint) &&
        (getSelfBottomConstraint = self.getSelfBottomConstraint) &&
        (getSelfLeftConstraint = self.getSelfLeftConstraint) &&
        (getSelfRightConstraint = self.getSelfRightConstraint)) {
        getSelfTopConstraint.constant = self.contentOffsetY;
        getSelfBottomConstraint.constant = self.contentOffsetY;
        getSelfLeftConstraint.constant = self.contentOffsetX;
        getSelfRightConstraint.constant = self.contentOffsetX;
    }
    
    // 若有customView 则 让其与contentView的约束相同
    if (_customView) {
        NSArray *customViewConstraints = @[
                                           [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[customView]|"
                                                                                   options:0
                                                                                   metrics:nil
                                                                                     views:@{@"customView": _customView}],
                                           [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[customView]|"
                                                                                   options:0
                                                                                   metrics:nil
                                                                                     views:@{@"customView": _customView}]
                                           ];
        NSArray *constraints = [customViewConstraints valueForKeyPath:@"@unionOfArrays.self"];
        [self.contentView addConstraints:constraints];
        [self.viewsConstraints addObjectsFromArray:constraints];
    } else {
        
        // 无customView
        CGFloat width = CGRectGetWidth(self.frame) ?: CGRectGetWidth([UIScreen mainScreen].bounds);
        CGFloat horizontalSpace = roundf(width / NoDataPlaceholderHorizontalSpaceRatioValue); // contentView的子控件横向间距  四舍五入
        CGFloat globalverticalSpace = self.globalVerticalSpace; // contentView的子控件之间的垂直间距，默认为10.0
        
        NSMutableArray<NSString *> *subviewKeyArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableDictionary *subviewDict = [NSMutableDictionary dictionaryWithCapacity:0];
        NSMutableDictionary *metrics = @{@"horizontalSpace": @(horizontalSpace)}.mutableCopy;
        
        // 设置imageView水平约束
        if ([self canShowImage]) {
            
            [subviewKeyArray addObject:NSStringFromSelector(@selector(imageView))];
            subviewDict[[subviewKeyArray lastObject]] = _imageView;
            
            CGFloat imageLeftSpace = horizontalSpace;
            CGFloat imageRightSpace = horizontalSpace;
            if ([self canChangeInsets:self.imageEdgeInsets]) {
                imageLeftSpace = self.imageEdgeInsets.left;
                imageRightSpace = self.imageEdgeInsets.right;
                NSDictionary *imageMetrics = @{@"imageLeftSpace": @(imageLeftSpace),
                                               @"imageRightSpace": @(imageRightSpace)};
                [metrics addEntriesFromDictionary:imageMetrics];
                NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(imageLeftSpace@999)-[imageView]-(imageRightSpace@999)-|"
                                                                               options:0
                                                                               metrics:metrics
                                                                                 views:subviewDict];
                [self.contentView addConstraints:constraints];
                [self.viewsConstraints addObjectsFromArray:constraints];
            }
            else {
                NSLayoutConstraint *imageViewCenterX = [NSLayoutConstraint constraintWithItem:_imageView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.contentView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0];
                [self.contentView addConstraint:imageViewCenterX];
                [self.viewsConstraints addObject:imageViewCenterX];
            }
            if (self.imageViewSize.width > 0.0 && self.imageViewSize.height > 0.0) {
                NSArray *constraints = @[
                                         [NSLayoutConstraint constraintWithItem:self.imageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:self.imageViewSize.width],
                                         [NSLayoutConstraint constraintWithItem:self.imageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:self.imageViewSize.height],
                                         ];
                [self.contentView addConstraints:constraints];
                [self.viewsConstraints addObjectsFromArray:constraints];
            }
            
        } else {
            [_imageView removeFromSuperview];
            _imageView = nil;
        }
        
        // 根据title是否可以显示，设置titleLable的水平约束
        if ([self canShowTitle]) {
            CGFloat titleLeftSpace = horizontalSpace;
            CGFloat titleRightSpace = horizontalSpace;
            if ([self canChangeInsets:self.titleEdgeInsets]) {
                titleLeftSpace = self.titleEdgeInsets.left;
                titleRightSpace = self.titleEdgeInsets.right;
            }
            NSDictionary *titleMetrics = @{@"titleLeftSpace": @(titleLeftSpace),
                                           @"titleRightSpace": @(titleRightSpace)};
            [metrics addEntriesFromDictionary:titleMetrics];
            [subviewKeyArray addObject:NSStringFromSelector(@selector(titleLabel))];
            subviewDict[[subviewKeyArray lastObject]] = _titleLabel;
            
            NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(titleLeftSpace@999)-[titleLabel(>=0)]-(titleRightSpace@999)-|"
                                                                           options:0
                                                                           metrics:metrics
                                                                             views:subviewDict];
            [self.contentView addConstraints:constraints];
            [self.viewsConstraints addObjectsFromArray:constraints];
        } else {
            // 不显示就移除
            [_titleLabel removeFromSuperview];
            _titleLabel = nil;
        }
        
        // 根据是否可以显示detail, 设置detailLabel水平约束
        if ([self canShowDetail]) {
            
            CGFloat detailLeftSpace = horizontalSpace;
            CGFloat detailRightSpace = horizontalSpace;
            if ([self canChangeInsets:self.detailEdgeInsets]) {
                detailLeftSpace = self.detailEdgeInsets.left;
                detailRightSpace = self.detailEdgeInsets.right;
            }
            NSDictionary *detailMetrics = @{@"detailLeftSpace": @(detailLeftSpace),
                                            @"detailRightSpace": @(detailRightSpace)};
            [metrics addEntriesFromDictionary:detailMetrics];
            
            [subviewKeyArray addObject:NSStringFromSelector(@selector(detailLabel))];
            subviewDict[[subviewKeyArray lastObject]] = _detailLabel;
            
            NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-(detailLeftSpace@999)-[detailLabel(>=0)]-(detailRightSpace@999)-|"
                                                                           options:0
                                                                           metrics:metrics
                                                                             views:subviewDict];
            [self.contentView addConstraints:constraints];
            [self.viewsConstraints addObjectsFromArray:constraints];
        } else {
            // 不显示就移除
            [_detailLabel removeFromSuperview];
            _detailLabel = nil;
        }
        
        // 根据reloadButton是否能显示，设置其水平约束
        if ([self canShowReloadButton]) {
            
            CGFloat buttonLeftSpace = horizontalSpace;
            CGFloat buttonRightSpace = horizontalSpace;
            if ([self canChangeInsets:self.buttonEdgeInsets]) {
                buttonLeftSpace = self.buttonEdgeInsets.left;
                buttonRightSpace = self.buttonEdgeInsets.right;
            }
            NSDictionary *buttonMetrics = @{@"buttonLeftSpace": @(buttonLeftSpace),
                                            @"buttonRightSpace": @(buttonRightSpace)};
            [metrics addEntriesFromDictionary:buttonMetrics];
            
            [subviewKeyArray addObject:NSStringFromSelector(@selector(reloadButton))];
            subviewDict[[subviewKeyArray lastObject]] = _reloadButton;
            
            NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-(buttonLeftSpace@999)-[reloadButton(>=0)]-(buttonRightSpace@999)-|"
                                                                           options:0
                                                                           metrics:metrics
                                                                             views:subviewDict];
            [self.contentView addConstraints:constraints];
            [self.viewsConstraints addObjectsFromArray:constraints];
        } else {
            // 不显示就移除
            [_reloadButton removeFromSuperview];
            _reloadButton = nil;
        }
        
        // 设置垂直约束
        NSMutableString *verticalFormat = [NSMutableString new];
        // 拼接字符串，添加每个控件垂直边缘之间的约束值, 默认为globalVerticalSpace 10.0，如果设置了子控件的contentEdgeInsets,则verticalSpace无效
        UIView *previousView = nil;
        for (NSInteger i = 0; i < subviewKeyArray.count; ++i) {
            CGFloat topSpace = globalverticalSpace;
            NSString *viewName = subviewKeyArray[i];
            UIView *view = subviewDict[viewName];
            // 拼接间距值
            if ([self canChangeInsets:view.noDataPlaceholderViewContentEdgeInsets]) {
                topSpace = view.noDataPlaceholderViewContentEdgeInsets.top;
            }
            if ([self canChangeInsets:previousView.noDataPlaceholderViewContentEdgeInsets]) {
                topSpace += previousView.noDataPlaceholderViewContentEdgeInsets.bottom;
            }
            
            [verticalFormat appendFormat:@"-(%.f@999)-[%@]", topSpace, viewName];
            
            if (i == subviewKeyArray.count - 1) {
                // 最后一个控件把距离父控件底部的约束值也加上
                [verticalFormat appendFormat:@"-(%.f@999)-", view.noDataPlaceholderViewContentEdgeInsets.bottom];
            }
            
            
            previousView = view;
        }
        previousView = nil;
        // 向contentView分配垂直约束
        if (verticalFormat.length > 0) {
            NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|%@|", verticalFormat]
                                                                           options:0
                                                                           metrics:metrics
                                                                             views:subviewDict];
            [self.contentView addConstraints:constraints];
            [self.viewsConstraints addObjectsFromArray:constraints];
        }
    }
    
    
    
    [super updateConstraints];
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    UIView *hitView = [super hitTest:point withEvent:event];
    
    
    if ([hitView isKindOfClass:[UIControl class]]) {
        return hitView;
    }
    
    if ([hitView isEqual:_customView]) {
        hitView = [hitView hitTest:point withEvent:event];
        return hitView;
    }
    
    if ([hitView isEqual:_contentView]) {
        return hitView;
    }
    
    return hitView;
}

- (void)resetSubviews {
    [_contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _titleLabel = nil;
    _detailLabel = nil;
    _imageView = nil;
    _customView = nil;
    _reloadButton = nil;
    
    [self clearConstraints];
}

- (NSMutableArray<NSLayoutConstraint *> *)viewsConstraints {
    if (_viewsConstraints == nil) {
        _viewsConstraints = @[].mutableCopy;
    }
    return _viewsConstraints;
}

@end

@implementation _WeakObjectContainer

- (instancetype)initWithWeakObject:(__weak id)weakObject {
    if (self = [super init]) {
        _weakObject = weakObject;
    }
    return self;
}

@end

@implementation _SwizzlingObject

- (NSString *)description {
    
    NSDictionary *descriptionDict = @{@"swizzlingClass": self.swizzlingClass,
                                      @"orginSelector": NSStringFromSelector(self.orginSelector),
                                      @"swizzlingImplPointer": self.swizzlingImplPointer};
    
    return [descriptionDict description];
}

@end

@implementation NSObject (SwizzlingExtend)

////////////////////////////////////////////////////////////////////////
#pragma mark - Method swizzling
////////////////////////////////////////////////////////////////////////


- (void)hockSelector:(SEL)orginSelector swizzlingSelector:(SEL)swizzlingSelector {
    
    // 本类未实现则return
    if (![self respondsToSelector:orginSelector]) {
        return;
    }
    
    for (_SwizzlingObject *implObject in self.implementationDictionary.allValues) {
        // 确保setImplementation 在UITableView or UICollectionView只调用一次, 也就是每个方法的指针只存储一次
        if (orginSelector == implObject.orginSelector && [self isKindOfClass:implObject.swizzlingClass]) {
            return;
        }
    }
    
    Class baseClas = [self xy_baseClassToSwizzling];
    ImplementationKey key = xy_getImplementationKey(baseClas, orginSelector);
    _SwizzlingObject *swizzleObjcet = [self.implementationDictionary objectForKey:key];
    NSValue *implValue = swizzleObjcet.swizzlingImplPointer;
    
    // 如果该类的实现已经存在，就return
    if (implValue || !key || !baseClas) {
        return;
    }
    
    // 注入额外的实现
    Method method = class_getInstanceMethod(baseClas, orginSelector);
    // 设置这个方法的实现
    IMP newImpl = method_setImplementation(method, (IMP)xy_orginalImplementation);
    
    // 将新实现保存到implementationDictionary中
    swizzleObjcet = [_SwizzlingObject new];
    swizzleObjcet.swizzlingClass = baseClas;
    swizzleObjcet.orginSelector = orginSelector;
    swizzleObjcet.swizzlingImplPointer = [NSValue valueWithPointer:newImpl];
    swizzleObjcet.swizzlingSelector = swizzlingSelector;
    [self.implementationDictionary setObject:swizzleObjcet forKey:key];
}

/// 根据类名和方法，拼接字符串，作为implementationDictionary的key
NSString * xy_getImplementationKey(Class clas, SEL selector) {
    if (clas == nil || selector == nil) {
        return nil;
    }
    
    NSString *className = NSStringFromClass(clas);
    NSString *selectorName = NSStringFromSelector(selector);
    return [NSString stringWithFormat:@"%@_%@", className, selectorName];
}

// 对原方法的实现进行加工
void xy_orginalImplementation(id self, SEL _cmd) {
    
    Class baseCls = [self xy_baseClassToSwizzling];
    ImplementationKey key = xy_getImplementationKey(baseCls, _cmd);
    _SwizzlingObject *swizzleObject = [[self implementationDictionary] objectForKey:key];
    NSValue *implValue = swizzleObject.swizzlingImplPointer;
    
    // 获取原方法的实现
    IMP impPointer = [implValue pointerValue];
    
    // 执行swizzing
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL swizzlingSelector = swizzleObject.swizzlingSelector;
    if ([self respondsToSelector:swizzlingSelector]) {
        [self performSelector:swizzlingSelector];
    }
#pragma clang diagnostic pop
    
    // 执行原实现
    if (impPointer) {
        ((void(*)(id, SEL))impPointer)(self, _cmd);
    }
}
+ (NSMutableDictionary *)implementationDictionary {
    static NSMutableDictionary *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMutableDictionary dictionary];
    });
    return table;
}

- (NSMutableDictionary<ImplementationKey, _SwizzlingObject *> *)implementationDictionary {
    return self.class.implementationDictionary;
}

- (Class)xy_baseClassToSwizzling {
    return [self class];
}

@end

@implementation UIView (NoDataPlaceholderViewEdgeInsetsExtend)

- (void)setNoDataPlaceholderViewContentEdgeInsets:(UIEdgeInsets)noDataPlaceholderViewContentEdgeInsets {
    objc_setAssociatedObject(self, @selector(noDataPlaceholderViewContentEdgeInsets), [NSValue valueWithUIEdgeInsets:noDataPlaceholderViewContentEdgeInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)noDataPlaceholderViewContentEdgeInsets {
    return [objc_getAssociatedObject(self, _cmd) UIEdgeInsetsValue];
}

@end


