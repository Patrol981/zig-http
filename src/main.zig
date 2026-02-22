const std = @import("std");
const root = @import("root.zig");

var _gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    var allocator: std.mem.Allocator = undefined;
    const debug = true;
    if (debug) {
        allocator = _gpa.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    const server = root.server.Server.create(allocator);
    defineRoutes(server.router);
    try server.host("127.0.0.1", 8000);
}

pub fn defineRoutes(router: *root.router.Router) void {
    const hello_world_route: root.router.RouteDefinition = .{
        .name = "/hello",
        .vtable = .{ .controller_action = hello },
    };
    router.addRoute(hello_world_route);
}

pub fn hello() []const u8 {
    return "Hello World!";
}
