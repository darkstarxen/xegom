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
            pair[1] = @field(Self, name);
            pair[0] = pair[1].string();
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

    pub fn string(self: Self) [:0]const u8 {
        return strings.get(self);
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
        var self = Self.init;
        if (loader.dispatch.vkEnumerateInstanceVersion != null) {
            self.version = @fromBackingInt(try loader.enumerateInstanceVersion());
        }

        const properties = try loader.enumerateInstanceExtensionPropertiesAlloc(null, allocator);
        defer allocator.free(properties);

        for (properties) |property| {
            const ptr: [*:0]const u8 = @ptrCast(&property.extension_name);
            const string = std.mem.span(ptr);

            if (Extension.from(string)) |extension|
                self.extensions.insert(extension)
            else
                log.debug("'{s}' is not supported", .{string});
        }

        return self;
    }

    pub fn has(self: Self, extension: Extension) bool {
        return self.extensions.contains(extension);
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
    pub const Info = struct {
        version: u32 = 0,
        name: [:0]const u8 = &.{},
    };

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
        var index: u32 = 0;
        var it = info.specifications.extensions.iterator();
        const tmp = try allocator.alloc([*:0]const u8, info.specifications.extensions.count());

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

pub fn deinit(self: root, p_allocator: ?*const vk.AllocationCallbacks) void {
    self.dispatch.destroyInstance(self.handle, p_allocator);
}

pub fn enumeratePhysicalDevices(self: root, allocator: std.mem.Allocator) ![]vk.PhysicalDevice {
    return self.dispatch.enumeratePhysicalDevicesAlloc(self.handle, allocator);
}

pub fn getWrapper(self: root, comptime DispatchType: type) vk.InstanceWrapperWithCustomDispatch(DispatchType) {
    return .load(self.handle, self.dispatch.dispatch.vkGetInstanceProcAddr.?);
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
                .engine = .{},
                .application = .{},
                .specifications = .init,
            },
            .specifications = try .from(loader, allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.layers.deinit(self.allocator);
    }

    pub fn setVersion(self: *Self, version: vk.Version) bool {
        std.debug.assert(version.toU32() >= vk.API_VERSION_1_0.toU32());

        return if (self.specifications.version.toU32() >= version.toU32()) supported: {
            self.specifications.version = version;

            break :supported true;
        } else false;
    }

    pub fn addLayer(self: *Self, layer: [:0]const u8) !void {
        try self.layers.append(self.allocator, layer);
    }

    pub fn enable(self: *Self, extension: anytype) bool {
        const T = @TypeOf(extension);
        const target = if (comptime T == Extension)
            extension
        else target: {
            if (Extension.from(extension)) |tmp|
                break :target tmp
            else
                return false;
        };

        return if (self.specifications.has(target)) supported: {
            self.request.specifications.extensions.insert(target);

            break :supported true;
        } else false;
    }

    pub fn build(self: Self, application: InitInfo.Info) !root {
        var info = self.request;
        info.application = application;
        info.layers = self.layers.items;

        return .init(self.loader, info, self.allocator);
    }
};
