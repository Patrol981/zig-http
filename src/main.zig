const std = @import("std");
const root = @import("root.zig");

var _gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main(init: std.process.Init.Minimal) !void {
    var allocator: std.mem.Allocator = undefined;
    const debug = true;
    if (debug) {
        allocator = _gpa.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    var args = try init.args.toSlice(allocator);
    defer allocator.free(args);

    const server = root.server.Server.create(allocator, args[1]);
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
        .name = "/hello_plain",
        .route_type = .Plain,
        .vtable = .{
            .controller_action = helloPlain,
        },
    };

    const lolspector_route: root.router.RouteDefinition = .{
        .name = "/lolspector",
        .relative_path = "../../sites/lolspector",
        .route_type = .Page,
        .vtable = .{ .controller_action = lolspector },
    };

    const hello_riot_route: root.router.RouteDefinition = .{
        .name = "/hello_riot",
        .route_type = .Json,
        .vtable = .{ .controller_action = helloRiot },
    };

    router.addRoute(hello_page_route);
    router.addRoute(hello_json_route);
    router.addRoute(hello_plain_route);
    router.addRoute(lolspector_route);
    router.addRoute(hello_riot_route);
}

pub fn lolspector(server: *root.server.Server) []const u8 {
    const cwd = std.Io.Dir.cwd();

    const data = std.Io.Dir.readFileAlloc(
        cwd,
        server.thread_io.io(),
        "../../sites/lolspector/index.html",
        server.mem_allocator,
        .unlimited,
    ) catch {
        return "Could not read file";
    };
    return data;
}

pub fn lolspector_(server: *root.server.Server) []const u8 {
    const cwd = std.Io.Dir.cwd();
    const io = server.thread_io();
    const allocator = server.mem_allocator;

    const file = cwd.openFile(io, "sites/lolspector/index.html", .{
        .mode = .read_only,
    }) catch {
        return "Could not read file";
    };
    defer file.close(io);

    const stat = file.stat(io) catch {
        return "Failed to stat file";
    };
    std.log.debug("file size from stat: {d}", .{stat.size});
    std.log.debug("file mtime: {d}", .{stat.mtime});

    const buff = allocator.alloc(u8, stat.size) catch {
        return "Failed to allocate buffer";
    };

    const bytes_read = file.readPositionalAll(io, buff, 0) catch {
        allocator.free(buff);
        return "Failed to read file";
    };

    std.log.debug("bytes_read: {d}", .{bytes_read});
    std.log.debug("first 64 bytes: {s}", .{buff[0..@min(64, bytes_read)]});

    return buff[0..bytes_read];
}

pub fn hello(server: *root.server.Server) []const u8 {
    const cwd = std.Io.Dir.cwd();
    const io = server.thread_io.io();
    const allocator = server.mem_allocator;

    const data = std.Io.Dir.readFileAlloc(cwd, io, "sites/hello/index.html", allocator, .unlimited) catch {
        return "Could not read file";
    };
    return data;
}

pub fn helloJson(server: *root.server.Server) []const u8 {
    _ = server;
    return 
    \\{"msg":"Hello Json"}
    ;
}

pub fn helloRiot(server: *root.server.Server) []const u8 {
    const io = server.thread_io.io();
    const allocator = server.mem_allocator;

    var client: std.http.Client = .{
        .allocator = allocator,
        .io = io,
    };
    defer client.deinit();

    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();

    _ = client.fetch(.{
        .method = .GET,
        .location = .{ .url = "https://euw1.api.riotgames.com/lol/clash/v1/tournaments" },
        .extra_headers = &.{
            .{
                .name = "X-Riot-Token",
                .value = server.environment.config.API_KEY,
            },
        },
        .response_writer = &body.writer,
    }) catch {
        std.log.err("[helloRiot] failed to fetch", .{});
        return "";
    };

    const str = body.written();
    return str;
}

pub fn helloPlain(server: *root.server.Server) []const u8 {
    _ = server;
    return "Hello Plain";
}
