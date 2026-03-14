const std = @import("std");
const router = @import("router.zig");
const http_header = @import("http_header.zig").HttpHeader;

const Environment = @import("../environment.zig").Environment;

pub const Server = struct {
    mem_allocator: std.mem.Allocator,

    should_close: bool = false,
    router: *router.Router = undefined,

    user_thread: std.Thread = undefined,
    http_thread: std.Thread = undefined,

    thread_io: std.Io.Threaded = undefined,
    blocking_io: std.Io.Threaded = undefined,

    url: []const u8 = undefined,
    port: u16 = 0,

    environment: Environment,

    pub fn create(allocator: std.mem.Allocator, api_key: []const u8) *Server {
        const self = allocator.create(Server) catch {
            @panic("[server] failed to create server");
        };

        self.* = .{
            .mem_allocator = allocator,
            .router = router.Router.create(allocator),
            .environment = Environment.create(.{
                .API_KEY = api_key,
            }),
        };
        return self;
    }

    pub fn deinit(self: *Server) void {
        self.should_close = true;
        self.thread_io.deinit();
        self.http_thread.join();
    }

    pub fn host(self: *Server, url: []const u8, port: u16) !void {
        self.url = url;
        self.port = port;

        self.http_thread = try std.Thread.spawn(
            .{ .allocator = self.mem_allocator },
            hostInternal,
            .{self},
        );

        self.thread_io = .init(self.mem_allocator, .{ .environ = .empty });
        const io = self.thread_io.io();

        var stdout_buffer: [1024]u8 = undefined;
        var stdin_buffer: [1024]u8 = undefined;

        var stdout = std.Io.File.stdout().writer(io, &stdout_buffer);
        var stdin = std.Io.File.stdin().reader(io, &stdin_buffer);

        std.log.debug("[server] started server with api_key: {s}", .{self.environment.config.API_KEY});

        while (true) {
            try stdout.interface.writeAll("> ");
            try stdout.interface.flush();

            const input = try stdin.interface.peekDelimiterExclusive('\n');

            if (input.len == 0) continue;

            switch (input[0]) {
                'p' => try self.reboot(),
                'r' => try self.reloadPages(&stdout.interface),
                'h' => try self.help(&stdout.interface),
                'q' => break,
                else => try stdout.interface.writeAll("Unknown command \n"),
            }

            stdin_buffer = std.mem.zeroes([1024]u8);
            stdin.interface.toss(input.len + 1);
            try stdout.interface.flush();
        }

        try stdout.flush();
    }

    fn reboot(self: *Server) !void {
        self.deinit();
        self.http_thread.join();
        self.http_thread = try std.Thread.spawn(
            .{ .allocator = self.mem_allocator },
            hostInternal,
            .{self},
        );
    }

    fn reloadPages(self: *Server, stdout: *std.Io.Writer) !void {
        const io = self.thread_io.io();
        const src_sites = try std.Io.Dir.cwd().openDir(
            io,
            "../../sites",
            .{
                .iterate = true,
            },
        );

        var it = src_sites.iterate();
        while (try it.next(io)) |item| {
            reloadFolder(io, src_sites, item);
        }

        // var path_buff: [std.fs.max_path_bytes]u8 = undefined;
        // _ = try cwd.realPathFile(io, ".", &path_buff);
        // _ = try cwd.realPath(io, '.', &path_buff);

        _ = stdout;

        // std.log.debug("cwd: {s}", .{path_buff});
    }

    fn reloadFolder(
        io: std.Io,
        src_dir: std.Io.Dir,
        file_entry: std.Io.Dir.Entry,
    ) void {
        _ = src_dir;
        _ = io;

        std.log.debug("{s}", .{file_entry.name});
    }

    fn help(self: *Server, stdout: *std.Io.Writer) !void {
        _ = self;
        try stdout.writeAll("-----------------------\n");
        try stdout.writeAll("|                     |\n");
        try stdout.writeAll("|   HTTP SERVER CLI   |\n");
        try stdout.writeAll("|                     |\n");
        try stdout.writeAll("-----------------------\n");
        try stdout.writeAll("commands:\n");
        try stdout.writeAll("r - refresh\n");
        try stdout.writeAll("p - reboot\n");
        try stdout.writeAll("h - show help\n");
        try stdout.writeAll("q - quit\n");
        try stdout.flush();
    }

    fn hostInternal(self: *Server) !void {
        const io = self.thread_io.io();

        const addr = try std.Io.net.IpAddress.parseIp4(
            self.url,
            self.port,
        );

        var listener = try addr.listen(io, .{});
        defer listener.deinit(io);

        while (!self.should_close) {
            const conn = try listener.accept(io);
            defer conn.close(io);
            std.log.debug("[conn] Client connected {}", .{
                conn.socket.address.ip4,
            });

            var reader_buff: [1024]u8 = undefined;
            var writer_buff: [1024]u8 = undefined;

            var writer = conn.writer(io, &writer_buff);
            var reader = conn.reader(io, &reader_buff);

            var http = std.http.Server.init(
                &reader.interface,
                &writer.interface,
            );
            var req = try http.receiveHead();

            const target = req.head.target;
            var found_route: bool = false;

            const header_info = http_header.getHeaderInfo(req);
            std.log.debug(
                "[header_info]:\nhost: {s}\norigin: {s}\nres: {s}",
                .{
                    header_info.host,
                    header_info.origin,
                    header_info.requested_resource_name,
                },
            );

            for (self.router.routes.items) |*route| {
                if (std.mem.eql(u8, target, route.name)) {
                    switch (route.route_type) {
                        router.RouteType.Json => {
                            try handleJson(
                                self,
                                route,
                                &req,
                            );
                        },
                        router.RouteType.Page => {
                            try handlePage(
                                self,
                                route,
                                &req,
                            );
                        },
                        router.RouteType.Plain => {
                            try handlePlain(
                                self,
                                route,
                                &req,
                            );
                        },
                    }
                    found_route = true;
                }
            }

            if (!found_route) {
                std.log.debug("{any}", .{header_info.requested_resource_type});
                switch (header_info.requested_resource_type) {
                    http_header.FetchType.script,
                    http_header.FetchType.image,
                    http_header.FetchType.style,
                    http_header.FetchType.document,
                    => {
                        var target_route: ?*router.RouteDefinition = null;
                        for (self.router.routes.items) |*route| {
                            if (header_info.containsOrigin(route.name)) {
                                target_route = route;
                                break;
                            }
                        }

                        if (target_route.?.relative_path != null) {
                            std.log.warn("[target resource] {s} {s}", .{
                                target_route.?.name,
                                target_route.?.relative_path.?,
                            });

                            var str_result: []const u8 = undefined;

                            if (target_route.?.relative_path != null) {
                                str_result = try std.mem.concat(
                                    self.mem_allocator,
                                    u8,
                                    &.{
                                        // header_info.origin,
                                        target_route.?.relative_path.?,
                                        target,
                                    },
                                );
                            } else {
                                str_result = target;
                            }

                            std.log.debug("[http server] found resource {s}", .{
                                str_result,
                            });
                            try handleResource(
                                self,
                                &req,
                                str_result,
                            );
                        }
                    },
                    else => {
                        std.log.debug("[http server] {any} is not a resource", .{
                            header_info.requested_resource_type,
                        });
                    },
                }

                if (header_info.requested_with == .fetchPartial) {
                    std.log.debug("[http server] fetch partial detected", .{});

                    var target_route: ?*router.RouteDefinition = null;
                    for (self.router.routes.items) |*route| {
                        if (header_info.containsOrigin(route.name)) {
                            target_route = route;
                            break;
                        }
                    }

                    var str_result: []const u8 = undefined;
                    if (target_route.?.relative_path != null) {
                        str_result = try std.mem.concat(self.mem_allocator, u8, &.{
                            target_route.?.relative_path.?,
                            target,
                        });
                    } else {
                        str_result = target;
                    }

                    std.log.debug("partial fetch dest: {s}", .{str_result});

                    try handleResource(self, &req, str_result);
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
        self: *Server,
        req: *std.http.Server.Request,
        path: []const u8,
    ) !void {
        const cwd = std.Io.Dir.cwd();

        const resource_data = std.Io.Dir.readFileAlloc(
            cwd,
            self.thread_io.io(),
            path,
            self.mem_allocator,
            .unlimited,
        ) catch {
            try req.respond("404", .{ .status = .ok });
            return;
        };

        try req.respond(resource_data, .{ .status = .ok });
    }

    pub fn handleJson(
        self: *Server,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(self);
        std.log.debug("json data: {s}", .{data});
        try req.respond(
            data,
            .{
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                },
            },
        );
    }

    pub fn handlePlain(
        self: *Server,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(self);
        try req.respond(data, .{ .status = .ok });
        // defer allocator.free(data);
    }

    pub fn handlePage(
        self: *Server,
        route: *router.RouteDefinition,
        req: *std.http.Server.Request,
    ) !void {
        const data = route.vtable.controller_action(self);
        try req.respond(data, .{ .status = .ok });
        // defer allocator.free(data);
    }
};
