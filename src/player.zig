const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;

const Generator = @import("generators.zig").Generator;
const GeneratorCtx = @import("generators.zig").GeneratorCtx;
const StackBuffer = @import("buffer.zig").StackBuffer;

const ai = @import("ai.zig");
const colors = @import("colors.zig");
const combat = @import("combat.zig");
const rng = @import("rng.zig");
const literature = @import("literature.zig");
const dijkstra = @import("dijkstra.zig");
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
const mobs = @import("mobs.zig");
const err = @import("err.zig");

const Activity = types.Activity;
const Rect = types.Rect;
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

pub const Ability = enum(usize) {
    Bomb = 0,
    Multiattack = 1,
    Dominate = 2,
    MeatOffering = 3,
    BurningLance = 4,
    Paralyse = 5,
    LivingBolt = 6,
    Invincibility = 7,
    Yoink = 8,

    pub const TOTAL = std.meta.fields(@This()).len;

    pub fn statusInfo(self: Ability) struct { s: Status, d: usize } {
        return switch (self) {
            .Bomb => .{ .s = .A_Bomb, .d = 2 },
            .Multiattack => .{ .s = .A_Multiattack, .d = 4 },
            .Dominate => .{ .s = .A_Dominate, .d = 5 },
            .MeatOffering => .{ .s = .A_MeatOffering, .d = 8 },
            .BurningLance => .{ .s = .A_BurningLance, .d = 6 },
            .Paralyse => .{ .s = .A_Paralyse, .d = 4 },
            .LivingBolt => .{ .s = .A_LivingBolt, .d = 4 },
            .Invincibility => .{ .s = .A_Invincibility, .d = 5 },
            .Yoink => .{ .s = .A_Yoink, .d = 4 },
        };
    }

    pub fn name(self: Ability) []const u8 {
        return switch (self) {
            .Bomb => "Burnt Offering",
            .Multiattack => "Multi-attack",
            .Dominate => "Dominate",
            .MeatOffering => "Meat Offering",
            .BurningLance => "Burning Lance",
            .Paralyse => "Paralyse Foes",
            .LivingBolt => "Living Bolt",
            .Invincibility => "Invincibility",
            .Yoink => "Entrance Foes",
        };
    }

    pub fn char(self: Ability) []const u8 {
        return switch (self) {
            .Bomb => "b",
            .Multiattack => "m",
            else => 'F',
        };
    }

    pub fn description(self: Ability) []const u8 {
        return switch (self) {
            .Bomb => "Attacked enemies become insane, stationary, and explosive.",
            .Multiattack => "While standing on a corpse, attacking an enemy automatically attacks 3 other enemies.",
            .Dominate => "Attacked foes become allies while you continue to rage.",
            .MeatOffering => "You deal 3x damage while standing on a corpse.",
            .BurningLance => "Conjures a burning lance nearby. When you move, the lance will attack foes in a line in the direction you moved, dealing 3x the damage you would deal.",
            .Paralyse => "Each time you attack, all foes in sight become paralysed for 4 turns (stacking).",
            .LivingBolt => "You zip around as living lightning, phasing through foes and dealing 2 electric damage.",
            .Invincibility => "While standing on a corpse, you gain 100% Armor and rFire.",
            .Yoink => "Each turn, all foes in sight get dragged 3 tiles toward you.",
        };
    }
};

pub const AbilityInfo = struct {
    received: bool,
    last_used: usize = 0,
    a: Ability,

    pub fn isActive(self: AbilityInfo) bool {
        return state.player.hasStatus(self.a.statusInfo().s);
    }

    pub fn isCooldown(self: AbilityInfo) ?usize {
        const t = state.player_turns - self.last_used;
        return if (t > 10) null else t;
    }

    pub fn isUsable(self: AbilityInfo) bool {
        return self.received and !self.isActive() and self.isCooldown() == null;
    }

    pub fn activate(self: *AbilityInfo) void {
        assert(self.isUsable());
        state.message(.Info, "Activated ability: {s}", .{self.a.name()});
        state.player.addStatus(self.a.statusInfo().s, 0, .{ .Tmp = self.a.statusInfo().d });
        self.last_used = state.player_turns;
        scores.recordTaggedUsize(.AbilitiesUsed, .{ .s = self.a.name() }, 1);

        if (self.a == .BurningLance) {
            const spawn_c = _getSummonLocation(&mobs.BurningLanceTemplate) orelse {
                state.message(.Info, "Shades of fiery red appear briefly, but nothing else happens.", .{});
                return; // FIXME: shouldn't be doing this, what if there are other triggers?
            };
            state.message(.CombatUnimportant, "A burning lance appears nearby.", .{});

            const mob = mobs.placeMob(state.GPA.allocator(), &mobs.BurningLanceTemplate, spawn_c, .{});
            mob.addStatus(.Lifespan, 0, .{ .Tmp = state.player.isUnderStatus(.A_BurningLance).?.duration.Tmp + 1 });
            state.player.addUnderling(mob);
        }
    }
};
pub const AbilityEntry = struct { w: usize, a: Ability };

pub const CONJ_AUGMENT_DROPS = [_]AbilityEntry{
    .{ .w = 99, .a = .Bomb },
    .{ .w = 99, .a = .Multiattack },
    .{ .w = 99, .a = .Dominate },
    .{ .w = 99, .a = .MeatOffering },
    .{ .w = 99, .a = .BurningLance },
    .{ .w = 99, .a = .Paralyse },
    .{ .w = 99, .a = .LivingBolt },
    .{ .w = 99, .a = .Invincibility },
    .{ .w = 99, .a = .Yoink },
};

pub fn choosePlayerUpgrades() void {
    var augments = StackBuffer(AbilityEntry, Ability.TOTAL).init(&CONJ_AUGMENT_DROPS);
    for (state.player_abilities) |*entry| {
        // Choose an augment...
        //
        const augment = rng.choose2(AbilityEntry, augments.constSlice(), "w") catch err.wat();
        entry.* = .{ .received = false, .a = augment.a };

        // ...and then delete that entry to avoid it being given again
        //
        const index = augments.linearSearch(augment, struct {
            pub fn f(a: AbilityEntry, b: AbilityEntry) bool {
                return a.a == b.a;
            }
        }.f).?;
        _ = augments.orderedRemove(index) catch err.wat(); // FIXME: should be swapRemove()
    }
}

pub fn hasAbility(augment: Ability) bool {
    return for (state.player_abilities) |augment_info| {
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
    ui.drawTextScreen("$aYou read:$.\n\n{s}", .{poster.text});
    return false;
}

pub fn recordStatsAtLevelExit() void {
    var open_space_seen: usize = 0;
    var open_space_total: usize = 0;
    {
        var my: usize = 0;
        while (my < HEIGHT) : (my += 1) {
            var mx: usize = 0;
            while (mx < WIDTH) : (mx += 1) {
                const coord = Coord.new2(state.player.coord.z, mx, my);
                if (state.dungeon.at(coord).type == .Floor) {
                    if (state.memory.contains(coord))
                        open_space_seen += 1;
                    open_space_total += 1;
                }
            }
        }
    }

    scores.recordUsize(.HPExitedWith, state.player.HP);
    scores.recordUsize(.SpaceExplored, open_space_seen * 100 / open_space_total);
}

pub fn triggerStair(cur_stair: Coord, dest_floor: usize) bool {
    recordStatsAtLevelExit();

    // state.message(.Move, "You ascend...", .{});
    _ = ui.drawTextModal("You descend...", .{});

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
        state.player.max_HP += 5;
        state.player.HP += 5;
    }

    // "Garbage-collect" previous level.
    var iter = state.mobs.iterator();
    while (iter.next()) |mob| {
        if (mob.coord.z != cur_stair.z) continue;
        mob.path_cache.clearAndFree();
    }

    return true;
}

pub fn usableAbilities() usize {
    var ctr: usize = 0;
    for (state.player_abilities) |abil| if (abil.isUsable()) {
        ctr += 1;
    };
    return ctr;
}

fn _getSummonLocation(t: *const mobs.MobTemplate) ?Coord {
    // Leave my indented fn calls alone, zig fmt
    // zig fmt: off
    var dijk = dijkstra.Dijkstra.init(state.player.coord, state.mapgeometry, mobs.PLAYER_VISION / 2,
        state.is_walkable, .{ .ignore_mobs = true }, state.GPA.allocator());
    // zig fmt: on
    defer dijk.deinit();

    var spawn_cs = StackBuffer(Coord, 256).init(null);
    dijk: while (dijk.next()) |child| {
        if (!state.player.cansee(child))
            continue;
        var gen = Generator(Rect.rectIter).init(t.mobAreaRect(child));
        while (gen.next()) |childchild|
            if (state.dungeon.at(childchild).mob != null or
                !state.is_walkable(childchild, .{ .right_now = true }))
            {
                continue :dijk;
            };
        spawn_cs.append(child) catch break;
    }
    return if (spawn_cs.len == 0) null else rng.chooseUnweighted(Coord, spawn_cs.constSlice());
}

pub fn summonAngel() void {
    var tries: usize = 10;
    while (tries > 0) : (tries -= 1) {
        const mob_t = rng.chooseUnweighted(mobs.MobTemplate, &mobs.ANGELS);

        const spawn_c = _getSummonLocation(&mob_t) orelse continue;
        state.message(.Info, "$gThe Presence summons a servant.$.", .{});

        const mob = mobs.placeMob(state.GPA.allocator(), &mob_t, spawn_c, .{});
        mob.addStatus(.Lifespan, 0, .{ .Tmp = 5 });
        scores.recordTaggedUsize(.AngelsSeen, .{ .M = mob }, 1);
        return;
    }
}

pub fn setNewCommand() void {
    var direcs = StackBuffer(Direction, 4).init(null);
    for (&CARDINAL_DIRECTIONS) |d| if (state.player.coord.move(d, state.mapgeometry)) |n| {
        const hostile = if (utils.getHostileInDirection(state.player, d)) true else |_| false;
        if (hostile or state.is_walkable(n, .{ .mob = state.player }))
            direcs.append(d) catch err.wat();
    };
    state.rage_command = rng.chooseUnweighted(Direction, direcs.constSlice());
    state.message(.Info, "$gThe Presence speaks.$. $a\"{s}!\"$.", .{state.rage_command.?.name2()});
}

pub fn tickRage() void {
    const slain = scores.get(.KillRecord).BatchUsize.total;
    if (slain >= state.next_ability_at) {
        state.next_ability_at += rng.range(usize, 15, 20);
        if (for (state.player_abilities) |a, i| {
            if (!a.received) break i;
        } else null) |n| {
            state.player_abilities[n].received = true;
            state.message(.Info, "$gThe Presence seems pleased.$. $aNew ability: {s}$.", .{state.player_abilities[n].a.name()});
            scores.recordTaggedUsize(.AbilitiesGranted, .{ .s = state.player_abilities[n].a.name() }, 1);
        }
    }

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
            scores.recordUsize(.TimesEnteredRage, 1);
        }
    } else {
        if (enemies == 0) {
            decreaseRage(0);
            state.message(.Info, "Your mind seems clear again.", .{});
        }
    }

    if (state.player_rage == 0) {
        state.rage_command = null;
    } else if (state.player_rage == state.RAGE_P_ABIL and usableAbilities() > 0) {
        increaseRage();
        ui.drawZapScreen();
    } else if (state.player_rage == state.RAGE_P_ANGEL) {
        decreaseRage(4);
        summonAngel();
    }

    if (state.player_rage > 0) {
        setNewCommand();
    }
}

pub fn tickRageEnd() void {
    if (state.player_rage == 0) return;
    assert(state.rage_command != null);

    const last_action = state.player.activities.current().?;
    const d = if (last_action == .Move) last_action.Move else if (last_action == .Attack) last_action.Attack.direction else null;

    if (d != null and d.? == state.rage_command.?) {
        increaseRage();
        scores.recordTaggedUsize(.CommandsObeyed, .{ .s = state.rage_command.?.name2() }, 1);
    } else {
        decreaseRage(null);
        scores.recordTaggedUsize(.CommandsDisobeyed, .{ .s = state.rage_command.?.name2() }, 1);
    }
}

pub fn increaseRage() void {
    state.player_rage = math.min(state.MAX_RAGE, state.player_rage + 1);
}

pub fn decreaseRage(to: ?usize) void {
    if (to) |u|
        state.player_rage = u
    else
        state.player_rage -|= 2;

    if (state.player_rage == 0)
        state.player.addStatus(.Exhausted, 0, .{ .Tmp = 15 });
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
                        ui.labels.addAt(fc, state.levelinfo[s.?].name, .{ .color = colors.AQUAMARINE, .last_for = 3 }),
                    else => {},
                };
            }

            memorizeTile(fc, .Immediate);
        }
    };
}

pub fn isStandingOnCorpse() bool {
    return state.dungeon.at(state.player.coord).surface != null and
        state.dungeon.at(state.player.coord).surface.? == .Corpse;
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
            if (!movementTriggersA(direction)) {
                movementTriggersB(direction);
                state.player.declareAction(Activity{ .Move = direction });
                return true;
            }

            const bonus: usize = if (state.player.hasStatus(.A_MeatOffering) and isStandingOnCorpse()) 300 else 100;
            state.player.fight(mob, .{ .damage_bonus = bonus });

            if (state.player.hasStatus(.A_Multiattack) and isStandingOnCorpse()) {
                const ds = if (direction.is_diagonal()) &DIAGONAL_DIRECTIONS else &CARDINAL_DIRECTIONS;
                for (ds) |d| if (state.player.coord.move(d, state.mapgeometry)) |n| if (state.dungeon.at(n).mob) |omob| {
                    if (state.player.isHostileTo(omob) and omob != mob) {
                        state.player.fight(omob, .{ .free_attack = true, .auto_hit = true, .damage_bonus = bonus });
                    }
                };
            }

            movementTriggersB(direction);
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
    if (state.player.hasStatus(.A_LivingBolt)) {
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

        spells.BOLT_BLINKBOLT.use(state.player, state.player.coord, last_coord, .{ .MP_cost = 0, .spell = &spells.BOLT_BLINKBOLT, .power = 2 });

        return false;
    }

    return true;
}

pub fn movementTriggersB(direction: Direction) void {
    if (state.player.hasStatus(.A_BurningLance)) {
        state.player.squad.?.trimMembers();
        const lance = for (state.player.squad.?.members.constSlice()) |mob| {
            if (mem.eql(u8, mob.id, "burning_lance")) {
                break mob;
            }
        } else unreachable;
        const target = utils.getFarthestWalkableCoord(direction, lance.coord, .{ .only_if_breaks_lof = true, .ignore_mobs = true });
        const damage = state.player.listOfWeapons().constSlice()[0].damage * 3;
        spells.BOLT_SPINNING_SWORD.use(lance, lance.coord, target, .{ .MP_cost = 0, .free = true, .power = damage });
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
