const std = @import("std");

pub const RouteVtable = struct {
    controller_action: *const fn () []const u8,
};

pub const RouteDefinition = struct {
    name: []const u8,
    vtable: RouteVtable,
};

pub const Router = struct {
    mem_allcoator: std.mem.Allocator,

    routes: std.ArrayList(RouteDefinition),

    pub fn create(allocator: std.mem.Allocator) *Router {
        const self = allocator.create(Router) catch {
            @panic("[router] failed to create router");
        };
        self.* = .{
            .mem_allcoator = allocator,
            .routes = std.ArrayList(RouteDefinition).initCapacity(allocator, 0) catch {
                @panic("[router] failed to initialize routes");
            },
        };
        return self;
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit(self.mem_allcoator);
    }

    pub fn addRoute(self: *Router, def: RouteDefinition) void {
        self.routes.append(self.mem_allcoator, def) catch {
            std.log.err("[router] failed to append definition", .{});
        };
    }
};
