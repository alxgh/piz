const std = @import("std");
const cpq = @cImport({
    @cInclude("libpq-fe.h");
});
const result = @import("result.zig").result;

fn from_cstr(value: [*c]const u8) []const u8 {
    return value[0..std.mem.len(value)];
}

pub const Error = error{
    ConnectionFailure,
    QueryError,
};

pub const PingStatus = enum {
    OK,
    REJECT,
    NO_RESPONSE,
    NO_ATTEMPT,

    pub fn str(self: PingStatus) []const u8 {
        return switch (self) {
            .OK => "OK",
            .REJECT => "REJECT",
            .NO_RESPONSE => "NO_RESPONSE",
            .NO_ATTEMPT => "NO_ATTEMPT",
        };
    }
};

pub const Pg = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    connection: *cpq.PGconn,
    conninfo: [*c]const u8,

    pub fn connect(allocator: std.mem.Allocator, conn_str: [*c]const u8) !Self {
        var connection: *cpq.PGconn = undefined;
        if (cpq.PQconnectdb(conn_str)) |conn| {
            connection = conn;
        }

        if (cpq.PQstatus(connection) != cpq.CONNECTION_OK) {
            return Error.ConnectionFailure;
        }

        return Self{
            .allocator = allocator,
            .connection = connection,
            .conninfo = conn_str,
        };
    }

    pub fn ping(self: *Self) !PingStatus {
        var ping_res = cpq.PQping(self.conninfo);
        return switch (ping_res) {
            cpq.PQPING_OK => .OK,
            cpq.PQPING_REJECT => .REJECT,
            cpq.PQPING_NO_RESPONSE => .NO_RESPONSE,
            cpq.PQPING_NO_ATTEMPT => .NO_ATTEMPT,
            else => unreachable,
        };
    }

    pub fn close(self: *Self) void {
        cpq.PQfinish(self.connection);
    }

    pub fn backendPID(self: *Self) i64 {
        return @intCast(cpq.PQbackendPID(self.connection));
    }

    pub fn exec(self: *Self, query: []const u8) !result {
        var res = cpq.PQexec(self.connection, @ptrCast(query));
        errdefer cpq.PQclear(res);
        if (cpq.PQresultStatus(res) != cpq.PGRES_TUPLES_OK) {
            std.debug.print("Query failed: {s}\n", .{cpq.PQerrorMessage(self.connection)});
            return Error.QueryError;
        }
        return result.init(self.allocator, res);
    }

    pub fn find(self: *Self, query: [*c]const u8, comptime return_type: type) !std.ArrayList(return_type) {
        var res = cpq.PQexec(self.connection, query);
        defer cpq.PQclear(res);
        if (cpq.PQresultStatus(res) != cpq.PGRES_TUPLES_OK) {
            std.debug.print("Query failed: {s}\n", .{cpq.PQerrorMessage(self.connection)});
            return Error.QueryError;
        }
        var list = std.ArrayList(return_type).init(self.allocator);
        errdefer list.deinit();
        var nFields = cpq.PQnfields(res);
        const tinfo = @typeInfo(return_type);
        if (tinfo != .Struct) {
            @compileError("Need ot pass a struct to find");
        }
        for (0..@intCast(nFields)) |n| {
            std.debug.print("{s}\n", .{cpq.PQfname(res, @intCast(n))});
        }
        for (0..@intCast(cpq.PQntuples(res))) |i| {
            var row: return_type = undefined;
            for (0..@intCast(nFields)) |j| {
                var value = from_cstr(cpq.PQgetvalue(res, @intCast(i), @intCast(j)));
                var field_name = from_cstr(cpq.PQfname(res, @intCast(j)));
                inline for (tinfo.Struct.fields) |field| {
                    if (std.mem.eql(u8, field.name, field_name)) {
                        switch (field.type) {
                            []const u8, ?[]const u8 => {
                                @field(row, field.name) = value;
                            },
                            bool => {
                                if (std.mem.eql(u8, "t", value)) {
                                    @field(row, field.name) = true;
                                } else {
                                    @field(row, field.name) = false;
                                }
                            },
                            else => {
                                std.debug.print("{s}", .{value});
                            },
                        }
                    }
                }
            }
            try list.append(row);
        }
        return list;
    }
};
