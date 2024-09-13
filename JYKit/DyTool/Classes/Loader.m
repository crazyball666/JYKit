//
//  Loader.m
//  DynamicTools
//
//  Created by crazyball on 2022/8/26.
//

#import "Loader.h"

#if __has_include(<JYKit/JYKit-Swift.h>)
#import <JYKit/JYKit-Swift.h>
#else
#import "JYKit-Swift.h"
#endif

@implementation Loader

+ (void)load {
    [DynamicTools setup];
}

@end
