const std = @import("std");
const router = @import("router.zig");
const http_header = @import("http_header.zig").HttpHeader;

pub const Server = struct {
    mem_allocator: std.mem.Allocator,

    should_close: bool = false,
    router: *router.Router = undefined,

    pub fn create(allocator: std.mem.Allocator) *Server {
        const self = allocator.create(Server) catch {
            @panic("[server] failed to create server");
        };

        self.* = .{
            .mem_allocator = allocator,
            .router = router.Router.create(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Server) void {
        _ = self;
    }

    pub fn host(self: *Server, url: []const u8, port: u16) !void {
        var threaded: std.Io.Threaded = .init(self.mem_allocator, .{ .environ = .empty });
        defer threaded.deinit();
        const io = threaded.io();

        const addr = try std.Io.net.IpAddress.parseIp4(url, port);

        var listener = try addr.listen(io, .{});
        defer listener.deinit(io);

        while (!self.should_close) {
            const conn = try listener.accept(io);
            defer conn.close(io);
            std.log.debug("[conn] Client connected {}", .{conn.socket.address.ip4});

            var reader_buff: [1024]u8 = undefined;
            var writer_buff: [1024]u8 = undefined;

            var writer = conn.writer(io, &writer_buff);
            var reader = conn.reader(io, &reader_buff);

            var http = std.http.Server.init(&reader.interface, &writer.interface);
            var req = try http.receiveHead();

            const target = req.head.target;
            var found_route: bool = false;

            const header_info = http_header.getHeaderInfo(req);
            std.log.debug("[header_info]:\nhost: {s}\norigin: {s}\nres: {s}", .{
                header_info.host,
                header_info.origin,
                header_info.requested_resource_name,
            });

            for (self.router.routes.items) |*route| {
                if (std.mem.eql(u8, target, route.name)) {
                    switch (route.route_type) {
                        router.RouteType.Json => {
                            try handleJson(self.mem_allocator, route, &req);
                        },
                        router.RouteType.Page => {
                            try handlePage(self.mem_allocator, route, &req);
                        },
                        router.RouteType.Plain => {
                            try handlePlain(self.mem_allocator, route, &req);
                        },
                    }
                    found_route = true;
                }
            }

            if (!found_route) {
                switch (header_info.requested_resource_type) {
                    http_header.FetchType.script,
                    http_header.FetchType.image,
                    http_header.FetchType.style,
                    => {
                        var target_route: ?*router.RouteDefinition = null;
                        for (self.router.routes.items) |*route| {
                            if (header_info.containsOrigin(route.name)) {
                                target_route = route;
                                break;
                            }
                        }

                        std.log.warn("[target resource] {any}", .{target_route});
                        if (target_route != null) {
                            const str_result = try std.mem.concat(self.mem_allocator, u8, &.{
                                // header_info.origin,
                                target_route.?.relative_path,
                                target,
                            });

                            std.log.debug("[http server] found resource {s}", .{str_result});
                            try handleResource(self.mem_allocator, &req, str_result);
                        }
                    },
                    else => {
                        std.log.debug("[http server] {any} is not a resource", .{header_info.requested_resource_type});
                    },
                }
            }
            std.log.err("[http server] could not find route at {s} {s}", .{
                target,
                header_info.origin,
            });
            try req.respond("404", .{ .status = .ok });
        }
    }

    pub fn handleResource(
        allocator: std.mem.Allocator,
        req: *std.http.Server.Request,
        path: []const u8,
    ) !void {
        var threaded: std.Io.Threaded = .init(allocator, .{ .environ = .empty });
        defer threaded.deinit();
        const io = threaded.io();

        const cwd = std.Io.Dir.cwd();

        const resource_data = std.Io.Dir.readFileAlloc(cwd, io, path, allocator, .unlimited) catch {
            try req.respond("404", .{ .status = .ok });
            return;
        };

        try req.respond(resource_data, .{ .status = .ok });
    }

    pub fn handleJson(
        allocator: std.mem.Allocator,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(allocator);
        req.head.content_type = "application/json";
        try req.respond(
            data,
            .{
                .status = .ok,
                // .extra_headers = .{
                //     .{ .name = "response-type", .value = "json" },
                // },
            },
        );
        // defer allocator.free(data);
    }

    pub fn handlePlain(
        allocator: std.mem.Allocator,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(allocator);
        try req.respond(data, .{ .status = .ok });
        // defer allocator.free(data);
    }

    pub fn handlePage(
        allocator: std.mem.Allocator,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(allocator);
        try req.respond(data, .{ .status = .ok });
        // defer allocator.free(data);
    }
};
