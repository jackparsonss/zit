pub const logger = @import("log.zig").logger;

pub const constants = struct {
    pub const ROOT_DIR = ".zit";
    pub const OBJECTS_DIR = ROOT_DIR ++ "/objects";
    pub const HEADS_DIR = ROOT_DIR ++ "/refs/heads";
    pub const TAGS_DIR = ROOT_DIR ++ "/refs/tags";
    pub const HEAD_FILE = ROOT_DIR ++ "/HEAD";
};
