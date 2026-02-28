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
    const hello_page_route: root.router.RouteDefinition = .{
        .name = "/hello_page",
        .relative_path = "sites/hello",
        .route_type = .Page,
        .vtable = .{ .controller_action = hello },
    };

    const hello_json_route: root.router.RouteDefinition = .{
        .name = "/hello_json",
        .route_type = .Json,
        .vtable = .{
            .controller_action = helloJson,
        },
    };

    const hello_plain_route: root.router.RouteDefinition = .{
        .name = "/hello_pain",
        .route_type = .Plain,
        .vtable = .{
            .controller_action = helloPlain,
        },
    };

    router.addRoute(hello_page_route);
    router.addRoute(hello_json_route);
    router.addRoute(hello_plain_route);
}

pub fn hello(allocator: std.mem.Allocator) []const u8 {
    var threaded: std.Io.Threaded = .init(allocator, .{ .environ = .empty });
    defer threaded.deinit();
    const io = threaded.io();

    const cwd = std.Io.Dir.cwd();

    const data = std.Io.Dir.readFileAlloc(cwd, io, "sites/hello/index.html", allocator, .unlimited) catch {
        return "Could not read file";
    };
    return data;
}

const Place = struct { lat: f32, long: f32 };
pub fn helloJson(allocator: std.mem.Allocator) []const u8 {
    var string: std.Io.Writer.Allocating = .init(allocator);
    defer string.deinit();

    const x: Place = .{
        .lat = 51.997664,
        .long = -0.740687,
    };

    string.writer.print("{f}", .{std.json.fmt(x, .{})}) catch {
        @panic("failed to write json");
    };
    return string.written();
}

pub fn helloPlain(allocator: std.mem.Allocator) []const u8 {
    _ = allocator;
    return "Hello Plain";
}
