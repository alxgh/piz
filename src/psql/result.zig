const std = @import("std");
const cpq = @cImport({
    @cInclude("libpq-fe.h");
});

pub const result = struct {
    const Self = @This();

    res: ?*cpq.PGresult,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, res: ?*cpq.PGresult) Self {
        return Self{
            .res = res,
            .allocator = allocator,
        };
    }
};
