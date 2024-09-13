//
//  SwiftPrintHook.h
//  DynamicTools
//
//  Created by cerzi on 2022/5/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrintHook : NSObject
+(instancetype)shared;
-(void)hook;
-(void)close;
@end

NS_ASSUME_NONNULL_END
