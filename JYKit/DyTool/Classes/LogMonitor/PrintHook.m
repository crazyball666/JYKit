//
//  LogInWindow.m
//
//  Created by kagenZhao on 2017/5/23.
//  Copyright © 2017年 kagenZhao. All rights reserved.
//

#import "PrintHook.h"
#import <sys/uio.h>
#import <stdio.h>

#if __has_include(<JYKit/JYKit-Swift.h>)
#import <JYKit/JYKit-Swift.h>
#else
#import "JYKit-Swift.h"
#endif

@interface PrintHook()
@property (nonatomic, strong) NSPipe *stdoutPipe;
@property (nonatomic, strong) NSPipe *stderrPipe;
@end

@implementation PrintHook

+ (instancetype)shared {
    static PrintHook *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PrintHook alloc] init];
    });
    return instance;
}

-(void)hook {
    self.stdoutPipe = [[NSPipe alloc] init];
    self.stderrPipe = [[NSPipe alloc] init];
    
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    
    int ori_stdout_fileNo = dup(STDOUT_FILENO);
    int ori_stderr_fileNo = dup(STDERR_FILENO);
    
    dup2(self.stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO);
    dup2(self.stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO);
    
    self.stdoutPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull handle) {
        NSData *data = handle.availableData;
        NSString *str = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        [DYLog.sharedInstance log: str];
        const char * utf8Str = str.UTF8String;
        write(ori_stdout_fileNo,utf8Str,strlen(utf8Str));
    };
    
    self.stderrPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull handle) {
        NSData *data = handle.availableData;
        NSString *str = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        [DYLog.sharedInstance log: str];
        const char * utf8Str = str.UTF8String;
        write(ori_stderr_fileNo,utf8Str,strlen(utf8Str));
    };
}


-(void)close {
    [self.stdoutPipe.fileHandleForReading closeFile];
    [self.stderrPipe.fileHandleForReading closeFile];
    self.stdoutPipe = nil;
    self.stderrPipe = nil;
}
@end
