pub const Environment = struct {
    pub const EnvironmentConfig = struct {
        API_KEY: []const u8,
    };

    config: EnvironmentConfig,

    pub fn create(cfg: EnvironmentConfig) Environment {
        return .{
            .config = cfg,
        };
    }
};
