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

#import "JYDeviceInfo.h"

#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <mach/mach_error.h>
#include <mach/mach_host.h>
#include <mach/mach_port.h>
#include <mach/task.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <os/proc.h>
#import <sys/utsname.h>

#if !TARGET_OS_OSX
    #import <UIKit/UIKit.h>
#else
    #import <AppKit/AppKit.h>
#endif

#define kIPadSystemNamePrefix @"iPad "

@implementation JYNetworkFlowInfo
@end

@implementation JYDeviceInfo
+ (NSString *)getSysInfoByName:(char *)typeSpeifier {
    size_t size;
    sysctlbyname(typeSpeifier, NULL, &size, NULL, 0);
    char *answer = (char *)malloc(size);
    sysctlbyname(typeSpeifier, answer, &size, NULL, 0);
    NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
    if (results == nil) {
        results = @"";
    }
    free(answer);
    return results;
}

+ (int)getSysInfo:(uint)typeSpecifier {
    size_t size = sizeof(int);
    int results;
    int mib[2] = { CTL_HW, (int)typeSpecifier };
    sysctl(mib, 2, &results, &size, NULL, 0);
    return results;
}

+ (nonnull NSString *)systemName {
#if !TARGET_OS_OSX
    return [UIDevice currentDevice].systemName;
#else
    NSProcessInfo *pInfo = [NSProcessInfo processInfo];
    return [pInfo operatingSystemVersionString];
#endif
}

+ (nonnull NSString *)systemVersion {
#if !TARGET_OS_OSX
    return [UIDevice currentDevice].systemVersion;
#else
    static NSString *g_s_systemVersion = nil;
    if (g_s_systemVersion == nil) {
        NSDictionary *sv = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
        NSString *productVersion = [sv objectForKey:@"ProductVersion"];
        NSString *productBuildVersion = [sv objectForKey:@"ProductBuildVersion"];
        g_s_systemVersion = [NSString stringWithFormat:@"OSX %@ build(%@)", productVersion, productBuildVersion];
    }
    return g_s_systemVersion;
#endif
}

+ (nonnull NSString *)model {
#if !TARGET_OS_OSX
    return [UIDevice currentDevice].model;
#else
    return [JYDeviceInfo getSysInfoByName:(char *)"hw.model"];
#endif
}

+ (nonnull NSString *)deviceModel {
#if !TARGET_OS_OSX
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
#else
    NSString *modelIdentifier = nil;
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef modelCF = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0);
        if (modelCF) {
            modelIdentifier = (__bridge_transfer NSString *)modelCF;
        }
        IOObjectRelease(platformExpert);
    }
    return modelIdentifier ?: @"";
#endif
}

+ (nonnull NSString *)platform {
    return [JYDeviceInfo getSysInfoByName:(char *)"hw.machine"];
}

+ (int)cpuCount {
    static int s_cpuCount = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_cpuCount = [JYDeviceInfo getSysInfo:HW_NCPU];
    });
    return s_cpuCount;
}

+ (int)cpuFrequency {
    return [JYDeviceInfo getSysInfo:HW_CPU_FREQ];
}

+ (float)cpuUsage {
    kern_return_t kr;
    mach_msg_type_number_t count;
    static host_cpu_load_info_data_t previous_info = { 0, 0, 0, 0 };
    host_cpu_load_info_data_t info;
    count = HOST_CPU_LOAD_INFO_COUNT;
    kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count);
    if (kr != KERN_SUCCESS) {
        return 0;
    }
    natural_t user = info.cpu_ticks[CPU_STATE_USER] - previous_info.cpu_ticks[CPU_STATE_USER];
    natural_t nice = info.cpu_ticks[CPU_STATE_NICE] - previous_info.cpu_ticks[CPU_STATE_NICE];
    natural_t system = info.cpu_ticks[CPU_STATE_SYSTEM] - previous_info.cpu_ticks[CPU_STATE_SYSTEM];
    natural_t idle = info.cpu_ticks[CPU_STATE_IDLE] - previous_info.cpu_ticks[CPU_STATE_IDLE];
    natural_t total = user + nice + system + idle;
    previous_info = info;
    if (total == 0) {
        return 0;
    } else {
        return (user + nice + system) * 100.0 / total;
    }
}


+ (float)appCpuUsage {
    const task_t thisTask = mach_task_self();
    thread_array_t thread_list = NULL;
    mach_msg_type_number_t thread_count = 0;
    kern_return_t kr = task_threads(thisTask, &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    float tot_cpu = 0;
    for (int j = 0; j < thread_count; j++) {
        thread_info_data_t thinfo;
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            tot_cpu = -1;
            goto cleanup;
        }
        thread_basic_info_t basic_info_th = (thread_basic_info_t)thinfo;
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
    }
cleanup:
    for (int i = 0; i < thread_count; i++) {
        mach_port_deallocate(thisTask, thread_list[i]);
    }
    kr = vm_deallocate(thisTask, (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);

    return tot_cpu;
}

+ (int)busFrequency {
    return [JYDeviceInfo getSysInfo:HW_BUS_FREQ];
}

+ (int)cacheLine {
    return [JYDeviceInfo getSysInfo:HW_CACHELINE];
}

+ (int)L1ICacheSize {
    return [JYDeviceInfo getSysInfo:HW_L1ICACHESIZE];
}

+ (int)L1DCacheSize {
    return [JYDeviceInfo getSysInfo:HW_L1DCACHESIZE];
}

+ (int)L2CacheSize {
    return [JYDeviceInfo getSysInfo:HW_L2CACHESIZE];
}

+ (int)L3CacheSize {
    return [JYDeviceInfo getSysInfo:HW_L3CACHESIZE];
}

+ (BOOL)isBeingDebugged {
    // Returns true if the current process is being debugged (either
    // running under the debugger or has a debugger attached post facto).
    int junk;
    int mib[4];
    struct kinfo_proc info;
    size_t size;

    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.

    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    // Call sysctl.

    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);

    // We're being debugged if the P_TRACED flag is set.
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}


+ (uint64_t)physicalMemory {
    uint64_t value;
    size_t size = sizeof(value);

    // same as [[NSProcessInfo processInfo] physicalMemory]
    int ret = sysctlbyname("hw.memsize", &value, &size, NULL, 0);
    if (ret != 0) {
        return 0;
    }

    return value;
}

+ (uint64_t)footprintMemory {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t infoCount = TASK_VM_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &infoCount);

    if (kernReturn != KERN_SUCCESS) {
        return 0;
    }

    return vmInfo.phys_footprint;
}

+ (uint64_t)availableMemory {
#if !TARGET_OS_OSX
    if (@available(iOS 13.0, *)) {
        return os_proc_available_memory();
    }
#endif

    // Fallback on earlier versions

    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);

    if (kernReturn != KERN_SUCCESS) {
        return 0;
    }

    return (uint64_t)vm_page_size * (vmStats.free_count + vmStats.inactive_count);
}

+ (JYNetworkFlowInfo *)networkFlowInfo {
    JYNetworkFlowInfo *flowInfo = [JYNetworkFlowInfo new];
    struct ifaddrs *interfaces = NULL;

    if (getifaddrs(&interfaces) != 0) {
        return flowInfo;
    }

    for (struct ifaddrs *cursor = interfaces; cursor != NULL; cursor = cursor->ifa_next) {
        if (cursor->ifa_addr == NULL || cursor->ifa_data == NULL) {
            continue;
        }

        if (cursor->ifa_addr->sa_family != AF_LINK) {
            continue;
        }

        unsigned int flags = cursor->ifa_flags;
        if ((flags & IFF_UP) == 0 || (flags & IFF_RUNNING) == 0 || (flags & IFF_LOOPBACK) != 0) {
            continue;
        }

        const struct if_data *interfaceData = (const struct if_data *)cursor->ifa_data;
        flowInfo.totalReceivedBytes += interfaceData->ifi_ibytes;
        flowInfo.totalSentBytes += interfaceData->ifi_obytes;
    }

    freeifaddrs(interfaces);
    return flowInfo;
}

@end
