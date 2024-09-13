//
//  Hooker.h
//  JYKit
//
//  Created by crazyball on 2023/8/3.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface Hooker : NSObject

/// Hook 类方法
/// - Parameters:
///   - originalClass: 原类
///   - originalSel: 原方法
///   - replacedClass: 替换类
///   - replacedSel: 替换方法
///   - noneSel: 空方法
+(void) hookClassMethod:(Class __nullable) originalClass
        originalSel:(SEL __nullable) originalSel
        replacedClass:(Class) replacedClass
        replacedSel:(SEL) replacedSel
        noneSel:(SEL __nullable) noneSel;

/// Hook 实例方法
/// - Parameters:
///   - originalClass: 原类
///   - originalSel: 原方法
///   - replacedClass: 替换类
///   - replacedSel: 替换方法
///   - noneSel: 空方法
+(void) hookInstanceMethod:(Class __nullable) originalClass
        originalSel:(SEL __nullable) originalSel
        replacedClass:(Class) replacedClass
        replacedSel:(SEL) replacedSel
        noneSel:(SEL __nullable) noneSel;

@end

NS_ASSUME_NONNULL_END
