const root = @This();
const std = @import("std");
const core = @import("root.zig");

const log = core.log;
const vk = core.vulkan;

pub const Dispatch = vk.InstanceWrapperWithCustomDispatch(struct {
    vkCreateDevice: ?vk.PfnCreateDevice = null,
    vkGetDeviceProcAddr: ?vk.PfnGetDeviceProcAddr = null,
    vkGetPhysicalDeviceFeatures: ?vk.PfnGetPhysicalDeviceFeatures = null,
    vkGetPhysicalDeviceProperties: ?vk.PfnGetPhysicalDeviceProperties = null,
    vkGetPhysicalDeviceMemoryProperties: ?vk.PfnGetPhysicalDeviceMemoryProperties = null,
    vkEnumerateDeviceExtensionProperties: ?vk.PfnEnumerateDeviceExtensionProperties = null,
});

/// Vulkan backed handle of this physical device,
/// meant for direct read-only use.
handle: vk.PhysicalDevice,
dispatch: *const Dispatch,

pub fn from(handle: vk.PhysicalDevice, dispatch: *const Dispatch) root {
    return .{
        .handle = handle,
        .dispatch = dispatch,
    };
}

pub fn getFeatures(physical_device: root) vk.PhysicalDeviceFeatures {
    return physical_device.dispatch.getPhysicalDeviceFeatures(physical_device.handle);
}

pub fn getProperties(physical_device: root) vk.PhysicalDeviceProperties {
    return physical_device.dispatch.getPhysicalDeviceProperties(physical_device.handle);
}

pub fn getMemoryProperties(physical_device: root) vk.PhysicalDeviceMemoryProperties {
    return physical_device.dispatch.getPhysicalDeviceMemoryProperties(physical_device.handle);
}

pub fn enumerateExtensionProperties(physical_device: root, p_layer_name: ?[*:0]const u8, allocator: std.mem.Allocator) ![]vk.ExtensionProperties {
    return physical_device.dispatch.enumerateDeviceExtensionPropertiesAlloc(
        physical_device.handle,
        p_layer_name,
        allocator,
    );
}

pub fn createDevice(physical_device: root, create_info: vk.DeviceCreateInfo, p_allocator: ?*const vk.AllocationCallbacks) !vk.Device {
    return physical_device.dispatch.createDevice(physical_device.handle, &create_info, p_allocator);
}
