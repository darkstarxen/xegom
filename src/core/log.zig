const std = @import("std");
const core = @import("root.zig");

const config = core.config;
const log = std.log.scoped(config.name);

pub const err = log.err;
pub const info = log.info;
pub const warn = log.warn;
pub const debug = log.debug;
