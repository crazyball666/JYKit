/*
 * Tencent is pleased to support the open source community by making wechat-matrix available.
 * Copyright (C) 2019 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the BSD 3-Clause License (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

/// 设备信息
@interface JYDeviceInfo : NSObject

/// 系统名称
+ (nonnull NSString *)systemName;

/// 系统版本
+ (nonnull NSString *)systemVersion;

/// 设备类型 e.g. "iPhone", "iPod touch"
+ (nonnull NSString *)model;

/// 设备型号
+ (nonnull NSString *)deviceModel;

/// 平台
+ (nonnull NSString *)platform;

/// CPU 核心数量化
+ (int)cpuCount;

/// CPU 频率
+ (int)cpuFrequency;

/// CPU 使用率
+ (float)cpuUsage;

/// App CPU 使用率
+ (float)appCpuUsage;

/// 总线频率
+ (int)busFrequency;

/// 缓存行大小
+ (int)cacheLine;

/// L1 I 缓存大小
+ (int)L1ICacheSize;

/// L1 D 缓存大小
+ (int)L1DCacheSize;

/// L2 缓存大小
+ (int)L2CacheSize;

/// L3 缓存大小
+ (int)L3CacheSize;

/// 是否在调试中
+ (BOOL)isBeingDebugged;

/// 设备的物理内存总量（bytes），来源：sysctlbyname("hw.memsize")
+ (uint64_t)physicalMemory;

/// 进程已经使用的内存量（bytes），来源：task_vm_info.phys_footprint
+ (uint64_t)footprintMemory;

/// 进程剩余可用的内存量（bytes），来源：os_proc_available_memory
+ (uint64_t)availableMemory;

@end
