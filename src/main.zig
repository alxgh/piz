const std = @import("std");
const psql = @import("./psql/psql.zig");

const User = struct {
    email: []const u8,
    is_active: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var pg = try psql.Pg.connect(gpa.allocator(), "host=localhost port=9432 user=auth password=password dbname=auth");
    defer pg.close();
    std.debug.print("ping result: {s}\n", .{(try pg.ping()).str()});
    std.debug.print("backend pid: {}\n", .{pg.backendPID()});
    var res = try pg.exec("SELECT 1 as n;");
    _ = res;
    var users = try pg.find("SELECT * FROM users;", User);
    defer users.deinit();
    for (users.items) |user| {
        std.debug.print("email: {s}, is_active: {}\n", .{ user.email, user.is_active });
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
