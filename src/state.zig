const std = @import("std");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const enums = std.enums;

const ai = @import("ai.zig");
const astar = @import("astar.zig");
const err = @import("err.zig");
const player_m = @import("player.zig");
const ui = @import("ui.zig");
const display = @import("display.zig");
const dijkstra = @import("dijkstra.zig");
const mapgen = @import("mapgen.zig");
const mobs_m = @import("mobs.zig");
const fire = @import("fire.zig");
const items = @import("items.zig");
const utils = @import("utils.zig");
const rng = @import("rng.zig");
const literature = @import("literature.zig");
const fov = @import("fov.zig");
const types = @import("types.zig");
const tsv = @import("tsv.zig");

const Squad = types.Squad;
const Mob = types.Mob;
const MessageType = types.MessageType;
const Item = types.Item;
const Coord = types.Coord;
const Dungeon = types.Dungeon;
const Tile = types.Tile;
const Status = types.Status;
const Rect = types.Rect;
const MobList = types.MobList;
const RingList = types.RingList;
const PotionList = types.PotionList;
const ArmorList = types.ArmorList;
const WeaponList = types.WeaponList;
const MachineList = types.MachineList;
const PropList = types.PropList;
const ContainerList = types.ContainerList;
const Message = types.Message;
const MessageArrayList = types.MessageArrayList;
const MobArrayList = types.MobArrayList;
const Direction = types.Direction;
const CARDINAL_DIRECTIONS = types.CARDINAL_DIRECTIONS;

const Alert = @import("alert.zig").Alert;
const SoundState = @import("sound.zig").SoundState;
const EvocableList = @import("items.zig").EvocableList;
const PosterArrayList = literature.PosterArrayList;
const Generator = @import("generators.zig").Generator;
const GeneratorCtx = @import("generators.zig").GeneratorCtx;

pub const GameState = union(enum) { Game, Win, Lose, Quit };
pub const Layout = union(enum) { Unknown, Room: usize };

pub const HEIGHT = 120;
pub const WIDTH = 120;
pub const LEVELS = 6;
pub const PLAYER_STARTING_LEVEL = 0;

// Should only be used directly by functions in main.zig. For other applications,
// should be passed as a parameter by caller.
pub var GPA = std.heap.GeneralPurposeAllocator(.{
    // Probably should enable this later on to track memory usage, if
    // allocations become too much
    .enable_memory_limit = false,

    .safety = true,

    // Probably would enable this later?
    .thread_safe = false,

    .never_unmap = false,

    .stack_trace_frames = 6,
}){};

pub const mapgeometry = Coord.new2(LEVELS, WIDTH, HEIGHT);
pub var dungeon: *Dungeon = undefined;
pub var layout: [LEVELS][HEIGHT][WIDTH]Layout = [1][HEIGHT][WIDTH]Layout{[1][WIDTH]Layout{[1]Layout{.Unknown} ** WIDTH} ** HEIGHT} ** LEVELS;
pub var state: GameState = .Game;
pub var player: *Mob = undefined;
pub var player_inited = false;
pub var player_rage: usize = 0;

pub const MAX_RAGE = 30;

// zig fmt: off
pub var night_rep = [types.Faction.TOTAL]isize{
    //
    // NEC    @   CG   YSM   NC
         0,   0,   0,  -10,  10,
    //
};
// zig fmt: on

pub var sentry_disabled = false;

pub fn mapRect(level: usize) Rect {
    return Rect{ .start = Coord.new2(level, 0, 0), .width = WIDTH, .height = HEIGHT };
}

// XXX: []u8 instead of '[]const u8` because of tsv parsing limits
pub const LevelInfo = struct {
    id: []u8,
    depth: usize,
    shortname: []u8,
    name: []u8,
    upgr: bool,
    optional: bool,
    stairs: [Dungeon.MAX_STAIRS]?[]u8,
};

// Loaded at runtime from data/levelinfo.tsv
pub var levelinfo: [LEVELS]LevelInfo = undefined;

pub var player_upgrades: [3]player_m.PlayerUpgradeInfo = undefined;
pub var player_conj_augments: [player_m.ConjAugment.TOTAL]player_m.ConjAugmentInfo = undefined;

// Cached return value of player.isPlayerSpotted()
pub var player_is_spotted: struct {
    is_spotted: bool,
    turn_cached: usize,
} = .{ .is_spotted = false, .turn_cached = 0 };

pub var default_patterns = [_]types.Ring{
    items.DefaultPinRing,
    items.DefaultChargeRing,
    items.DefaultLungeRing,
    items.DefaultEyepunchRing,
    items.DefaultLeapRing,
};

pub const MemoryTile = struct {
    tile: display.Cell,
    type: Type = .Immediate,

    pub const Type = enum { Immediate, Echolocated, DetectUndead };
};
pub const MemoryTileMap = std.AutoHashMap(Coord, MemoryTile);

pub var memory: MemoryTileMap = undefined;

pub var descriptions: std.StringHashMap([]const u8) = undefined;

pub var rooms: [LEVELS]mapgen.Room.ArrayList = undefined;

pub const MapgenInfos = struct {
    has_vault: bool = false,
};
pub var mapgen_infos = [1]MapgenInfos{.{}} ** LEVELS;

// Data objects
pub var squads: Squad.List = undefined;
pub var mobs: MobList = undefined;
pub var rings: RingList = undefined;
pub var machines: MachineList = undefined;
pub var props: PropList = undefined;
pub var containers: ContainerList = undefined;
pub var evocables: EvocableList = undefined;
pub var alerts: Alert.List = undefined;

pub var ticks: usize = 0;
pub var player_turns: usize = 0;
pub var messages: MessageArrayList = undefined;
pub var score: usize = 0;
pub var destroyed_candles: usize = 0;

// Find the nearest space near a coord in which a monster can be placed.
//
// Will *not* return crd.
//
// Uses state.GPA.allocator()
//
pub fn nextSpotForMob(crd: Coord, mob: ?*Mob) ?Coord {
    var dijk = dijkstra.Dijkstra.init(crd, mapgeometry, 3, is_walkable, .{ .mob = mob, .right_now = true }, GPA.allocator());
    defer dijk.deinit();

    return while (dijk.next()) |child| {
        if (!child.eq(crd) and !dungeon.at(child).prison)
            break child;
    } else null;
}

pub const IsWalkableOptions = struct {
    // Return true only if the tile is walkable *right now*. Otherwise, tiles
    // that *could* be walkable in the future are merely assigned a penalty but
    // are treated as if they are walkable (e.g., tiles with mobs, or tiles with
    // machines that are walkable when powered but not walkable otherwise, like
    // doors).
    //
    right_now: bool = false,

    // Only treat a tile as unwalkable if it breaks line-of-fire.
    //
    // Water and lava tiles will not be considered unwalkable if this is true.
    only_if_breaks_lof: bool = false,

    // Consider a tile with a mob on it walkable.
    ignore_mobs: bool = false,

    mob: ?*const Mob = null,

    _no_multitile_recurse: bool = false,

    // This is a hack to confine astar within a rectangle, not relevant to
    // is_walkable.
    confines: Rect = Rect.new(Coord.new2(0, 0, 0), WIDTH, HEIGHT),
};

// STYLE: change to Tile.isWalkable
pub fn is_walkable(coord: Coord, opts: IsWalkableOptions) bool {
    if (opts.mob != null and opts.mob.?.multitile != null and !opts._no_multitile_recurse) {
        var newopts = opts;
        newopts._no_multitile_recurse = true;
        const l = opts.mob.?.multitile.?;

        var gen = Generator(Rect.rectIter).init(Rect.new(coord, l, l));
        while (gen.next()) |mobcoord|
            if (!is_walkable(mobcoord, newopts))
                return false;

        return true;
    }

    switch (dungeon.at(coord).type) {
        .Wall => return false,
        .Water, .Lava => if (!opts.only_if_breaks_lof) return false,
        else => {},
    }

    // Mob is walkable if:
    // - It's hostile (it's walkable if it's dead!)
    // - It *is* the mob
    // - Mob can swap with it
    //
    if (!opts.ignore_mobs) {
        if (dungeon.at(coord).mob) |other| {
            if (opts.mob) |mob| {
                if (mob != other and !mob.canSwapWith(other, .{})) {
                    return false;
                }
            } else return false;
        }
    }

    if (dungeon.at(coord).surface) |surface| {
        switch (surface) {
            .Machine => |m| {
                if (opts.right_now) {
                    if (!m.isWalkable())
                        return false;
                } else {
                    if (!m.powered_walkable and !m.unpowered_walkable)
                        return false;

                    if (opts.mob) |mob|
                        if (!m.canBePoweredBy(mob) and
                            !m.isWalkable() and m.powered_walkable and !m.unpowered_walkable)
                            return false;
                }
            },
            .Prop => |p| if (!p.walkable) return false,
            .Poster => return false,
            .Stair => return false,
            .Container, .Corpse => {},
        }
    }

    return true;
}

// TODO: move this to utils.zig?
// TODO: actually no, move this to player.zig
pub fn createMobList(include_player: bool, only_if_infov: bool, level: usize, alloc: mem.Allocator) MobArrayList {
    var moblist = std.ArrayList(*Mob).init(alloc);
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new(x, y);

            if (!include_player and coord.eq(player.coord))
                continue;

            if (dungeon.at(Coord.new2(level, x, y)).mob) |mob| {
                if (only_if_infov and !player.cansee(coord))
                    continue;

                // Skip extra areas of multitile creatures to avoid duplicates
                if (mob.multitile != null and !mob.coord.eq(coord))
                    continue;

                moblist.append(mob) catch unreachable;
            }
        }
    }

    const S = struct {
        pub fn _sortFunc(_: void, a: *Mob, b: *Mob) bool {
            if (player.isHostileTo(a) and !player.isHostileTo(b)) return true;
            if (!player.isHostileTo(a) and player.isHostileTo(b)) return false;
            return player.coord.distance(a.coord) < player.coord.distance(b.coord);
        }
    };
    std.sort.insertionSort(*Mob, moblist.items, {}, S._sortFunc);

    return moblist;
}

// Make sound "decay" each tick.
pub fn tickSound(cur_lev: usize) void {
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new2(cur_lev, x, y);
            const cur_sound = dungeon.soundAt(coord);
            cur_sound.state = SoundState.ageToState(ticks - cur_sound.when);
        }
    }
}

pub fn tickSpatter(cur_lev: usize) void {
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new2(cur_lev, x, y);
            const blood = dungeon.at(coord).spatter.getPtr(.Blood);
            if (blood.* > 10)
                blood.* -|= 3;
        }
    }
}

pub fn loadLevelInfo() void {
    const alloc = GPA.allocator();

    var rbuf: [65535]u8 = undefined;
    const data_dir = std.fs.cwd().openDir("data", .{}) catch unreachable;
    const data_file = data_dir.openFile("levelinfo.tsv", .{ .read = true }) catch unreachable;

    const read = data_file.readAll(rbuf[0..]) catch unreachable;

    const result = tsv.parse(LevelInfo, &[_]tsv.TSVSchemaItem{
        .{ .field_name = "id", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
        .{ .field_name = "depth", .parse_to = usize, .parse_fn = tsv.parsePrimitive },
        .{ .field_name = "shortname", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
        .{ .field_name = "name", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
        .{ .field_name = "upgr", .parse_to = bool, .parse_fn = tsv.parsePrimitive },
        .{ .field_name = "optional", .parse_to = bool, .parse_fn = tsv.parsePrimitive },
        .{ .field_name = "stairs", .parse_to = ?[]u8, .is_array = Dungeon.MAX_STAIRS, .parse_fn = tsv.parseOptionalUtf8String, .optional = true, .default_val = null },
    }, .{
        .id = undefined,
        .depth = undefined,
        .shortname = undefined,
        .name = undefined,
        .upgr = undefined,
        .optional = undefined,
        .stairs = undefined,
    }, rbuf[0..read], alloc);

    if (!result.is_ok()) {
        err.bug("Can't load data/levelinfo.tsv: {} (line {}, field {})", .{
            result.Err.type,
            result.Err.context.lineno,
            result.Err.context.field,
        });
    }

    const data = result.unwrap();
    defer data.deinit();

    if (data.items.len != LEVELS) {
        err.bug("Can't load data/levelinfo.tsv: Incorrect number of entries.", .{});
    }

    for (data.items) |row, i|
        levelinfo[i] = row;

    std.log.info("Loaded data/levelinfo.tsv.", .{});
}

pub fn findLevelByName(name: []const u8) ?usize {
    return for (levelinfo) |item, i| {
        if (mem.eql(u8, item.name, name)) break i;
    } else null;
}

pub fn freeLevelInfo() void {
    const alloc = GPA.allocator();

    for (levelinfo) |info| {
        alloc.free(info.id);
        alloc.free(info.shortname);
        alloc.free(info.name);
        for (&info.stairs) |maybe_stair|
            if (maybe_stair) |stair|
                alloc.free(stair);
    }
}

pub fn dialog(by: *const Mob, text: []const u8) void {
    ui.Animation.apply(.{ .PopChar = .{ .coord = by.coord, .char = '!' } });
    message(.Dialog, "{c}: \"{s}\"", .{ by, text });
}

pub fn messageAboutMob2(mob: *const Mob, ref_coord: ?Coord, mtype: MessageType, comptime fmt: []const u8, args: anytype) void {
    messageAboutMob(mob, ref_coord, mtype, fmt, args, fmt, args);
}

pub fn messageAboutMob(
    mob: *const Mob,
    ref_coord: ?Coord,
    mtype: MessageType,
    comptime mob_is_me_fmt: []const u8,
    mob_is_me_args: anytype,
    comptime mob_is_else_fmt: []const u8,
    mob_is_else_args: anytype,
) void {
    var buf: [128]u8 = undefined;
    for (buf) |*i| i.* = 0;
    var fbs = std.io.fixedBufferStream(&buf);

    if (mob == player) {
        std.fmt.format(fbs.writer(), mob_is_me_fmt, mob_is_me_args) catch err.wat();
        message(mtype, "You {s}", .{fbs.getWritten()});
    } else if (player.cansee(mob.coord)) {
        std.fmt.format(fbs.writer(), mob_is_else_fmt, mob_is_else_args) catch err.wat();
        message(mtype, "The {s} {s}", .{ mob.displayName(), fbs.getWritten() });
    } else if (ref_coord != null and player.cansee(ref_coord.?)) {
        std.fmt.format(fbs.writer(), mob_is_else_fmt, mob_is_else_args) catch err.wat();
        message(mtype, "Something {s}", .{fbs.getWritten()});
    }
}

pub fn message(mtype: MessageType, comptime fmt: []const u8, args: anytype) void {
    var buf: [128]u8 = undefined;
    for (buf) |*i| i.* = 0;
    var fbs = std.io.fixedBufferStream(&buf);
    @call(.{ .modifier = .always_inline }, std.fmt.format, .{ fbs.writer(), fmt, args }) catch err.bug("format error", .{});

    var msg: Message = .{
        .msg = undefined,
        .type = mtype,
        .turn = player_turns,
    };
    utils.copyZ(&msg.msg, fbs.getWritten());

    // If the message isn't a prompt, check if the message is a duplicate
    if (mtype != .Prompt and messages.items.len > 0 and mem.eql(
        u8,
        utils.used(messages.items[messages.items.len - 1].msg),
        utils.used(msg.msg),
    )) {
        messages.items[messages.items.len - 1].dups += 1;
    } else {
        messages.append(msg) catch err.oom();
    }
}

pub fn markMessageNoisy() void {
    assert(messages.items.len > 0);
    messages.items[messages.items.len - 1].noise = true;
}
