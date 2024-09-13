//
//  Hooker.m
//  JYKit
//
//  Created by crazyball on 2023/8/3.
//

#import "Hooker.h"

@implementation Hooker

+(void) hookClassMethod:(Class __nullable) originalClass
        originalSel:(SEL __nullable) originalSel
        replacedClass:(Class) replacedClass
        replacedSel:(SEL) replacedSel
        noneSel:(SEL __nullable) noneSel
{
    if (!originalClass) {
        NSString *text = [NSString stringWithFormat:@"******** 原类 (%@) 不存在，跳过 Hook 方法 (%@)", originalClass, NSStringFromSelector(originalSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }
    // 原类方法
    Method originalMethod = class_getClassMethod(originalClass, originalSel);
    
    // 原类方法不存在
    if (!originalMethod) {
        // 添加替换类的空方法
        Method noneMethod = class_getClassMethod(replacedClass, noneSel);
        if (!noneMethod) {
            NSString *text = [NSString stringWithFormat:@"******** 替换类 (%@) 没有实现空方法 (%@)，跳过 Hook", replacedClass, NSStringFromSelector(noneSel)];
            NSLog(@"%@", text);
            NSCAssert(false, text);
            return;
        }
        
        Class class = object_getClass(originalClass);
        BOOL didAddNoneMethod = class_addMethod(class, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
        if (didAddNoneMethod) {
            NSLog(@"******** 原类 (%@) 没有实现 (%@) 方法，手动添加替换类 (%@) 的空方法 (%@) 成功", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(noneSel));
        }
        originalMethod = class_getClassMethod(originalClass, originalSel);
    }
    
    // 判断原类方法
    if (!originalMethod) {
        NSString *text = [NSString stringWithFormat:@"******** 原类 (%@) 没有实现原方法 (%@) 且添加替换类 (%@) 的空方法 (%@) 失败，跳过 Hook", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(noneSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }
    
    // 替换的类方法
    Method replacedMethod = class_getClassMethod(replacedClass, replacedSel);
    
    // 判断替换的类方法是否存在
    if (!replacedMethod) {
        NSString *text = [NSString stringWithFormat:@"******** 替换类 (%@) 没有实现方法 (%@)，跳过 Hook", replacedClass, NSStringFromSelector(replacedSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }
    
    // 向 originalClass 的元类添加 replaceMethod
    Class originMetaClass = objc_getMetaClass(NSStringFromClass(originalClass).UTF8String);
    BOOL didAddMethod = class_addMethod(originMetaClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (didAddMethod) {
        // 重新拿到添加被添加的 method,这里是关键(注意这里 originalClass, 不 replacedClass), 因为替换的方法已经添加到原类中了, 应该交换原类中的两个方法
        Method newMethod = class_getClassMethod(originalClass, replacedSel);
        // 实现交换
        method_exchangeImplementations(originalMethod, newMethod);
        NSLog(@"******** 原类 (%@) 的方法 (%@) 成功 Hook 为替换类 (%@) 的方法 (%@)", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(replacedSel));
    }else{
        // 添加失败，则说明已经 hook 过该类的方法，防止多次交换。
        NSLog(@"******** 原类 (%@) 的方法 (%@) 已替换过，避免多次替换", originalClass, NSStringFromClass(originalClass));
    }

}


+(void) hookInstanceMethod:(Class __nullable) originalClass
        originalSel:(SEL __nullable) originalSel
        replacedClass:(Class) replacedClass
        replacedSel:(SEL) replacedSel
        noneSel:(SEL __nullable) noneSel
{
    if (!originalClass) {
        NSString *text = [NSString stringWithFormat:@"******** 原类 (%@) 不存在，跳过 Hook 方法 (%@)", originalClass, NSStringFromSelector(originalSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }
    // 原实例方法
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    
    // 原实例方法不存在
    if (!originalMethod) {
        // 添加替换类的空方法
        Method noneMethod = class_getInstanceMethod(replacedClass, noneSel);
        if (!noneMethod) {
            NSString *text = [NSString stringWithFormat:@"******** 替换类 (%@) 没有实现空方法 (%@)，跳过 Hook", replacedClass, NSStringFromSelector(noneSel)];
            NSLog(@"%@", text);
            NSCAssert(false, text);
            return;
        }
        
        BOOL didAddNoneMethod = class_addMethod(originalClass, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
        if (didAddNoneMethod) {
            NSLog(@"******** 原类 (%@) 没有实现 (%@) 方法，手动添加替换类 (%@) 的空方法 (%@) 成功", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(noneSel));
        }
        originalMethod = class_getInstanceMethod(originalClass, originalSel);
    }
    
    // 判断原实例方法
    if (!originalMethod) {
        NSString *text = [NSString stringWithFormat:@"******** 原类 (%@) 没有实现原方法 (%@) 且添加替换类 (%@) 的空方法 (%@) 失败，跳过 Hook", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(noneSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }

    // 替换的实例方法
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    
    // 判断替换的类方法是否存在
    if (!replacedMethod) {
        NSString *text = [NSString stringWithFormat:@"******** 替换类 (%@) 没有实现方法 (%@)，跳过 Hook", replacedClass, NSStringFromSelector(replacedSel)];
        NSLog(@"%@", text);
        NSCAssert(false, text);
        return;
    }
    
    // 这里是向 originalClass 添加 replaceMethod
    BOOL didAddMethod = class_addMethod(originalClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (didAddMethod) {
        // 重新拿到添加被添加的 method,这里是关键(注意这里 originalClass, 不 replacedClass), 因为替换的方法已经添加到原类中了, 应该交换原类中的两个方法
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        // 实现交换
        method_exchangeImplementations(originalMethod, newMethod);
        NSLog(@"******** 原类 (%@) 的方法 (%@) 成功 Hook 为替换类 (%@) 的方法 (%@)", originalClass, NSStringFromSelector(originalSel), replacedClass, NSStringFromSelector(replacedSel));
    }else{
        // 添加失败，则说明已经 hook 过该类的方法，防止多次交换。
        NSLog(@"******** 原类 (%@) 的方法 (%@) 已替换过，避免多次替换", originalClass, NSStringFromClass(originalClass));
    }
}

@end
