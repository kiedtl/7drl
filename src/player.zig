const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;

const StackBuffer = @import("buffer.zig").StackBuffer;

const ai = @import("ai.zig");
const colors = @import("colors.zig");
const combat = @import("combat.zig");
const rng = @import("rng.zig");
const literature = @import("literature.zig");
const explosions = @import("explosions.zig");
const items = @import("items.zig");
const utils = @import("utils.zig");
const mapgen = @import("mapgen.zig");
const surfaces = @import("surfaces.zig");
const spells = @import("spells.zig");
const ui = @import("ui.zig");
const state = @import("state.zig");
const types = @import("types.zig");
const scores = @import("scores.zig");
const err = @import("err.zig");

const Activity = types.Activity;
const Coord = types.Coord;
const Tile = types.Tile;
const Item = types.Item;
const Ring = types.Ring;
const Weapon = types.Weapon;
const Resistance = types.Resistance;
const StatusDataInfo = types.StatusDataInfo;
const Armor = types.Armor;
const SurfaceItem = types.SurfaceItem;
const Mob = types.Mob;
const MobArrayList = types.MobArrayList;
const Status = types.Status;
const Machine = types.Machine;
const Direction = types.Direction;
const Inventory = types.Mob.Inventory;

const DIRECTIONS = types.DIRECTIONS;
const CARDINAL_DIRECTIONS = types.CARDINAL_DIRECTIONS;
const DIAGONAL_DIRECTIONS = types.DIAGONAL_DIRECTIONS;
const LEVELS = state.LEVELS;
const HEIGHT = state.HEIGHT;
const WIDTH = state.WIDTH;

pub var wiz_lidless_eye: bool = false;

pub const ConjAugment = enum(usize) {
    // Survival,
    Melee = 0,
    Evade = 1,
    WallDisintegrate1 = 2,
    WallDisintegrate2 = 3,
    UndeadBloodthirst = 4,
    rElec_25 = 5,
    rElec_50 = 6,
    rFire_25 = 7,
    rFire_50 = 8,

    pub const TOTAL = std.meta.fields(@This()).len;

    pub fn name(self: ConjAugment) []const u8 {
        return switch (self) {
            .WallDisintegrate1 => "Wall Disintegration [1]",
            .WallDisintegrate2 => "Wall Disintegration [2]",
            .rFire_25 => "rFire+25",
            .rFire_50 => "rFire+50",
            .rElec_25 => "rElec+25",
            .rElec_50 => "rElec+50",
            .UndeadBloodthirst => "Undead Bloodthirst",
            .Melee => "+Melee",
            .Evade => "+Evasion",
        };
    }

    pub fn char(self: ConjAugment) []const u8 {
        return switch (self) {
            // .Survival => "Opposing spectral sabres will not always destroy your own. (TODO: update)",
            .WallDisintegrate1 => "$aw$.",
            .WallDisintegrate2 => "$aw+$.",
            .rFire_25 => "$rF$.",
            .rFire_50 => "$rF+$.",
            .rElec_25 => "$bE$.",
            .rElec_50 => "$bE+$.",
            .UndeadBloodthirst => "u",
            .Melee => "m",
            .Evade => "v",
        };
    }

    pub fn description(self: ConjAugment) []const u8 {
        return switch (self) {
            // .Survival => "Opposing spectral sabres will not always destroy your own. (TODO: update)",
            .WallDisintegrate1 => "A single nearby wall disintegrates into a new sabre when there are other sabres in your vision.",
            .WallDisintegrate2 => "Two nearby walls disintegrate into new sabres when there are other sabres in your vision.",
            .rFire_25 => "Your sabres possess +25% rFire.",
            .rFire_50 => "Your sabres possess +50% rFire.",
            .rElec_25 => "Your sabres possess +25% rElec.",
            .rElec_50 => "Your sabres possess +50% rElec.",
            .UndeadBloodthirst => "A new volley of sabres spawn when you see a hostile undead die.",
            .Melee => "Your sabres possess +25% Melee.",
            .Evade => "Your sabres possess +25% Evade.",
        };
    }
};

pub const ConjAugmentInfo = struct { received: bool, a: ConjAugment };
pub const ConjAugmentEntry = struct { w: usize, a: ConjAugment };

pub const CONJ_AUGMENT_DROPS = [_]ConjAugmentEntry{
    // .{ .w = 99, .a = .Survival },
    .{ .w = 99, .a = .WallDisintegrate1 },
    .{ .w = 25, .a = .WallDisintegrate2 },
    .{ .w = 50, .a = .rFire_25 },
    .{ .w = 50, .a = .rFire_50 },
    .{ .w = 99, .a = .rElec_25 },
    .{ .w = 99, .a = .rElec_50 },
    .{ .w = 50, .a = .UndeadBloodthirst },
    .{ .w = 99, .a = .Melee },
    .{ .w = 50, .a = .Evade },
};

pub const PlayerUpgradeInfo = struct {
    recieved: bool = false,
    upgrade: PlayerUpgrade,
};

pub const PlayerUpgrade = enum {
    Agile,
    OI_Enraged,
    Healthy,
    Will,
    Echolocating,

    pub const TOTAL = std.meta.fields(@This()).len;
    pub const UPGRADES = [_]PlayerUpgrade{ .Agile, .OI_Enraged, .Healthy, .Will, .Echolocating };

    pub fn name(self: PlayerUpgrade) []const u8 {
        return switch (self) {
            .Agile => "Agility",
            .OI_Enraged => "Inner Rage",
            .Healthy => "Robust",
            .Will => "Hardened Will",
            .Echolocating => "Echolocation",
        };
    }

    pub fn announce(self: PlayerUpgrade) []const u8 {
        return switch (self) {
            .Agile => "You are good at evading blows.",
            .OI_Enraged => "You feel hatred building up inside.",
            .Healthy => "You are unusually robust.",
            .Will => "Your will hardens.",
            .Echolocating => "Your sense of hearing becomes acute.",
        };
    }

    pub fn description(self: PlayerUpgrade) []const u8 {
        return switch (self) {
            .Agile => "You have a +20% dodging bonus.",
            .OI_Enraged => "You become enraged when badly hurt.",
            .Healthy => "You have 50% more health than usual.",
            .Will => "You have 3 extra pips of willpower.",
            .Echolocating => "You passively echolocate areas around sound.",
        };
    }

    pub fn implement(self: PlayerUpgrade) void {
        switch (self) {
            .Agile => state.player.stats.Evade += 10,
            .OI_Enraged => state.player.ai.flee_effect = .{
                .status = .Enraged,
                .duration = .{ .Tmp = 10 },
                .exhausting = true,
            },
            .Healthy => state.player.max_HP = state.player.max_HP * 150 / 100,
            .Will => state.player.stats.Willpower += 3,
            .Echolocating => state.player.addStatus(.Echolocation, 7, .Prm),
        }
    }
};

pub fn choosePlayerUpgrades() void {
    var upgrades = PlayerUpgrade.UPGRADES;
    rng.shuffle(PlayerUpgrade, &upgrades);

    var i: usize = 0;
    for (state.levelinfo) |level| if (level.upgr) {
        state.player_upgrades[i] = .{ .recieved = false, .upgrade = upgrades[i] };
        i += 1;
    };

    var augments = StackBuffer(ConjAugmentEntry, ConjAugment.TOTAL).init(&CONJ_AUGMENT_DROPS);
    for (state.player_conj_augments) |*entry| {
        // Choose an augment...
        //
        const augment = rng.choose2(ConjAugmentEntry, augments.constSlice(), "w") catch err.wat();
        entry.* = .{ .received = false, .a = augment.a };

        // ...and then delete that entry to avoid it being given again
        //
        const index = augments.linearSearch(augment, struct {
            pub fn f(a: ConjAugmentEntry, b: ConjAugmentEntry) bool {
                return a.a == b.a;
            }
        }.f).?;
        _ = augments.orderedRemove(index) catch err.wat(); // FIXME: should be swapRemove()
    }
}

pub fn hasAugment(augment: ConjAugment) bool {
    return for (state.player_conj_augments) |augment_info| {
        if (augment_info.received and augment_info.a == augment)
            break true;
    } else false;
}

pub fn hasAlignedNC() bool {
    return repPtr().* > 0;
}

pub fn repPtr() *isize {
    return &state.night_rep[@enumToInt(state.player.faction)];
}

pub fn triggerPoster(coord: Coord) bool {
    const poster = state.dungeon.at(coord).surface.?.Poster;
    ui.drawTextScreen("$oYou read:$.\n\n{s}", .{poster.text});
    return false;
}

pub fn triggerStair(cur_stair: Coord, dest_floor: usize) bool {
    // state.message(.Move, "You ascend...", .{});
    _ = ui.drawTextModal("You ascend...", .{});

    mapgen.initLevel(dest_floor);

    const dest_stair = state.dungeon.entries[dest_floor];
    const dest = for (&DIRECTIONS) |d| {
        if (dest_stair.move(d, state.mapgeometry)) |neighbor| {
            if (state.is_walkable(neighbor, .{ .right_now = true }))
                break neighbor;
        }
    } else err.bug("Unable to find passable tile near upstairs!", .{});

    if (!state.player.teleportTo(dest, null, false, false)) {
        err.bug("Unable to ascend stairs! (something's in the way, maybe?)", .{});
    }

    if (state.levelinfo[state.player.coord.z].upgr) {
        state.player.max_HP += 1;

        const upgrade = for (state.player_upgrades) |*u| {
            if (!u.recieved)
                break u;
        } else err.bug("Cannot find upgrade to grant! (upgrades: {} {} {})", .{
            state.player_upgrades[0], state.player_upgrades[1], state.player_upgrades[2],
        });

        upgrade.recieved = true;
        state.message(.Info, "You feel different... {s}", .{upgrade.upgrade.announce()});
        upgrade.upgrade.implement();
    }

    const rep = &state.night_rep[@enumToInt(state.player.faction)];
    if (rep.* < 0) rep.* += 1;

    combat.disruptAllUndead(dest_stair.z);

    // "Garbage-collect" previous level.
    var iter = state.mobs.iterator();
    while (iter.next()) |mob| {
        if (mob.coord.z != cur_stair.z) continue;
        mob.path_cache.clearAndFree();
    }

    return true;
}

pub fn tickRage() void {
    var enemies: usize = 0;
    for (&DIRECTIONS) |d| {
        if (utils.getHostileInDirection(state.player, d)) |_| {
            enemies += 1;
        } else |_| {}
    }

    if (state.player_rage == 0) {
        if (enemies >= 4 and !state.player.hasStatus(.Exhausted)) {
            state.player_rage = 5;
            state.message(.Info, "You enter a martial trance.", .{});
        }
    } else {
        if (enemies == 0) {
            decreaseRage(true);
            state.message(.Info, "Your mind seems clear again.", .{});
        }
    }

    if (state.player_rage == 0) {
        state.rage_command = null;
    } else {
        var direcs = StackBuffer(Direction, 4).init(null);
        for (&CARDINAL_DIRECTIONS) |d| if (state.player.coord.move(d, state.mapgeometry)) |n| {
            const hostile = if (utils.getHostileInDirection(state.player, d)) true else |_| false;
            if (hostile or state.is_walkable(n, .{ .mob = state.player }))
                direcs.append(d) catch err.wat();
        };
        state.rage_command = rng.chooseUnweighted(Direction, direcs.constSlice());
        state.message(.Info, "$GThe Presence seems to speak.$. $o\"{s}!\"$.", .{state.rage_command.?.name2()});
    }
}

pub fn tickRageEnd() void {
    if (state.player_rage == 0) return;
    assert(state.rage_command != null);

    const last_action = state.player.activities.current().?;
    const d = if (last_action == .Move) last_action.Move else if (last_action == .Attack) last_action.Attack.direction else null;

    if (d != null and d.? == state.rage_command.?) {
        increaseRage();
    } else {
        decreaseRage(false);
    }
}

pub fn increaseRage() void {
    state.player_rage = math.min(30, state.player_rage + 1);
}

pub fn decreaseRage(exit_rage: bool) void {
    if (exit_rage)
        state.player_rage = 0
    else
        state.player_rage -= 1;

    if (state.player_rage == 0)
        state.player.addStatus(.Exhausted, 0, .{ .Tmp = 5 });
}

// Iterate through each tile in FOV:
// - Add them to memory.
// - If they haven't existed in memory before as an .Immediate tile, check for
//   things of interest (items, machines, etc) and announce their presence.
pub fn bookkeepingFOV() void {
    for (state.player.fov) |row, y| for (row) |_, x| {
        if (state.player.fov[y][x]) {
            const fc = Coord.new2(state.player.coord.z, x, y);

            var was_already_seen: bool = false;
            if (state.memory.get(fc)) |memtile|
                if (memtile.type == .Immediate) {
                    was_already_seen = true;
                };

            if (!was_already_seen) {
                if (state.dungeon.at(fc).surface) |surf| switch (surf) {
                    .Machine => |m| if (m.announce)
                        //S._addToAnnouncements(SBuf.init(m.name), &announcements),
                        ui.labels.addAt(fc, m.name, .{ .color = colors.LIGHT_STEEL_BLUE, .last_for = 5 }),
                    .Stair => |s| if (s != null)
                        //S._addToAnnouncements(SBuf.init("upward stairs"), &announcements),
                        ui.labels.addAt(fc, state.levelinfo[s.?].name, .{ .color = colors.GOLD, .last_for = 5 }),
                    else => {},
                };
            }

            memorizeTile(fc, .Immediate);
        }
    };
}

pub fn tryRest() bool {
    if (state.player.hasStatus(.Pain)) {
        ui.drawAlertThenLog("You cannot rest while in pain!", .{});
        return false;
    }

    state.player.rest();
    return true;
}

pub fn moveOrFight(direction: Direction) bool {
    const current = state.player.coord;

    const dest = current.move(direction, state.mapgeometry) orelse return false;

    // Does the player want to trigger a machine that requires confirmation, or
    // maybe rummage a container?
    //
    if (state.dungeon.at(dest).surface) |surf| switch (surf) {
        .Machine => |m| if (m.evoke_confirm) |msg| {
            if (!ui.drawYesNoPrompt("{s}", .{msg}))
                return false;
        },
        else => {},
    };

    if (direction.is_diagonal() and state.player.isUnderStatus(.Disorient) != null) {
        ui.drawAlertThenLog("You cannot move or attack diagonally whilst disoriented!", .{});
        return false;
    }

    // Does the player want to stab or fight?
    if (state.dungeon.at(dest).mob) |mob| {
        if (state.player_rage > 0 and state.player.isHostileTo(mob)) {
            state.player.fight(mob, .{});
            return true;
        }
    }

    if (!movementTriggersA(direction)) {
        movementTriggersB(direction);
        state.player.declareAction(Activity{ .Move = direction });
        return true;
    }

    const ret = state.player.moveInDirection(direction);
    movementTriggersB(direction);

    if (!state.player.coord.eq(current)) {
        if (state.dungeon.at(state.player.coord).surface) |s| switch (s) {
            .Machine => |m| if (m.player_interact) |interaction| {
                if (m.canBeInteracted(state.player, &interaction)) {
                    state.message(.Info, "$c({s})$. Press $bA$. to activate.", .{m.name});
                } else {
                    state.message(.Info, "$c({s})$. $gCannot be activated.$.", .{m.name});
                }
            },
            else => {},
        };
    }

    return ret;
}

pub fn movementTriggersA(direction: Direction) bool {
    if (state.player.hasStatus(.RingTeleportation)) {
        // Get last enemy in chain of enemies.
        var last_coord = state.player.coord;
        var mob_chain_count: usize = 0;
        while (true) {
            if (last_coord.move(direction, state.mapgeometry)) |coord| {
                last_coord = coord;
                if (utils.getHostileAt(state.player, coord)) |_| {
                    mob_chain_count += 1;
                } else |_| {
                    if (mob_chain_count > 0) {
                        break;
                    }
                }
            } else break;
        }

        spells.BOLT_BLINKBOLT.use(state.player, state.player.coord, last_coord, .{
            .MP_cost = 0,
            .spell = &spells.BOLT_BLINKBOLT,
            .power = math.clamp(mob_chain_count, 2, 5),
        });

        return false;
    }

    return true;
}

pub fn movementTriggersB(direction: Direction) void {
    if (state.player.hasStatus(.RingDamnation) and !direction.is_diagonal()) {
        const power = state.player.isUnderStatus(.RingDamnation).?.power;
        spells.SUPER_DAMNATION.use(
            state.player,
            state.player.coord,
            state.player.coord,
            .{ .MP_cost = 0, .no_message = true, .context_direction1 = direction, .free = true, .power = power },
        );
    }
    if (state.player.hasStatus(.RingElectrocution)) {
        const power = state.player.isUnderStatus(.RingElectrocution).?.power;

        var anim_buf = StackBuffer(Coord, 4).init(null);
        for (&DIAGONAL_DIRECTIONS) |d|
            if (state.player.coord.move(d, state.mapgeometry)) |c|
                anim_buf.append(c) catch err.wat();

        ui.Animation.blink(anim_buf.constSlice(), '*', ui.Animation.ELEC_LINE_FG, .{}).apply();

        for (&DIAGONAL_DIRECTIONS) |d|
            if (utils.getHostileInDirection(state.player, d)) |hostile| {
                hostile.takeDamage(.{
                    .amount = power,
                    .by_mob = state.player,
                    .kind = .Electric,
                }, .{ .noun = "Lightning" });
            } else |_| {};
        state.player.makeNoise(.Combat, .Loud);
    }
}

pub fn activateSurfaceItem(coord: Coord) bool {
    var mach: *Machine = undefined;

    // FIXME: simplify this, DRY
    if (state.dungeon.at(coord).surface) |s| {
        switch (s) {
            .Machine => |m| if (m.player_interact) |_| {
                mach = m;
            } else {
                ui.drawAlertThenLog("You can't activate that.", .{});
                return false;
            },
            else => {
                ui.drawAlertThenLog("There's nothing here to activate.", .{});
                return false;
            },
        }
    } else {
        ui.drawAlertThenLog("There's nothing here to activate.", .{});
        return false;
    }

    const interaction = &mach.player_interact.?;
    mach.evoke(state.player, interaction) catch |e| {
        switch (e) {
            error.UsedMax => ui.drawAlertThenLog("You can't use the {s} again.", .{mach.name}),
            error.NoEffect => if (interaction.no_effect_msg) |msg| {
                ui.drawAlertThenLog("{s}", .{msg});
            },
        }
        return false;
    };

    state.player.declareAction(.Interact);
    if (interaction.success_msg) |msg|
        state.message(.Info, "{s}", .{msg});

    if (mach.player_interact.?.max_use != 0) {
        const left = mach.player_interact.?.max_use - mach.player_interact.?.used;
        if (left == 0) {
            if (interaction.expended_msg) |msg|
                state.message(.Unimportant, "{s}", .{msg});
        } else {
            state.message(.Info, "You can use this {s} {} more times.", .{ mach.name, left });
        }
    }

    return true;
}

pub fn memorizeTile(fc: Coord, mtype: state.MemoryTile.Type) void {
    const memt = state.MemoryTile{ .tile = Tile.displayAs(fc, false), .type = mtype };
    state.memory.put(fc, memt) catch err.wat();
}

pub fn enemiesCanSee(coord: Coord) bool {
    const moblist = state.createMobList(false, true, state.player.coord.z, state.GPA.allocator());
    defer moblist.deinit();

    return b: for (moblist.items) |mob| {
        if (!mob.no_show_fov and mob.ai.is_combative and mob.isHostileTo(state.player) and !mob.should_be_dead()) {
            if (mob.cansee(coord)) {
                break :b true;
            }
        }
    } else false;
}

// Returns true if player is known by any nearby enemies.
pub fn isPlayerSpotted() bool {
    if (state.player_is_spotted.turn_cached == state.player_turns) {
        return state.player_is_spotted.is_spotted;
    }

    const moblist = state.createMobList(false, true, state.player.coord.z, state.GPA.allocator());
    defer moblist.deinit();

    const is_spotted = enemiesCanSee(state.player.coord) or (b: for (moblist.items) |mob| {
        if (!mob.no_show_fov and mob.ai.is_combative and mob.isHostileTo(state.player)) {
            if (ai.isEnemyKnown(mob, state.player))
                break :b true;
        }
    } else false);

    state.player_is_spotted = .{
        .is_spotted = is_spotted,
        .turn_cached = state.player_turns,
    };

    return is_spotted;
}

pub fn canSeeAny(coords: []const ?Coord) bool {
    return for (coords) |m_coord| {
        if (m_coord) |coord| {
            if (state.player.cansee(coord)) {
                break true;
            }
        }
    } else false;
}

pub const RingError = enum {
    HatedByNight,

    pub fn text1(self: @This()) []const u8 {
        return switch (self) {
            .HatedByNight => "hated by the Night",
        };
    }
};

pub fn checkRing(index: usize) ?RingError {
    const ring = getRingByIndex(index).?;
    if (ring.hated_by_nc and hasAlignedNC()) {
        return .HatedByNight;
    }
    return null;
}

pub fn beginUsingRing(index: usize) void {
    const ring = getRingByIndex(index).?;

    if (checkRing(index)) |e| {
        state.message(.Info, "[$o{s}$.] You cannot use this ring ({s}).", .{ ring.name, e.text1() });
        return;
    }

    if (getActiveRing()) |otherring| {
        otherring.activated = false;
        otherring.pattern_checker.reset();
    }

    if (ui.chooseDirection()) |dir| {
        state.message(.Info, "Activated ring $o{s}$....", .{ring.name});

        if (ring.pattern_checker.init.?(state.player, dir, &ring.pattern_checker.state)) |hint| {
            ring.activated = true;

            var strbuf = std.ArrayList(u8).init(state.GPA.allocator());
            defer strbuf.deinit();
            const writer = strbuf.writer();
            writer.print("[$o{s}$.] ", .{ring.name}) catch err.wat();
            formatActivityList(&.{hint}, writer);
            state.message(.Info, "{s}", .{strbuf.items});
        } else |derr| {
            ring.activated = false;
            switch (derr) {
                error.NeedCardinalDirection => state.message(.Info, "[$o{s}$.] error: need a cardinal direction", .{ring.name}),
                error.NeedOppositeWalkableTile => state.message(.Info, "[$o{s}$.] error: needs to have walkable space in the opposite direction", .{ring.name}),
                error.NeedWalkableTile => state.message(.Info, "[$o{s}$.] error: need a walkable space in that direction", .{ring.name}),

                error.NeedOppositeTileNearWalls => state.message(.Info, "[$o{s}$.] error: needs to have walkable space near walls in the opposite direction", .{ring.name}),
                error.NeedTileNearWalls => state.message(.Info, "[$o{s}$.] error: need a walkable space near walls in that direction", .{ring.name}),
                error.NeedHostileOnTile => state.message(.Info, "[$o{s}$.] error: there needs to be a hostile in that direction", .{ring.name}),
                error.NeedOpenSpace => state.message(.Info, "[$o{s}$.] error: need to be in open space (no walls in cardinal directions)", .{ring.name}),
                error.NeedOppositeWalkableTileInFrontOfWall => state.message(.Info, "[$o{s}$.] error: needs to have walkable space in front of wall in opposite direction", .{ring.name}),
                error.NeedLivingEnemy => state.message(.Info, "[$o{s}$.] error: enemy cannot be a construct or undead", .{ring.name}),
            }
        }
    }
}

pub fn getRingIndexBySlot(slot: Mob.Inventory.EquSlot) usize {
    return for (Mob.Inventory.RING_SLOTS) |item, i| {
        if (item == slot) break i + state.default_patterns.len;
    } else err.bug("Tried to get ring index from non-ring slot", .{});
}

pub fn getRingByIndex(index: usize) ?*Ring {
    if (index >= state.default_patterns.len) {
        const rel_index = index - state.default_patterns.len;
        if (rel_index >= Inventory.RING_SLOTS.len) return null;
        return if (state.player.inventory.equipment(Inventory.RING_SLOTS[rel_index]).*) |r| r.Ring else null;
    } else {
        return &state.default_patterns[index];
    }
}

pub fn getActiveRing() ?*Ring {
    const max_rings = state.default_patterns.len + Inventory.RING_SLOTS.len;

    var i: usize = 0;
    return while (i <= max_rings) : (i += 1) {
        if (getRingByIndex(i)) |ring| {
            if (ring.activated)
                break ring;
        }
    } else null;
}

pub fn getRingHints(ring: *Ring) void {
    var buf = StackBuffer(Activity, 16).init(null);

    const chk_func = ring.pattern_checker.funcs[ring.pattern_checker.turns_taken];

    for (&DIRECTIONS) |d| if (state.player.coord.move(d, state.mapgeometry)) |neighbor_tile| {
        const move_activity = Activity{ .Move = d };
        if (state.is_walkable(neighbor_tile, .{ .mob = state.player })) {
            if ((chk_func)(state.player, &ring.pattern_checker.state, move_activity, true))
                buf.append(move_activity) catch err.wat();
        }

        if (state.dungeon.at(neighbor_tile).mob) |neighbor_mob| {
            if (neighbor_mob.isHostileTo(state.player) and neighbor_mob.ai.is_combative) {
                const attack_activity = Activity{ .Attack = .{
                    .who = neighbor_mob,
                    .direction = d,
                    .coord = neighbor_tile,
                } };
                if ((chk_func)(state.player, &ring.pattern_checker.state, attack_activity, true))
                    buf.append(attack_activity) catch err.wat();
            }
        }
    };

    const wait_activity: Activity = .Rest;
    if ((chk_func)(state.player, &ring.pattern_checker.state, wait_activity, true))
        buf.append(wait_activity) catch err.wat();

    if (buf.len == 0) {
        state.message(.Info, "[$o{s}$.] No valid moves!", .{ring.name});
    }

    var strbuf = std.ArrayList(u8).init(state.GPA.allocator());
    defer strbuf.deinit();
    const writer = strbuf.writer();
    writer.print("[$o{s}$.] ", .{ring.name}) catch err.wat();
    formatActivityList(buf.constSlice(), writer);
    state.message(.Info, "{s}", .{strbuf.items});
}

pub fn formatActivityList(activities: []const Activity, writer: anytype) void {
    for (activities) |activity, i| {
        if (i != 0 and i < activities.len - 1)
            writer.print(", ", .{}) catch err.wat()
        else if (i != 0 and i == activities.len - 1)
            writer.print(", or ", .{}) catch err.wat();

        (switch (activity) {
            .Rest => writer.print("wait", .{}),
            .Attack => |d| writer.print("attack $b{}$.", .{d.direction}),
            .Move => |d| writer.print("go $b{}$.", .{d}),
            else => unreachable,
        }) catch err.wat();
    }
}
