const std = @import("std");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;

const err = @import("err.zig");
const ui = @import("ui.zig");
const state = @import("state.zig");
const rng = @import("rng.zig");
const types = @import("types.zig");
const player = @import("player.zig");
const surfaces = @import("surfaces.zig");
const utils = @import("utils.zig");

const StackBuffer = @import("buffer.zig").StackBuffer;
const BStr = utils.BStr;

const Mob = types.Mob;
const Coord = types.Coord;
const Status = types.Status;
const Tile = types.Tile;
const WIDTH = state.WIDTH;
const HEIGHT = state.HEIGHT;
const LEVELS = state.LEVELS;

pub fn _mobname(m: *const Mob) []const u8 {
    return if (m == state.player) "<player>" else m.ai.profession_name orelse m.species.name;
}

pub const Info = struct {
    version: []const u8,
    dist: []const u8,
    seed: u64,
    username: BStr(128),
    end_datetime: utils.DateTime,
    turns: usize,
    result: []const u8, // "Escaped", "died in darkness", etc
    slain_str: []const u8, // Empty if won/quit
    slain_by_id: []const u8, // Empty if won/quit
    slain_by_name: BStr(32), // Empty if won/quit
    slain_by_captain_id: []const u8, // Empty if won/quit
    slain_by_captain_name: BStr(32), // Empty if won/quit
    level: usize,
    HP: usize,
    maxHP: usize,
    statuses: StackBuffer(types.StatusDataInfo, Status.TOTAL),
    stats: Mob.MobStat,
    surroundings: [SURROUND_RADIUS][SURROUND_RADIUS]u21,
    messages: StackBuffer(Message, MESSAGE_COUNT),
    in_view_ids: StackBuffer([]const u8, 32),
    in_view_names: StackBuffer(BStr(32), 32),
    ability_names: StackBuffer([]const u8, player.Ability.TOTAL),
    ability_descs: StackBuffer([]const u8, player.Ability.TOTAL),

    pub const MESSAGE_COUNT = 30;
    pub const SURROUND_RADIUS = 20;
    pub const Self = @This();
    pub const Message = struct { text: BStr(128), dups: usize };
    pub const Equipment = struct { slot_id: []const u8, slot_name: []const u8, id: []const u8, name: BStr(128) };

    pub fn collect() Self {
        player.recordStatsAtLevelExit();

        // FIXME: should be a cleaner way to do this...
        var s: Self = undefined;

        s.version = @import("build_options").release;
        s.dist = @import("build_options").dist;

        s.seed = rng.seed;

        if (std.process.getEnvVarOwned(state.GPA.allocator(), "USER")) |env| {
            s.username.reinit(env);
            state.GPA.allocator().free(env);
        } else |_| {
            if (std.process.getEnvVarOwned(state.GPA.allocator(), "USERNAME")) |env| {
                s.username.reinit(env);
                state.GPA.allocator().free(env);
            } else |_| {
                s.username.reinit("Lord_of_eggplants");
            }
        }

        s.end_datetime = utils.DateTime.collect();
        s.turns = state.player_turns;

        s.result = switch (state.state) {
            .Game => "Began meditating on the mysteries of eggplants",
            .Win => "Returned the Amulet",
            .Quit => "Overcome by the Fear of death",
            .Lose => b: {
                if (state.player.killed_by) |by| {
                    if (by.faction == .Revgenunkim) {
                        break :b "Failed in the appointed task";
                    }
                }
                break :b "Died on the journey";
            },
        };

        s.slain_str = "";
        s.slain_by_id = "";
        s.slain_by_captain_id = "";
        s.slain_by_name.reinit(null);
        s.slain_by_captain_name.reinit(null);

        if (state.state == .Lose and state.player.killed_by != null) {
            const ldp = state.player.lastDamagePercentage();
            s.slain_str = "killed";
            if (ldp > 30) s.slain_str = "slain";
            if (ldp > 60) s.slain_str = "executed";
            if (ldp > 90) s.slain_str = "demolished";
            if (ldp > 120) s.slain_str = "miserably destroyed";

            const killer = state.player.killed_by.?;
            s.slain_by_id = killer.id;
            s.slain_by_name.reinit(_mobname(killer));

            if (!killer.isAloneOrLeader()) {
                if (killer.squad.?.leader) |leader| {
                    s.slain_by_captain_id = leader.id;
                    s.slain_by_captain_name.reinit(_mobname(leader));
                }
            }
        }

        s.level = state.player.coord.z;
        s.HP = state.player.HP;
        s.maxHP = state.player.max_HP;

        s.statuses.reinit(null);
        var statuses = state.player.statuses.iterator();
        while (statuses.next()) |entry| {
            if (!state.player.hasStatus(entry.key)) continue;
            s.statuses.append(entry.value.*) catch err.wat();
        }

        s.stats = state.player.stats;

        {
            var dy: usize = 0;
            var my: usize = state.player.coord.y -| Info.SURROUND_RADIUS / 2;
            while (dy < Info.SURROUND_RADIUS) : ({
                dy += 1;
                my += 1;
            }) {
                var dx: usize = 0;
                var mx: usize = state.player.coord.x -| Info.SURROUND_RADIUS / 2;
                while (dx < Info.SURROUND_RADIUS) : ({
                    dx += 1;
                    mx += 1;
                }) {
                    if (mx >= WIDTH or my >= HEIGHT) {
                        s.surroundings[dy][dx] = ' ';
                        continue;
                    }

                    const coord = Coord.new2(state.player.coord.z, mx, my);

                    if (state.dungeon.neighboringWalls(coord, true) == 9) {
                        s.surroundings[dy][dx] = ' ';
                    } else if (state.player.coord.eq(coord)) {
                        s.surroundings[dy][dx] = '@';
                    } else {
                        s.surroundings[dy][dx] = @intCast(u21, Tile.displayAs(coord, false).ch);
                    }
                }
            }
        }

        s.messages.reinit(null);
        if (state.messages.items.len > 0) {
            const msgcount = state.messages.items.len - 1;
            var i: usize = msgcount - math.min(msgcount, MESSAGE_COUNT - 1);
            while (i <= msgcount) : (i += 1) {
                const msg = state.messages.items[i];
                s.messages.append(.{
                    .text = BStr(128).init(utils.used(msg.msg)),
                    .dups = msg.dups,
                }) catch err.wat();
            }
        }

        s.in_view_ids.reinit(null);
        s.in_view_names.reinit(null);
        {
            const can_see = state.createMobList(false, true, state.player.coord.z, state.GPA.allocator());
            defer can_see.deinit();
            for (can_see.items) |mob| {
                s.in_view_ids.append(mob.id) catch break;
                s.in_view_names.append(BStr(32).init(_mobname(mob))) catch err.wat();
            }
        }

        s.ability_names.reinit(null);
        s.ability_descs.reinit(null);
        for (state.player_abilities) |aug| if (aug.received) {
            s.ability_names.append(aug.a.name()) catch err.wat();
            s.ability_descs.append(aug.a.description()) catch err.wat();
        };

        return s;
    }
};

pub const Chunk = union(enum) {
    Header: struct { n: []const u8 },
    Stat: struct { s: Stat, n: []const u8, ign0: bool = true },
};

pub const CHUNKS = [_]Chunk{
    .{ .Header = .{ .n = "General" } },
    .{ .Stat = .{ .s = .TurnsSpent, .n = "turns spent" } },
    .{ .Stat = .{ .s = .StatusRecord, .n = "turns w/ statuses" } },
    .{ .Stat = .{ .s = .AbilitiesGranted, .n = "abilities received" } },
    .{ .Stat = .{ .s = .SpaceExplored, .n = "% explored" } },
    .{ .Header = .{ .n = "Combat" } },
    .{ .Stat = .{ .s = .KillRecord, .n = "vanquished foes" } },
    .{ .Stat = .{ .s = .DamageInflicted, .n = "inflicted damage" } },
    .{ .Stat = .{ .s = .DamageEndured, .n = "endured damage" } },
    .{ .Header = .{ .n = "Rages" } },
    .{ .Stat = .{ .s = .TimesEnteredRage, .n = "entered rage" } },
    .{ .Stat = .{ .s = .CommandsObeyed, .n = "disobeyed commands" } },
    .{ .Stat = .{ .s = .CommandsDisobeyed, .n = "obeyed commands" } },
    .{ .Stat = .{ .s = .AbilitiesUsed, .n = "abilities used" } },
    .{ .Stat = .{ .s = .AngelsSeen, .n = "angels seen" } },
};

pub const Stat = enum(usize) {
    TurnsSpent = 0,
    KillRecord = 1,
    StabRecord = 2,
    DamageInflicted = 3,
    DamageEndured = 4,
    StatusRecord = 5,
    ItemsUsed = 6,
    ItemsThrown = 7,
    PatternsUsed = 8,
    RaidedLairs = 9,
    CandlesDestroyed = 10,
    TimesCorrupted = 11,
    TimesEnteredRage = 12,
    HPExitedWith = 13,
    AbilitiesUsed = 14,
    AngelsSeen = 15,
    AbilitiesGranted = 16,
    CommandsObeyed = 17,
    CommandsDisobeyed = 18,
    SpaceExplored = 19,

    pub fn ignoretotal(self: Stat) bool {
        return switch (self) {
            .HPExitedWith => true,
            else => false,
        };
    }

    pub fn stattype(self: Stat) std.meta.FieldEnum(StatValue) {
        return switch (self) {
            .TurnsSpent => .SingleUsize,
            .KillRecord => .BatchUsize,
            .StabRecord => .BatchUsize,
            .DamageInflicted => .BatchUsize,
            .DamageEndured => .BatchUsize,
            .StatusRecord => .BatchUsize,
            .ItemsUsed => .BatchUsize,
            .ItemsThrown => .BatchUsize,
            .PatternsUsed => .BatchUsize,
            .RaidedLairs => .SingleUsize,
            .CandlesDestroyed => .SingleUsize,
            .TimesCorrupted => .BatchUsize,
            .TimesEnteredRage => .SingleUsize,
            .HPExitedWith => .SingleUsize,
            .AbilitiesUsed => .BatchUsize,
            .AngelsSeen => .BatchUsize,
            .AbilitiesGranted => .BatchUsize,
            .CommandsObeyed => .BatchUsize,
            .CommandsDisobeyed => .BatchUsize,
            .SpaceExplored => .SingleUsize,
        };
    }
};

pub const StatValue = struct {
    SingleUsize: SingleUsize = .{},
    BatchUsize: struct {
        total: usize = 0,
        singles: StackBuffer(BatchEntry, 256) = StackBuffer(BatchEntry, 256).init(null),
    },

    pub const BatchEntry = struct {
        id: StackBuffer(u8, 64) = StackBuffer(u8, 64).init(null),
        val: SingleUsize = .{},
    };

    pub const SingleUsize = struct {
        total: usize = 0,
        each: [LEVELS]usize = [1]usize{0} ** LEVELS,

        pub fn jsonStringify(val: SingleUsize, opts: std.json.StringifyOptions, stream: anytype) !void {
            const JsonValue = struct { floor_type: []const u8, floor_name: []const u8, value: usize };
            var object: struct { total: usize, values: StackBuffer(JsonValue, LEVELS) } = .{
                .total = val.total,
                .values = StackBuffer(JsonValue, LEVELS).init(null),
            };

            var c: usize = 0;
            while (c < LEVELS) : (c += 1) if (_isLevelSignificant(c)) {
                const v = JsonValue{
                    .floor_type = state.levelinfo[c].id,
                    .floor_name = state.levelinfo[c].name,
                    .value = val.each[c],
                };
                object.values.append(v) catch err.wat();
            };

            try std.json.stringify(object, opts, stream);
        }
    };
};

pub var data = std.enums.directEnumArray(Stat, StatValue, 0, undefined);

pub fn init() void {
    for (data) |*entry, i|
        if (std.meta.intToEnum(Stat, i)) |_| {
            entry.* = .{};
        } else |_| {};
}

pub fn get(s: Stat) *StatValue {
    return &data[@enumToInt(s)];
}

// XXX: this hidden reliance on state.player.z could cause bugs
// e.g. when recording stats of a level the player just left
pub fn recordUsize(stat: Stat, value: usize) void {
    switch (stat.stattype()) {
        .SingleUsize => {
            if (!stat.ignoretotal())
                data[@enumToInt(stat)].SingleUsize.total += value;
            data[@enumToInt(stat)].SingleUsize.each[state.player.coord.z] += value;
        },
        else => unreachable,
    }
}

pub const Tag = union(enum) {
    M: *Mob,
    I: types.Item,
    s: []const u8,

    pub fn intoString(self: Tag) StackBuffer(u8, 64) {
        return switch (self) {
            .M => |mob| StackBuffer(u8, 64).initFmt("{s}", .{_mobname(mob)}),
            .I => |item| StackBuffer(u8, 64).init((item.shortName() catch err.wat()).slice()),
            .s => |str| StackBuffer(u8, 64).init(str),
        };
    }
};

// XXX: this hidden reliance on state.player.z could cause bugs
// e.g. when recording stats of a level the player just left
pub fn recordTaggedUsize(stat: Stat, tag: Tag, value: usize) void {
    const key = tag.intoString();
    switch (stat.stattype()) {
        .BatchUsize => {
            if (!stat.ignoretotal())
                data[@enumToInt(stat)].BatchUsize.total += value;
            const index: ?usize = for (data[@enumToInt(stat)].BatchUsize.singles.constSlice()) |single, i| {
                if (mem.eql(u8, single.id.constSlice(), key.constSlice())) break i;
            } else null;
            if (index) |i| {
                data[@enumToInt(stat)].BatchUsize.singles.slice()[i].val.total += value;
                data[@enumToInt(stat)].BatchUsize.singles.slice()[i].val.each[state.player.coord.z] += value;
            } else {
                data[@enumToInt(stat)].BatchUsize.singles.append(.{}) catch err.wat();
                data[@enumToInt(stat)].BatchUsize.singles.lastPtr().?.id = key;
                data[@enumToInt(stat)].BatchUsize.singles.lastPtr().?.val.total += value;
                data[@enumToInt(stat)].BatchUsize.singles.lastPtr().?.val.each[state.player.coord.z] += value;
            }
        },
        else => unreachable,
    }
}

fn _isLevelSignificant(level: usize) bool {
    return data[@enumToInt(@as(Stat, .TurnsSpent))].SingleUsize.each[level] > 0;
}

fn exportTextMorgue(info: Info, alloc: mem.Allocator) !std.ArrayList(u8) {
    var buf = std.ArrayList(u8).init(alloc);
    var w = buf.writer();

    try w.print("// Ancient Rage morgue entry @@ {}-{}-{} {}:{}\n", .{ info.end_datetime.Y, info.end_datetime.M, info.end_datetime.D, info.end_datetime.h, info.end_datetime.m });
    try w.print("// Seed: {}\n", .{info.seed});
    try w.print("\n", .{});

    try w.print("{s} the Burdened\n", .{info.username.constSlice()});
    try w.print("\n", .{});
    try w.print("*** {s} ***\n", .{info.result});
    try w.print("\n", .{});

    if (state.state == .Lose or state.state == .Quit) {
        if (info.slain_str.len > 0) {
            try w.print("... {s} by a {s}\n", .{ info.slain_str, info.slain_by_name.constSlice() });
            if (info.slain_by_captain_name.len > 0)
                try w.print("... in service of a {s}\n", .{info.slain_by_captain_name.constSlice()});
        }
    }

    try w.print("... at {s} after {} turns\n", .{ state.levelinfo[info.level].name, info.turns });
    try w.print("... with {}/{} HP\n", .{ info.HP, info.maxHP });
    try w.print("\n", .{});

    try w.print(" State \n", .{});
    try w.print("=======\n", .{});
    try w.print("\n", .{});

    if (info.ability_names.len > 0) {
        try w.print("Abilities:\n", .{});
        for (info.ability_names.constSlice()) |apt, i|
            try w.print("- [{s}] {s}\n", .{ apt, info.ability_descs.data[i] });
        try w.print("\n", .{});
    } else {
        try w.print("You were granted no abilities.\n", .{});
        try w.print("\n", .{});
    }

    const killed = data[@enumToInt(@as(Stat, .KillRecord))].BatchUsize.total;
    try w.print("You slew {} foe(s).\n", .{killed});
    try w.print("\n", .{});

    try w.print(" Circumstances \n", .{});
    try w.print("===============\n", .{});
    try w.print("\n", .{});

    if (info.statuses.len > 0) {
        try w.print("Statuses:\n", .{});
        for (info.statuses.constSlice()) |statusinfo| {
            const sname = statusinfo.status.string(state.player);
            switch (statusinfo.duration) {
                .Prm => try w.print("<Prm> {s}", .{sname}),
                .Equ => try w.print("<Equ> {s}", .{sname}),
                .Tmp => try w.print("<Tmp> {s} ({})", .{ sname, statusinfo.duration.Tmp }),
            }
            try w.print("\n", .{});
        }
    } else {
        try w.print("You had no status effects.\n", .{});
    }
    try w.print("\n", .{});

    try w.print("Last messages:\n", .{});
    for (info.messages.constSlice()) |message| {
        try w.print("- ", .{});
        {
            var f = false;
            for (message.text.constSlice()) |ch| {
                if (f) {
                    f = false;
                    continue;
                } else if (ch == '$') {
                    f = true;
                    continue;
                }
                try w.print("{u}", .{ch});
            }
        }
        if (message.dups > 0) {
            try w.print(" (×{})", .{message.dups + 1});
        }
        try w.print("\n", .{});
    }
    try w.print("\n", .{});

    try w.print("Surroundings:\n", .{});
    for (info.surroundings) |row| {
        for (row) |ch| {
            try w.print("{u}", .{ch});
        }
        try w.print("\n", .{});
    }
    try w.print("\n", .{});

    if (info.in_view_ids.len > 0) {
        try w.print("You could see:\n", .{});

        const R = struct { n: BStr(32), c: usize };
        var records = std.ArrayList(R).init(state.GPA.allocator());
        defer records.deinit();

        for (info.in_view_names.constSlice()) |name| {
            const r = for (records.items) |*rec| {
                if (mem.eql(u8, rec.n.constSlice(), name.constSlice())) break rec;
            } else b: {
                records.append(.{ .n = BStr(32).init(name.constSlice()), .c = 1 }) catch err.wat();
                break :b &records.items[records.items.len - 1];
            };
            r.c += 1;
        }

        for (records.items) |rec| {
            try w.print("- {: >2} {s}\n", .{ rec.c, rec.n.constSlice() });
        }
    } else {
        try w.print("There was nothing in sight.\n", .{});
    }

    // Newlines will be auto-added by header, see below
    // try w.print("\n\n", .{});

    for (&CHUNKS) |chunk| {
        switch (chunk) {
            .Header => |header| {
                try w.print("\n\n", .{});
                try w.print(" {s: <30}", .{header.n});
                try w.print("| ", .{});
                {
                    var c: usize = 0;
                    while (c < LEVELS) : (c += 1) if (_isLevelSignificant(c)) {
                        try w.print("{: <4} ", .{state.levelinfo[c].depth});
                    };
                }
                try w.print("\n-", .{});
                for (header.n) |_|
                    try w.print("-", .{});
                try w.print("-", .{});
                var si: usize = 30 - (header.n.len + 2) + 1;
                while (si > 0) : (si -= 1)
                    try w.print(" ", .{});
                try w.print("| ", .{});
                {
                    var c: usize = 0;
                    while (c < LEVELS) : (c += 1) if (_isLevelSignificant(c)) {
                        try w.print("{s: <4} ", .{state.levelinfo[c].shortname});
                    };
                }
                try w.print("\n", .{});
            },
            .Stat => |stat| {
                const entry = &data[@enumToInt(stat.s)];
                switch (stat.s.stattype()) {
                    .SingleUsize => {
                        try w.print("{s: <24} {: >5} | ", .{ stat.n, entry.SingleUsize.total });
                        {
                            var c: usize = 0;
                            while (c < LEVELS) : (c += 1) if (_isLevelSignificant(c)) {
                                if (stat.ign0 and entry.SingleUsize.each[c] == 0) {
                                    try w.print("-    ", .{});
                                } else {
                                    try w.print("{: <4} ", .{entry.SingleUsize.each[c]});
                                }
                            };
                        }
                        try w.print("\n", .{});
                    },
                    .BatchUsize => {
                        try w.print("{s: <24} {: >5} |\n", .{ stat.n, entry.BatchUsize.total });
                        for (entry.BatchUsize.singles.slice()) |batch_entry| {
                            try w.print("  {s: <22} {: >5} | ", .{ batch_entry.id.constSlice(), batch_entry.val.total });
                            var c: usize = 0;
                            while (c < LEVELS) : (c += 1) if (_isLevelSignificant(c)) {
                                if (stat.ign0 and batch_entry.val.each[c] == 0) {
                                    try w.print("-    ", .{});
                                } else {
                                    try w.print("{: <4} ", .{batch_entry.val.each[c]});
                                }
                            };
                            try w.print("\n", .{});
                        }
                    },
                }
            },
        }
    }

    try w.print("\n", .{});

    return buf;
}

fn exportJsonMorgue(info: Info) !std.ArrayList(u8) {
    var buf = std.ArrayList(u8).init(state.GPA.allocator());
    var w = buf.writer();

    try w.writeAll("{");

    try w.writeAll("\"info\":");
    try std.json.stringify(info, .{}, w);

    try w.writeAll(",\"stats\":{");
    for (&CHUNKS) |chunk, chunk_i| switch (chunk) {
        .Header => {},
        .Stat => |stat| {
            const entry = &data[@enumToInt(stat.s)];
            try w.print("\"{s}\": {{", .{stat.n});
            try w.print("\"type\": \"{s}\",", .{@tagName(stat.s.stattype())});
            switch (stat.s.stattype()) {
                .SingleUsize => {
                    try w.writeAll("\"value\":");
                    try std.json.stringify(entry.SingleUsize, .{}, w);
                },
                .BatchUsize => {
                    try w.writeAll("\"values\": [");
                    for (entry.BatchUsize.singles.slice()) |batch_entry, i| {
                        try w.print("{{ \"name\": \"{s}\", \"value\":", .{batch_entry.id.constSlice()});
                        try std.json.stringify(batch_entry.val, .{}, w);
                        try w.writeAll("}");
                        if (i != entry.BatchUsize.singles.slice().len - 1)
                            try w.writeAll(",");
                    }
                    try w.writeAll("]");
                },
            }
            try w.writeAll("}");

            if (chunk_i != CHUNKS.len - 1)
                try w.writeAll(",");
        },
    };
    try w.writeByte('}');

    try w.writeByte('}');

    return buf;
}

pub fn uploadMorgue(p_info: Info) void {
    var info = p_info;

    switch (ui.drawChoicePrompt("Upload morgue file?", .{}, &[_][]const u8{ "Yes", "Yes (anonymous)", "No" }) orelse 2) {
        0 => {},
        1 => info.username.reinit("Anonymous"),
        2 => return,
        else => unreachable,
    }

    const morgue = exportJsonMorgue(info) catch err.wat();
    defer morgue.deinit();

    // TODO: when upgrading from Zig 0.9.1, remove this
    if (@import("builtin").os.tag == .windows) {
        _ = std.os.windows.WSAStartup(2, 2) catch return;
    }
    defer if (@import("builtin").os.tag == .windows) {
        _ = std.os.windows.WSACleanup() catch {};
    };

    const HOST = "7drl.000webhostapp.com";
    const PORT = 80;

    std.log.info("Connecting to {s}...", .{HOST});
    const stream = std.net.tcpConnectToHost(state.GPA.allocator(), HOST, PORT) catch |e| {
        std.log.info("Could not connect ({e}), aborting.", .{e});
        return;
    };
    defer stream.close();

    std.log.info("Sending content...", .{});
    stream.writer().print("POST /index.php HTTP/1.1\r\n", .{}) catch return;
    stream.writer().print("Host: {s}\r\n", .{HOST}) catch return;
    stream.writer().print("User-Agent: Ancient_Rage\r\n", .{}) catch return;
    stream.writer().print("Content-Type: application/json\r\n", .{}) catch return;
    stream.writer().print("Content-Length: {}\r\n", .{morgue.items.len}) catch return;
    stream.writer().print("\r\n", .{}) catch return;
    stream.writer().print("{s}", .{morgue.items}) catch return;
    stream.writer().print("\r\n", .{}) catch return;

    // ---
    std.log.info("Waiting for response...", .{});
    var response: [2048]u8 = undefined;
    if (stream.read(&response)) |ret| {
        var lines = std.mem.tokenize(u8, response[0..ret], "\n");
        while (lines.next()) |line|
            std.log.info("Response: > {s}", .{line});
    } else |e| {
        std.log.info("Error when reading response: {s}", .{@errorName(e)});
    }
    // ---

}

pub fn createMorgue() Info {
    const info = Info.collect();

    std.os.mkdir("morgue", 0o776) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => {
            std.log.err("Could not create morgue directory: {}", .{e});
            std.log.err("Refusing to write morgue entries.", .{});
            return info;
        },
    };

    {
        const morgue = exportJsonMorgue(info) catch err.wat();
        defer morgue.deinit();

        const filename = std.fmt.allocPrintZ(state.GPA.allocator(), "morgue-{s}-{}-{}-{:0>2}-{:0>2}-{}:{}.json", .{ info.username.constSlice(), rng.seed, info.end_datetime.Y, info.end_datetime.M, info.end_datetime.D, info.end_datetime.h, info.end_datetime.m }) catch err.oom();
        defer state.GPA.allocator().free(filename);

        (std.fs.cwd().openDir("morgue", .{}) catch err.wat()).writeFile(filename, morgue.items[0..]) catch |e| {
            std.log.err("Could not write to morgue file '{s}': {}", .{ filename, e });
            std.log.err("Refusing to write morgue entries.", .{});
            return info;
        };
        std.log.info("Morgue file written to {s}.", .{filename});
    }
    {
        const morgue = exportTextMorgue(info, state.GPA.allocator()) catch err.wat();
        defer morgue.deinit();

        const filename = std.fmt.allocPrintZ(state.GPA.allocator(), "morgue-{s}-{}-{}-{:0>2}-{:0>2}-{}:{}.txt", .{ info.username.constSlice(), rng.seed, info.end_datetime.Y, info.end_datetime.M, info.end_datetime.D, info.end_datetime.h, info.end_datetime.m }) catch err.oom();
        defer state.GPA.allocator().free(filename);

        (std.fs.cwd().openDir("morgue", .{}) catch err.wat()).writeFile(filename, morgue.items[0..]) catch |e| {
            std.log.err("Could not write to morgue file '{s}': {}", .{ filename, e });
            std.log.err("Refusing to write morgue entries.", .{});
            return info;
        };
        std.log.info("Morgue file written to {s}.", .{filename});
    }

    return info;
}
