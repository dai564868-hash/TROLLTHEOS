#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#import <mach/mach.h>
#import <mach/vm_page_size.h>
#import <mach/task_info.h>
#import <mach/mach_traps.h>
#import <stdio.h>
#import <stdlib.h>
#import <libgen.h>
#import <map>
#import <deque>
#import <vector>
#import <array>
#import <string>
#import <UIKit/UIKit.h>
#include <string.h>
#include <limits.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <unistd.h>
#include <sys/mman.h>
#include <math.h>
#include "UtfTool.hpp"
#include "libproc.h"
#include <errno.h>
#import "pid.h"

#define __int64 int64_t
#ifndef PROC_ALL_PIDS
#define PROC_ALL_PIDS 1
#endif
#ifndef PROC_PIDPATHINFO_MAXSIZE
#define PROC_PIDPATHINFO_MAXSIZE 1024
#endif

struct dyld_uuid_info64 {
    mach_vm_address_t    imageLoadAddress;
    uuid_t               imageUUID;
};

struct dyld_image_info64 {
    mach_vm_address_t    imageLoadAddress;
    mach_vm_address_t    imageFilePath;
    mach_vm_size_t       imageFileModDate;
};

struct dyld_all_image_infos64 {
    uint32_t version;
    uint32_t infoArrayCount;
    mach_vm_address_t infoArray;
    dyld_image_notifier  notification;
    bool                 processDetachedFromSharedRegion;
    bool libSystemInitialized;
    mach_vm_address_t            dyldImageLoadAddress;
    mach_vm_address_t            jitInfo;
    mach_vm_address_t            dyldVersion;
    mach_vm_address_t            errorMessage;
    uint64_t                    terminationFlags;
    mach_vm_address_t            coreSymbolicationShmPage;
    uint64_t                    systemOrderFlag;
    uint64_t                    uuidArrayCount;
    mach_vm_address_t            uuidArray;
    mach_vm_address_t            dyldAllImageInfosAddress;
    uint64_t                    initialImageCount;
    uint64_t                    errorKind;
    mach_vm_address_t            errorClientOfDylibPath;
    mach_vm_address_t            errorTargetDylibPath;
    mach_vm_address_t            errorSymbol;
    uint64_t                    sharedCacheSlide;
};

mach_port_t global_task_port = MACH_PORT_NULL;

mach_port_t get_task_port(pid_t pid) {
    mach_port_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) {
        return MACH_PORT_NULL;
    }
    return task;
}

void initialize_task_port(pid_t pid) {
    global_task_port = get_task_port(pid);
}

kern_return_t mach_vm_read(mach_port_t target_task, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t *data, mach_vm_size_t *data_size) {
    vm_offset_t outData = 0;
    mach_msg_type_number_t outSize = 0;
    kern_return_t kr = vm_read(target_task, (vm_address_t)address, (vm_size_t)size, &outData, &outSize);
    if (kr == KERN_SUCCESS) {
        *data = outData;
        *data_size = outSize;
    }
    return kr;
}

static bool ReadMemory(mach_vm_address_t address, void* buffer, size_t size) {
    mach_vm_size_t data_size = 0;
    mach_vm_address_t out_memory = 0;
    kern_return_t kr = mach_vm_read(global_task_port, address, size, &out_memory, &data_size);
    if (kr != KERN_SUCCESS || data_size != size) {
        return false;
    }
    memcpy(buffer, (void*)out_memory, size);
    vm_deallocate(mach_task_self(), out_memory, data_size);
    return true;
}

static bool WriteMemory(mach_vm_address_t address, void* buffer, size_t size) {
    kern_return_t kr = vm_write(global_task_port, address, (vm_offset_t)buffer, (mach_msg_type_number_t)size);
    if (kr != KERN_SUCCESS) {
        return false;
    }
    return true;
}


typedef uintptr_t kaddr;
bool IsValidAddress(kaddr address) {
    return address != 0;
}

mach_port_t get_task_for_PID(pid_t pid)
{
    mach_port_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr == KERN_SUCCESS)
    {
        return task;
    }
    return MACH_PORT_NULL;
}

pid_t get_pid_by_name(const char *keyword)
{
    int count = proc_listallpids(NULL, 0);
    pid_t pids[count];
    proc_listallpids(pids, sizeof(pids));
    for (int i = 0; i < count; i++)
    {
        char name[1000];
        proc_name(pids[i], name, sizeof(name));
        if (strstr(name, keyword) != NULL)
        {
            return pids[i];
        }
    }
    return -1;
}

task_t get_task_by_pid(pid_t pid)
{
    task_port_t psDefault;
    task_port_t psDefault_control;
    task_array_t tasks;
    mach_msg_type_number_t numTasks;
    kern_return_t kr;
    host_t self_host = mach_host_self();
    kr = processor_set_default(self_host, &psDefault);
    if (kr != KERN_SUCCESS)
    {
        fprintf(stderr, "Error in processor_set_default: %x\n", kr);
        return MACH_PORT_NULL;
    }
    kr = host_processor_set_priv(self_host, psDefault, &psDefault_control);
    if (kr != KERN_SUCCESS)
    {
        fprintf(stderr, "Error in host_processor_set_priv: %x\n", kr);
        return MACH_PORT_NULL;
    }
    kr = processor_set_tasks(psDefault_control, &tasks, &numTasks);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Error in processor_set_tasks: %x\n", kr);
        return MACH_PORT_NULL;
    }
    for (int i = 0; i < numTasks; i++)
    {
        int task_pid;
        kr = pid_for_task(tasks[i], &task_pid);
        if (kr != KERN_SUCCESS) {
            continue;
        }
        if (task_pid == pid) return tasks[i];
    }
    return MACH_PORT_NULL;
}

mach_vm_address_t get_image_base_address(mach_port_t task, const char *image_name)
{
    task_dyld_info_data_t dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    if (kr != KERN_SUCCESS)
    {
        return 0;
    }
    struct dyld_all_image_infos64 infos;
    vm_size_t size = sizeof(infos);
    mach_msg_type_number_t read_size = 0;
    vm_offset_t read_mem = 0;
    kr = vm_read(task, (vm_address_t)dyld_info.all_image_info_addr, size, &read_mem, &read_size);
    if (kr != KERN_SUCCESS || read_size < sizeof(infos))
    {
        return 0;
    }
    memcpy(&infos, (void *)read_mem, sizeof(infos));
    vm_deallocate(mach_task_self(), read_mem, read_size);
    uint32_t image_count = infos.infoArrayCount;
    mach_vm_address_t info_array_addr = infos.infoArray;
    vm_size_t image_info_size = image_count * sizeof(struct dyld_image_info64);
    struct dyld_image_info64 *image_infos = (struct dyld_image_info64 *)malloc(image_info_size);
    if (!image_infos) return 0;
    read_mem = 0;
    read_size = 0;
    kr = vm_read(task, (vm_address_t)info_array_addr, image_info_size, &read_mem, &read_size);
    if (kr != KERN_SUCCESS || read_size < image_info_size)
    {
        free(image_infos);
        return 0;
    }
    memcpy(image_infos, (void *)read_mem, image_info_size);
    vm_deallocate(mach_task_self(), read_mem, read_size);
    for (uint32_t i = 0; i < image_count; ++i)
    {
        char path_buffer[PATH_MAX] = {0};
        read_mem = 0;
        read_size = 0;
        kr = vm_read(task, (vm_address_t)image_infos[i].imageFilePath, PATH_MAX, &read_mem, &read_size);
        if (kr == KERN_SUCCESS)
        {
            size_t to_copy = read_size > PATH_MAX ? PATH_MAX : read_size;
            memcpy(path_buffer, (void *)read_mem, to_copy);
            vm_deallocate(mach_task_self(), read_mem, read_size);
        }
        if (kr == KERN_SUCCESS && strstr(path_buffer, image_name))
        {
            mach_vm_address_t base = image_infos[i].imageLoadAddress;
            free(image_infos);
            return base;
        }
    }
    free(image_infos);
    return 0;
}

/*
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* ________________________________________LDVQuang__________________________________________________
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* 
* 
* create on 31/12/2025 by @quangmodmap
*/