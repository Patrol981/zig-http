const std = @import("std");

pub const HttpHeader = struct {
    pub const FetchType = enum {
        document,
        script,
        image,
        style,
        font,
        fetch,
        empty,
        unknown,
    };

    pub const RequestedWith = enum {
        fetchPartial,
        none,
    };

    pub const HeaderInfo = struct {
        origin: []const u8,
        host: []const u8,
        requested_resource_name: []const u8,
        requested_resource_type: FetchType = .unknown,
        requested_with: RequestedWith = .none,

        pub fn containsHost(info: HeaderInfo, str: []const u8) bool {
            const result = std.mem.find(u8, info.host, str);
            if (result != null) {
                return true;
            }
            return false;
        }

        pub fn containsOrigin(info: HeaderInfo, str: []const u8) bool {
            const result = std.mem.find(u8, info.origin, str);
            if (result != null) {
                return true;
            }
            return false;
        }
    };

    pub fn getHeaderInfo(req: std.http.Server.Request) HeaderInfo {
        var header_info: HeaderInfo = .{
            .origin = "",
            .host = "",
            .requested_resource_name = "",
            .requested_resource_type = FetchType.unknown,
            .requested_with = RequestedWith.none,
        };

        var iterator = req.iterateHeaders();

        while (iterator.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "host")) {
                header_info.host = header.value;
            } else if (std.ascii.eqlIgnoreCase(header.name, "referer")) {
                header_info.origin = header.value;
            } else if (std.ascii.eqlIgnoreCase(header.name, "sec-fetch-dest")) {
                inline for (std.meta.fields(FetchType)) |field| {
                    if (std.mem.eql(u8, header.value, field.name)) {
                        header_info.requested_resource_type = @field(
                            FetchType,
                            field.name,
                        );
                    }
                }
            } else if (std.ascii.eqlIgnoreCase(header.name, "X-Requested-With")) {
                std.log.debug("[X-Requested-With] {s}", .{header.value});
                if (std.mem.eql(u8, header.value, "fetch-partial")) {
                    header_info.requested_with = .fetchPartial;
                }
            }
        }

        return header_info;
    }
};
