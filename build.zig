const std = @import("std");
const zon = @import("build.zig.zon");

const name = @tagName(zon.name);
const version = std.SemanticVersion.parse(zon.version) catch unreachable;

pub fn build(b: *std.Build) void {
    const config = b.addOptions();
    setup(config) catch @panic("Failed to setup config");
    config.addOption(std.SemanticVersion, "version", version);

    const vulkan = b.dependency("vulkan", .{
        .registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml"),
    }).module("vulkan-zig");

    _ = b.addModule(name, .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan },
            .{ .name = "config", .module = config.createModule() },
        },
    });
}

fn setup(config: *std.Build.Step.Options) !void {
    try config.contents.print(
        config.step.owner.allocator,
        "pub const {f} = {};\n",
        .{ std.zig.fmtId("name"), zon.name },
    );
}
