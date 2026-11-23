const root = @This();
const std = @import("std");
const core = @import("root.zig");

const log = core.log;
const vk = core.vulkan;

pub const Features = packed struct {
    const Self = @This();
    const info = @typeInfo(Self).@"struct";

    /// out of bounds buffer accesses are well defined
    robust_buffer_access: bool = false,
    /// full 32-bit range of indices for indexed draw calls
    full_draw_index_uint_32: bool = false,
    /// image views which are arrays of cube maps
    image_cube_array: bool = false,
    /// blending operations are controlled per-attachment
    independent_blend: bool = false,
    /// geometry stage
    geometry_shader: bool = false,
    /// tessellation control and evaluation stage
    tessellation_shader: bool = false,
    /// per-sample shading and interpolation
    sample_rate_shading: bool = false,
    /// blend operations which take two sources
    dual_src_blend: bool = false,
    /// logic operations
    logic_op: bool = false,
    /// multi draw indirect
    multi_draw_indirect: bool = false,
    /// indirect drawing can use non-zero firstInstance
    draw_indirect_first_instance: bool = false,
    /// depth clamping
    depth_clamp: bool = false,
    /// depth bias clamping
    depth_bias_clamp: bool = false,
    /// point and wireframe fill modes
    fill_mode_non_solid: bool = false,
    /// depth bounds test
    depth_bounds: bool = false,
    /// lines with width greater than 1
    wide_lines: bool = false,
    /// points with size greater than 1
    large_points: bool = false,
    /// the fragment alpha component can be forced to maximum representable alpha value
    alpha_to_one: bool = false,
    /// viewport arrays
    multi_viewport: bool = false,
    /// anisotropic sampler filtering
    sampler_anisotropy: bool = false,
    /// ETC texture compression formats
    texture_compression_etc2: bool = false,
    /// ASTC LDR texture compression formats
    texture_compression_astc_ldr: bool = false,
    /// BC1-7 texture compressed formats
    texture_compression_bc: bool = false,
    /// precise occlusion queries returning actual sample counts
    occlusion_query_precise: bool = false,
    /// pipeline statistics query
    pipeline_statistics_query: bool = false,
    /// stores and atomic ops on storage buffers and images are supported in vertex, tessellation, and geometry stages
    vertex_pipeline_stores_and_atomics: bool = false,
    /// stores and atomic ops on storage buffers and images are supported in the fragment stage
    fragment_stores_and_atomics: bool = false,
    /// tessellation and geometry stages can export point size
    shader_tessellation_and_geometry_point_size: bool = false,
    /// image gather with runtime values and independent offsets
    shader_image_gather_extended: bool = false,
    /// the extended set of formats can be used for storage images
    shader_storage_image_extended_formats: bool = false,
    /// multisample images can be used for storage images
    shader_storage_image_multisample: bool = false,
    /// read from storage image does not require format qualifier
    shader_storage_image_read_without_format: bool = false,
    /// write to storage image does not require format qualifier
    shader_storage_image_write_without_format: bool = false,
    /// arrays of uniform buffers can be accessed with dynamically uniform indices
    shader_uniform_buffer_array_dynamic_indexing: bool = false,
    /// arrays of sampled images can be accessed with dynamically uniform indices
    shader_sampled_image_array_dynamic_indexing: bool = false,
    /// arrays of storage buffers can be accessed with dynamically uniform indices
    shader_storage_buffer_array_dynamic_indexing: bool = false,
    /// arrays of storage images can be accessed with dynamically uniform indices
    shader_storage_image_array_dynamic_indexing: bool = false,
    /// clip distance in shaders
    shader_clip_distance: bool = false,
    /// cull distance in shaders
    shader_cull_distance: bool = false,
    /// 64-bit floats (doubles) in shaders
    shader_float_64: bool = false,
    /// 64-bit integers in shaders
    shader_int_64: bool = false,
    /// 16-bit integers in shaders
    shader_int_16: bool = false,
    /// shader can use texture operations that return resource residency information (requires sparseNonResident support)
    shader_resource_residency: bool = false,
    /// shader can use texture operations that specify minimum resource LOD
    shader_resource_min_lod: bool = false,
    /// Sparse resources support: Resource memory can be managed at opaque page level rather than object level
    sparse_binding: bool = false,
    /// Sparse resources support: GPU can access partially resident buffers
    sparse_residency_buffer: bool = false,
    /// Sparse resources support: GPU can access partially resident 2D (non-MSAA non-depth/stencil) images
    sparse_residency_image_2d: bool = false,
    /// Sparse resources support: GPU can access partially resident 3D images
    sparse_residency_image_3d: bool = false,
    /// Sparse resources support: GPU can access partially resident MSAA 2D images with 2 samples
    sparse_residency_2_samples: bool = false,
    /// Sparse resources support: GPU can access partially resident MSAA 2D images with 4 samples
    sparse_residency_4_samples: bool = false,
    /// Sparse resources support: GPU can access partially resident MSAA 2D images with 8 samples
    sparse_residency_8_samples: bool = false,
    /// Sparse resources support: GPU can access partially resident MSAA 2D images with 16 samples
    sparse_residency_16_samples: bool = false,
    /// Sparse resources support: GPU can correctly access data aliased into multiple locations (opt-in)
    sparse_residency_aliased: bool = false,
    /// multisample rate must be the same for all pipelines in a subpass
    variable_multisample_rate: bool = false,
    /// Queries may be inherited from primary to secondary command buffers
    inherited_queries: bool = false,

    pub fn from(features: vk.PhysicalDeviceFeatures) Self {
        var feats = Self{};
        inline for (info.field_names) |name| {
            @field(feats, name) = @field(features, name) == .true;
        }

        return feats;
    }

    pub fn toPhysicalDeviceFeatures(feats: Self) vk.PhysicalDeviceFeatures {
        var features = vk.PhysicalDeviceFeatures{};
        inline for (info.field_names) |name| {
            @field(features, name) = if (@field(feats, name)) .true else .false;
        }

        return features;
    }
};

pub const Extension = enum {
    const Self = @This();
    const info = @typeInfo(Self).@"enum";

    const strings = std.EnumArray(Self, [:0]const u8).init(init_values: {
        var tmp: std.enums.EnumFieldStruct(Self, [:0]const u8, null) = undefined;
        for (info.field_names) |name| {
            @field(tmp, name) = @field(vk.device_extensions, name).name;
        }

        break :init_values tmp;
    });

    const map = std.StaticStringMap(Self).initComptime(kvs_list: {
        var tmp: [info.field_names.len]struct { []const u8, Self } = undefined;
        for (info.field_names, &tmp) |name, *pair| {
            pair.@"1" = @field(Self, name);
            pair.@"0" = pair.@"1".string();
        }

        break :kvs_list tmp;
    });

    khr_swapchain,
    khr_bind_memory_2,
    khr_external_memory,
    ext_host_query_reset,
    khr_performance_query,
    khr_dedicated_allocation,
    khr_get_memory_requirements_2,

    pub fn from(name: []const u8) ?Self {
        return map.get(name);
    }

    pub fn string(extension: Self) [:0]const u8 {
        return strings.get(extension);
    }
};

pub const Specifications = struct {
    const Self = @This();

    pub const init = Self{
        .features = .{},
        .extensions = .{},
    };

    features: Features,
    extensions: std.EnumSet(Extension),

    pub fn from(physical_device: core.PhysicalDevice, allocator: std.mem.Allocator) !Self {
        var specifications = Self.init;
        specifications.features = .from(physical_device.getFeatures());

        const properties = try physical_device.enumerateExtensionProperties(null, allocator);
        defer allocator.free(properties);

        for (properties) |property| {
            const ptr: [*:0]const u8 = @ptrCast(&property.extension_name);
            const string = std.mem.span(ptr);

            if (Extension.from(string)) |extension|
                specifications.extensions.insert(extension)
            else
                log.debug("'{s}' is not supported", .{string});
        }

        return specifications;
    }

    pub fn has(specifications: Self, extension: Extension) bool {
        return specifications.extensions.contains(extension);
    }
};

/// Vulkan backed handle of this device,
/// meant for direct read-only use.
handle: vk.Device,
/// The specifications of this device,
/// meant for direct read-only use.
specifications: Specifications,
/// The underlying physical device of this device,
/// meant for direct read-only use.
physical_device: core.PhysicalDevice,
dispatch: vk.DeviceWrapperWithCustomDispatch(struct {
    vkDestroyDevice: ?vk.PfnDestroyDevice = null,
    vkGetDeviceProcAddr: ?vk.PfnGetDeviceProcAddr = null,
}),

pub const InitInfo = struct {
    specifications: Specifications,
    queue_create_infos: []const vk.DeviceQueueCreateInfo,

    flags: vk.DeviceCreateFlags = .{},

    p_next: ?*const anyopaque = null,
    p_allocator: ?*const vk.AllocationCallbacks = null,
};
pub fn init(physical_device: core.PhysicalDevice, info: InitInfo, allocator: std.mem.Allocator) !root {
    const features = info.specifications.features.toPhysicalDeviceFeatures();
    const extensions = extensions: {
        var it = info.specifications.extensions.iterator();
        const tmp = try allocator.alloc([*:0]const u8, info.specifications.extensions.count());

        var index: u32 = 0;
        while (it.next()) |extension| : (index += 1) {
            tmp[index] = extension.string();
        }

        break :extensions tmp;
    };
    defer allocator.free(extensions);

    const physical_device_properties = physical_device.getProperties();
    const version: vk.Version = @fromBackingInt(physical_device_properties.api_version);
    log.debug("Creating device({s}({}.{}.{}))", .{
        physical_device_properties.device_name,
        version.major,
        version.minor,
        version.patch,
    });

    const handle = try physical_device.createDevice(.{
        .flags = info.flags,
        .p_next = info.p_next,

        .p_enabled_features = &features,

        .pp_enabled_extension_names = extensions.ptr,
        .enabled_extension_count = @intCast(extensions.len),

        .p_queue_create_infos = info.queue_create_infos.ptr,
        .queue_create_info_count = @intCast(info.queue_create_infos.len),
    }, info.p_allocator);

    return .{
        .handle = handle,
        .physical_device = physical_device,
        .specifications = info.specifications,
        .dispatch = .load(handle, physical_device.dispatch.dispatch.vkGetDeviceProcAddr.?),
    };
}

pub fn deinit(device: root, p_allocator: ?*const vk.AllocationCallbacks) void {
    device.dispatch.destroyDevice(device.handle, p_allocator);
}

pub fn getWrapper(device: root, comptime DispatchType: type) vk.DeviceWrapperWithCustomDispatch(DispatchType) {
    return .load(device.handle, device.dispatch.dispatch.vkGetDeviceProcAddr.?);
}

pub const Builder = struct {
    const Self = @This();

    request: InitInfo,
    allocator: std.mem.Allocator,
    specifications: Specifications,
    physical_device: core.PhysicalDevice,
    queue_create_infos: std.ArrayList(vk.DeviceQueueCreateInfo),

    pub fn init(physical_device: core.PhysicalDevice, allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .queue_create_infos = .empty,
            .physical_device = physical_device,
            .specifications = try .from(physical_device, allocator),
            .request = .{ .specifications = .init, .queue_create_infos = &.{} },
        };
    }

    pub fn deinit(builder: *Self) void {
        builder.queue_create_infos.deinit(builder.allocator);
    }

    pub fn addQueueInfo(builder: *Self, info: vk.DeviceQueueCreateInfo) !void {
        try builder.queue_create_infos.append(builder.allocator, info);
    }

    pub fn enable(builder: *Self, extension: anytype) bool {
        const T = @TypeOf(extension);
        const target = if (comptime T == Extension)
            extension
        else if (Extension.from(extension)) |tmp|
            tmp
        else
            return false;

        return if (builder.specifications.has(target)) supported: {
            builder.request.specifications.extensions.insert(target);

            break :supported true;
        } else false;
    }

    pub fn build(builder: Self) !root {
        var info = builder.request;
        info.queue_create_infos = builder.queue_create_infos.items;

        return .init(builder.physical_device, info, builder.allocator);
    }
};
