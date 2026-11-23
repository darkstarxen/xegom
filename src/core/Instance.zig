const root = @This();
const std = @import("std");
const core = @import("root.zig");

const log = core.log;
const vk = core.vulkan;

pub const Extension = enum {
    const Self = @This();
    const info = @typeInfo(Self).@"enum";

    const strings = std.EnumArray(Self, [:0]const u8).init(init_values: {
        var tmp: std.enums.EnumFieldStruct(Self, [:0]const u8, null) = undefined;
        for (info.field_names) |name| {
            @field(tmp, name) = @field(vk.instance_extensions, name).name;
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

    khr_surface,
    khr_xcb_surface,
    khr_xlib_surface,
    khr_win_32_surface,
    khr_android_surface,
    khr_wayland_surface,
    khr_get_physical_device_properties_2,

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
        .extensions = .{},
        .version = vk.API_VERSION_1_0,
    };

    version: vk.Version,
    extensions: std.EnumSet(Extension),

    pub fn from(loader: vk.BaseWrapper, allocator: std.mem.Allocator) !Self {
        var specifications = Self.init;
        if (loader.dispatch.vkEnumerateInstanceVersion != null) {
            specifications.version = @fromBackingInt(try loader.enumerateInstanceVersion());
        }

        const properties = try loader.enumerateInstanceExtensionPropertiesAlloc(null, allocator);
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

/// Vulkan backed handle of this instance,
/// meant for direct read-only use.
handle: vk.Instance,
/// The specifications of this instance,
/// meant for direct read-only use.
specifications: Specifications,
dispatch: vk.InstanceWrapperWithCustomDispatch(struct {
    vkDestroyInstance: ?vk.PfnDestroyInstance = null,
    vkGetInstanceProcAddr: ?vk.PfnGetInstanceProcAddr = null,
    vkEnumeratePhysicalDevices: ?vk.PfnEnumeratePhysicalDevices = null,
}),

pub const InitInfo = struct {
    pub const Info = struct { version: u32, name: [:0]const u8 };

    engine: Info,
    application: Info,
    specifications: Specifications,

    flags: vk.InstanceCreateFlags = .{},
    layers: []const [*:0]const u8 = &.{},

    p_next: ?*const anyopaque = null,
    p_allocator: ?*const vk.AllocationCallbacks = null,
};
pub fn init(loader: vk.BaseWrapper, info: InitInfo, allocator: std.mem.Allocator) !root {
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

    log.debug("Creating instance({}.{}.{})", .{
        info.specifications.version.major,
        info.specifications.version.minor,
        info.specifications.version.patch,
    });

    const handle = try loader.createInstance(&.{
        .flags = info.flags,
        .p_next = info.p_next,

        .pp_enabled_layer_names = info.layers.ptr,
        .enabled_layer_count = @intCast(info.layers.len),

        .pp_enabled_extension_names = extensions.ptr,
        .enabled_extension_count = @intCast(extensions.len),

        .p_application_info = &.{
            .p_engine_name = info.engine.name,
            .engine_version = info.engine.version,

            .p_application_name = info.application.name,
            .application_version = info.application.version,

            .api_version = info.specifications.version.toU32(),
        },
    }, info.p_allocator);

    return .{
        .handle = handle,
        .specifications = info.specifications,
        .dispatch = .load(handle, loader.dispatch.vkGetInstanceProcAddr.?),
    };
}

pub fn deinit(instance: root, p_allocator: ?*const vk.AllocationCallbacks) void {
    instance.dispatch.destroyInstance(instance.handle, p_allocator);
}

pub fn enumeratePhysicalDevices(instance: root, allocator: std.mem.Allocator) ![]vk.PhysicalDevice {
    return instance.dispatch.enumeratePhysicalDevicesAlloc(instance.handle, allocator);
}

pub fn getWrapper(instance: root, comptime DispatchType: type) vk.InstanceWrapperWithCustomDispatch(DispatchType) {
    return .load(instance.handle, instance.dispatch.dispatch.vkGetInstanceProcAddr.?);
}

pub const Builder = struct {
    const Self = @This();

    request: InitInfo,
    loader: vk.BaseWrapper,
    allocator: std.mem.Allocator,
    specifications: Specifications,
    layers: std.ArrayList([*:0]const u8),

    pub fn init(loader: vk.BaseWrapper, allocator: std.mem.Allocator) !Self {
        return .{
            .layers = .empty,
            .loader = loader,
            .allocator = allocator,
            .request = .{
                .specifications = .init,
                .application = undefined,
                .engine = .{ .version = 0, .name = &.{} },
            },
            .specifications = try .from(loader, allocator),
        };
    }

    pub fn deinit(builder: *Self) void {
        builder.layers.deinit(builder.allocator);
    }

    pub fn setVersion(builder: *Self, version: vk.Version) bool {
        std.debug.assert(version.toU32() >= vk.API_VERSION_1_0.toU32());

        return if (builder.specifications.version.toU32() >= version.toU32()) supported: {
            builder.specifications.version = version;

            break :supported true;
        } else false;
    }

    pub fn addLayer(builder: *Self, layer: [:0]const u8) !void {
        try builder.layers.append(builder.allocator, layer);
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

    pub fn build(builder: Self, application: InitInfo.Info) !root {
        var info = builder.request;
        info.application = application;
        info.layers = builder.layers.items;

        return .init(builder.loader, info, builder.allocator);
    }
};
