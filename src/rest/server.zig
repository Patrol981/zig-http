const std = @import("std");
const router = @import("router.zig");

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

            for (self.router.routes.items) |route| {
                if (std.mem.eql(u8, target, route.name)) {
                    found_route = true;
                    const data = route.vtable.controller_action();
                    try req.respond(data, .{ .status = .ok });
                }
            }

            if (!found_route) {
                try req.respond("404", .{ .status = .ok });
            }
        }
    }
};
