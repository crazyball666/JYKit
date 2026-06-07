//
//  LogInWindow.m
//
//  Created by kagenZhao on 2017/5/23.
//  Copyright © 2017年 kagenZhao. All rights reserved.
//

#import "PrintHook.h"
#import <sys/uio.h>
#import <stdio.h>
#import <unistd.h>

#if __has_include(<JYKit/JYKit-Swift.h>)
#import <JYKit/JYKit-Swift.h>
#else
#import "JYKit-Swift.h"
#endif

@interface PrintHook()
@property (nonatomic, strong) NSPipe *stdoutPipe;
@property (nonatomic, strong) NSPipe *stderrPipe;
@property (nonatomic, assign) int originalStdoutFD;
@property (nonatomic, assign) int originalStderrFD;
@property (nonatomic, assign) BOOL hooked;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        _originalStdoutFD = -1;
        _originalStderrFD = -1;
    }
    return self;
}

-(void)hook {
    if (self.hooked) {
        return;
    }

    self.stdoutPipe = [[NSPipe alloc] init];
    self.stderrPipe = [[NSPipe alloc] init];
    
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    
    self.originalStdoutFD = dup(STDOUT_FILENO);
    self.originalStderrFD = dup(STDERR_FILENO);
    if (self.originalStdoutFD < 0 || self.originalStderrFD < 0) {
        [self close];
        return;
    }
    
    dup2(self.stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO);
    dup2(self.stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO);
    
    __weak typeof(self) weakSelf = self;
    self.stdoutPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull handle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        NSData *data = handle.availableData;
        if (data.length == 0) { return; }
        NSString *str = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        if (str.length > 0) {
            [DYLog.sharedInstance log: str];
        }
        if (self.originalStdoutFD >= 0) {
            write(self.originalStdoutFD, data.bytes, data.length);
        }
    };
    
    self.stderrPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle * _Nonnull handle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        NSData *data = handle.availableData;
        if (data.length == 0) { return; }
        NSString *str = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
        if (str.length > 0) {
            [DYLog.sharedInstance log: str];
        }
        if (self.originalStderrFD >= 0) {
            write(self.originalStderrFD, data.bytes, data.length);
        }
    };
    self.hooked = YES;
}


-(void)close {
    if (!self.hooked && self.originalStdoutFD < 0 && self.originalStderrFD < 0) {
        return;
    }

    self.stdoutPipe.fileHandleForReading.readabilityHandler = nil;
    self.stderrPipe.fileHandleForReading.readabilityHandler = nil;

    if (self.originalStdoutFD >= 0) {
        dup2(self.originalStdoutFD, STDOUT_FILENO);
        close(self.originalStdoutFD);
        self.originalStdoutFD = -1;
    }
    if (self.originalStderrFD >= 0) {
        dup2(self.originalStderrFD, STDERR_FILENO);
        close(self.originalStderrFD);
        self.originalStderrFD = -1;
    }

    [self.stdoutPipe.fileHandleForReading closeFile];
    [self.stdoutPipe.fileHandleForWriting closeFile];
    [self.stderrPipe.fileHandleForReading closeFile];
    [self.stderrPipe.fileHandleForWriting closeFile];
    self.stdoutPipe = nil;
    self.stderrPipe = nil;
    self.hooked = NO;
}
@end
