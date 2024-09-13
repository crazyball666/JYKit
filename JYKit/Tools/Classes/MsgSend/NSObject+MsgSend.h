//
//  NSObject+MsgSend.h
//  DynamicTools
//
//  Created by crazyball on 2022/7/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (MsgSend)

+ (id)VKCallSelector:(SEL)selector error:(NSError *__autoreleasing *)error,...;

+ (id)VKCallSelectorName:(NSString *)selName error:(NSError *__autoreleasing *)error,...;

- (id)VKCallSelector:(SEL)selector error:(NSError *__autoreleasing *)error,...;

- (id)VKCallSelectorName:(NSString *)selName error:(NSError *__autoreleasing *)error,...;

@end




@interface MsgSend : NSObject
+(id)call:(nullable id)target sel:(SEL)sel params:(NSArray *)params;
@end


NS_ASSUME_NONNULL_END
