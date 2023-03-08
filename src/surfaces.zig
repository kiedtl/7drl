// TODO: add state to machines

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;
const math = std.math;
const enums = std.enums;

const ui = @import("ui.zig");
const dijkstra = @import("dijkstra.zig");
const spells = @import("spells.zig");
const colors = @import("colors.zig");
const err = @import("err.zig");
const font = @import("font.zig");
const main = @import("root");
const mobs = @import("mobs.zig");
const utils = @import("utils.zig");
const state = @import("state.zig");
const explosions = @import("explosions.zig");
const player = @import("player.zig");
const tsv = @import("tsv.zig");
const rng = @import("rng.zig");
const materials = @import("materials.zig");
const types = @import("types.zig");
const scores = @import("scores.zig");

const Rect = types.Rect;
const Coord = types.Coord;
const Direction = types.Direction;
const Item = types.Item;
const Weapon = types.Weapon;
const Mob = types.Mob;
const Squad = types.Squad;
const Machine = types.Machine;
const PropArrayList = types.PropArrayList;
const Container = types.Container;
const Material = types.Material;
const Vial = types.Vial;
const Prop = types.Prop;
const Stat = types.Stat;
const Resistance = types.Resistance;
const StatusDataInfo = types.StatusDataInfo;

const DIRECTIONS = types.DIRECTIONS;
const CARDINAL_DIRECTIONS = types.CARDINAL_DIRECTIONS;
const LEVELS = state.LEVELS;
const HEIGHT = state.HEIGHT;
const WIDTH = state.WIDTH;

const Generator = @import("generators.zig").Generator;
const GeneratorCtx = @import("generators.zig").GeneratorCtx;

const StackBuffer = @import("buffer.zig").StackBuffer;

// ---

pub var props: PropArrayList = undefined;
pub var prison_item_props: PropArrayList = undefined;
pub var laboratory_item_props: PropArrayList = undefined;
pub var laboratory_props: PropArrayList = undefined;
pub var vault_props: PropArrayList = undefined;
pub var statue_props: PropArrayList = undefined;
pub var weapon_props: PropArrayList = undefined;
pub var bottle_props: PropArrayList = undefined;
pub var tools_props: PropArrayList = undefined;
pub var armors_props: PropArrayList = undefined;

pub const ToolChest = Container{ .name = "tool chest", .tile = 'æ', .capacity = 1, .type = .Evocables };
pub const Wardrobe = Container{ .name = "wardrobe", .tile = 'Æ', .capacity = 1, .type = .Wearables, .item_repeat = 0 };
pub const PotionShelf = Container{ .name = "potion shelf", .tile = 'Æ', .capacity = 3, .type = .Drinkables, .item_repeat = 0 };
pub const WeaponRack = Container{ .name = "weapon rack", .tile = 'π', .capacity = 1, .type = .Smackables, .item_repeat = 0 };
pub const LabCabinet = Container{ .name = "cabinet", .tile = 'π', .capacity = 5, .type = .Utility, .item_repeat = 70 };
pub const VOreCrate = Container{ .name = "crate", .tile = '∐', .capacity = 14, .type = .VOres, .item_repeat = 60 };

pub const LOOT_CONTAINERS = [_]*const Container{ &WeaponRack, &PotionShelf, &Wardrobe, &ToolChest };
pub const LOOT_CONTAINER_WEIGHTS = [LOOT_CONTAINERS.len]usize{ 2, 4, 2, 1 };

pub const MACHINES = [_]Machine{
    StairExit,
    NormalDoor,
    LabDoor,
    VaultDoor,
    LockedDoor,
    SladeDoor,
    HeavyLockedDoor,
    IronVaultDoor,
    GoldVaultDoor,
    Mine,
    Drain,
    Fountain,
    // WaterBarrel,
};

pub const StairExit = Machine{
    .id = "stair_exit",
    .name = "fiery chasm",
    .powered_tile = ':',
    .unpowered_tile = ':',
    .powered_fg = 0xff5347,
    .unpowered_fg = 0xff5347,
    .powered_bg = 0x4b0f0f,
    .unpowered_bg = 0x4b0f0f,
    .powered_walkable = false,
    .unpowered_walkable = false,
    //.powered_sprite = .S_G_StairsUp,
    //.unpowered_sprite = .S_G_StairsUp,
    .on_power = powerStairExit,
};

pub const NormalDoor = Machine{
    .id = "door_normal",
    .name = "door",

    .powered_tile = '\'',
    .unpowered_tile = '+',
    .powered_fg = 0xffaaaa,
    .unpowered_fg = 0xffaaaa,
    .powered_bg = 0x7a2914,
    .unpowered_bg = 0x7a2914,

    .powered_sprite = .S_G_M_DoorOpen,
    .unpowered_sprite = .S_G_M_DoorShut,
    .powered_sfg = 0xba7964,
    .unpowered_sfg = 0xba7964,
    .powered_sbg = colors.BG,
    .unpowered_sbg = colors.BG,

    .power_drain = 49,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .powered_opacity = 0.2,
    .unpowered_opacity = 1.0,
    .flammability = 30, // wooden door is flammable
    .porous = true,
    .on_power = powerNone,
};

pub const LabDoor = Machine{
    .id = "door_lab",
    .name = "door",

    .powered_tile = '+',
    .unpowered_tile = 'x',
    .powered_fg = 0xffdf10,
    .unpowered_fg = 0xffbfff,
    .powered_sprite = .S_O_M_LabDoorOpen,

    .power_drain = 0,
    .power = 100,
    .powered_walkable = false,
    .unpowered_walkable = true,
    .powered_opacity = 1.0,
    .unpowered_opacity = 0.0,
    .flammability = 0, // metal door not flammable
    .porous = true,
    .detect_with_elec = true,
    .on_power = powerLabDoor,
};

pub const VaultDoor = Machine{ // TODO: rename to QuartersDoor
    .id = "door_qrt",
    .name = "iron door",

    .powered_tile = '░',
    .unpowered_tile = '+',
    .powered_fg = 0xaaaaaa,
    .unpowered_bg = 0xffffff,
    .unpowered_fg = colors.BG,

    .powered_sprite = .S_O_M_QrtDoorOpen,
    .unpowered_sprite = .S_O_M_QrtDoorShut,
    .powered_sfg = 0xffffff,
    .powered_sbg = colors.BG,
    .unpowered_sfg = 0xffffff,
    .unpowered_sbg = colors.BG,

    .power_drain = 49,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .powered_opacity = 0.0,
    .unpowered_opacity = 1.0,
    .flammability = 0, // metal door, not flammable
    .porous = true,
    .on_power = powerNone,
};

pub const LockedDoor = Machine{
    .id = "door_locked",
    .name = "locked door",

    .powered_tile = '\'',
    .unpowered_tile = '+',
    .powered_fg = 0x5588ff,
    .unpowered_fg = 0x5588ff,
    .powered_bg = 0x14297a,
    .unpowered_bg = 0x14297a,

    .powered_sprite = .S_G_M_DoorOpen,
    .unpowered_sprite = .S_G_M_DoorShut,
    .powered_sfg = 0x6479ba,
    .unpowered_sfg = 0x6479ba,
    .powered_sbg = colors.BG,
    .unpowered_sbg = colors.BG,

    .power_drain = 90,
    .restricted_to = .CaveGoblins,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .flammability = 30, // also wooden door
    .porous = true,
    .on_power = powerNone,
    .pathfinding_penalty = 5,
    .evoke_confirm = "Break down the locked door?",
    .player_interact = .{
        .name = "break down",
        .needs_power = false,
        .success_msg = "You break down the door.",
        .no_effect_msg = "(This is a bug.)",
        .max_use = 1,
        .func = struct {
            fn f(machine: *Machine, by: *Mob) bool {
                assert(by == state.player);

                machine.disabled = true;
                state.dungeon.at(machine.coord).surface = null;
                return true;
            }
        }.f,
    },
};

pub const SladeDoor = Machine{
    .id = "door_slade",
    .name = "slade door",

    .powered_tile = '\'',
    .unpowered_tile = '+',
    .powered_fg = 0xaaaaff,
    .unpowered_fg = 0xaaaaff,
    .powered_bg = 0x29147a,
    .unpowered_bg = 0x29147a,

    .powered_sprite = .S_G_M_DoorOpen,
    .unpowered_sprite = .S_G_M_DoorShut,
    .powered_sfg = 0x775599,
    .unpowered_sfg = 0x775599,
    .powered_sbg = colors.BG,
    .unpowered_sbg = colors.BG,

    .power_drain = 100,
    .restricted_to = .Night,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .powered_opacity = 0.0,
    .unpowered_opacity = 0.0,
    .porous = false,

    .on_power = struct {
        fn f(m: *Machine) void {
            if (m.last_interaction) |mob| {
                if (mob.multitile != null) return;
                for (&DIRECTIONS) |d| if (m.coord.move(d, state.mapgeometry)) |neighbor| {
                    // A bit hackish
                    if (neighbor.distance(mob.coord) == 2 and state.is_walkable(neighbor, .{ .mob = mob })) {
                        _ = mob.teleportTo(neighbor, null, true, true);
                        return;
                    }
                };

                // const orig = mob.coord;
                // if (state.player.cansee(orig)) {
                //     state.message(.Info, "{c} phases through the door.", .{});
                // }
                // if (state.player.cansee(dest)) {
                //     state.message(.Info, "{c} phases through the door.", .{});
                // }
            }
        }
    }.f,

    .player_interact = .{
        .name = "[this is a bug]",
        .needs_power = false,
        .success_msg = null,
        .no_effect_msg = null,
        .max_use = 0,
        .func = struct {
            fn f(machine: *Machine, by: *Mob) bool {
                assert(by == state.player);

                if (!player.hasAlignedNC()) {
                    if (!ui.drawYesNoPrompt("Trespass on the Lair?", .{}))
                        return false;
                    machine.disabled = true;
                    state.dungeon.at(machine.coord).surface = null;
                    state.message(.Info, "You break down the slade door. ($b-2 rep$.)", .{});
                    scores.recordUsize(.RaidedLairs, 1);
                    player.repPtr().* -= 2;
                } else {
                    assert(machine.addPower(by));
                }

                return true;
            }
        }.f,
    },
};

pub const HeavyLockedDoor = Machine{
    .id = "door_locked_heavy",
    .name = "locked steel door",

    .powered_tile = '\'',
    .unpowered_tile = '+',
    .powered_fg = 0xaaffaa,
    .unpowered_fg = 0xaaffaa,
    .powered_bg = 0x297a14,
    .unpowered_bg = 0x297a14,

    .powered_sprite = .S_G_M_DoorOpen,
    .unpowered_sprite = .S_G_M_DoorShut,
    .powered_sfg = 0x64ba79,
    .unpowered_sfg = 0x64ba79,
    .powered_sbg = colors.BG,
    .unpowered_sbg = colors.BG,

    .power_drain = 90,
    .restricted_to = .CaveGoblins,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .powered_opacity = 0,
    .unpowered_opacity = 1.0,
    .flammability = 0, // not a wooden door at all
    .porous = true,
    .on_power = powerNone,
    .pathfinding_penalty = 5,
};

fn createVaultDoor(comptime id_suffix: []const u8, comptime name_prefix: []const u8, color: u32, alarm_chance: usize) Machine {
    return Machine{
        .id = "door_vault_" ++ id_suffix,
        .name = name_prefix ++ " door",

        .powered_tile = ' ',
        .unpowered_tile = '+',
        .powered_fg = colors.percentageOf(color, 130),
        .unpowered_fg = colors.percentageOf(color, 130),
        .powered_bg = colors.percentageOf(color, 40),
        .unpowered_bg = colors.percentageOf(color, 40),

        .powered_sprite = .S_O_M_QrtDoorOpen,
        .unpowered_sprite = .S_O_M_QrtDoorShut,
        .powered_sfg = colors.percentageOf(color, 150),
        .unpowered_sfg = colors.percentageOf(color, 150),
        .powered_sbg = colors.BG,
        .unpowered_sbg = colors.BG,

        .power_drain = 0,
        .restricted_to = .Player,
        .powered_walkable = true,
        .unpowered_walkable = false,
        .powered_opacity = 0,
        .unpowered_opacity = 1.0,

        // Prevent player from tossing coagulation at closed door to empty
        // everything inside with no risk
        //
        .porous = false,

        .evoke_confirm = "Really open a treasure vault door?",
        .on_power = struct {
            pub fn f(machine: *Machine) void {
                machine.disabled = true;
                state.dungeon.at(machine.coord).surface = null;

                if (rng.percent(alarm_chance)) {
                    state.message(.Important, "The alarm goes off!!", .{});
                    state.markMessageNoisy();
                    state.player.makeNoise(.Alarm, .Loudest);
                }
            }
        }.f,
    };
}

pub const IronVaultDoor = createVaultDoor("iron", "iron", colors.COPPER_RED, 30);
pub const GoldVaultDoor = createVaultDoor("gold", "golden", colors.GOLD, 60);
pub const MarbleVaultDoor = createVaultDoor("marble", "marble", colors.OFF_WHITE, 90);
pub const TavernVaultDoor = createVaultDoor("tavern", "tavern", 0x77440f, 100);

pub const Mine = Machine{
    .name = "mine",
    .powered_fg = 0xff34d7,
    .unpowered_fg = 0xff3434,
    .powered_tile = '^',
    .unpowered_tile = '^',
    .power_drain = 0, // Stay powered on once activated
    .on_power = powerMine,
    .flammability = 100,
    .pathfinding_penalty = 10,
};

pub const Drain = Machine{
    .id = "drain",
    .name = "drain",
    .announce = true,
    .powered_tile = '∩',
    .unpowered_tile = '∩',
    .powered_fg = 0x888888,
    .unpowered_fg = 0x888888,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .on_power = powerNone,
    .player_interact = .{
        .name = "crawl",
        .success_msg = "You crawl into the drain and emerge from another!",
        .no_effect_msg = "You crawl into the drain, but it's a dead end!",
        .expended_msg = null,
        .needs_power = false,
        .max_use = 1,
        .func = interact1Drain,
    },
};

pub const Fountain = Machine{
    .id = "fountain",
    .name = "fountain",
    .announce = true,
    .powered_tile = '¶',
    .unpowered_tile = '¶',
    .powered_fg = 0x00d7ff,
    .unpowered_fg = 0x00d7ff,
    .powered_walkable = true,
    .unpowered_walkable = true,
    .on_power = powerNone,
    .player_interact = .{
        .name = "quaff",
        .success_msg = "The fountain refreshes you.",
        .no_effect_msg = "The fountain is dry!",
        .needs_power = false,
        .max_use = 1,
        .func = interact1Fountain,
    },
};

fn powerNone(_: *Machine) void {}

fn powerStairExit(machine: *Machine) void {
    std.log.info("triggered", .{});
    if (machine.last_interaction) |culprit| {
        if (culprit == state.player)
            state.state = .Win;
    }
}

fn powerLabDoor(machine: *Machine) void {
    var has_mob = if (state.dungeon.at(machine.coord).mob != null) true else false;
    for (&DIRECTIONS) |d| {
        if (has_mob) break;
        if (machine.coord.move(d, state.mapgeometry)) |neighbor| {
            if (state.dungeon.at(neighbor).mob != null) has_mob = true;
        }
    }

    if (has_mob) {
        machine.powered_tile = '\\';
        machine.powered_sprite = .S_O_M_LabDoorOpen;
        machine.powered_walkable = true;
        machine.powered_opacity = 0.0;
    } else {
        machine.powered_tile = '+';
        machine.powered_sprite = .S_O_M_LabDoorShut;
        machine.powered_walkable = false;
        machine.powered_opacity = 1.0;
    }
}

fn powerMine(machine: *Machine) void {
    if (machine.last_interaction) |mob|
        if (mob == state.player) {
            // Deactivate.
            // TODO: either one of two things should be done:
            //       - Make it so that goblins won't trigger it, and make use of the
            //         restricted_to field on this machine.
            //       - Add a restricted_from field to ensure player won't trigger it.
            machine.power = 0;
            return;
        };

    if (rng.tenin(25)) {
        state.dungeon.at(machine.coord).surface = null;
        machine.disabled = true;

        explosions.kaboom(machine.coord, .{
            .strength = 3 * 100,
            .culprit = state.player,
        });
    }
}

fn interact1RechargingStation(_: *Machine, by: *Mob) bool {
    // XXX: All messages are printed in invokeRecharger().
    assert(by == state.player);

    var num_recharged: usize = 0;
    for (state.player.inventory.pack.slice()) |item| switch (item) {
        .Evocable => |e| if (e.rechargable and e.charges < e.max_charges) {
            e.charges = e.max_charges;
            num_recharged += 1;
        },
        else => {},
    };

    return num_recharged > 0;
}

fn interact1Drain(machine: *Machine, mob: *Mob) bool {
    assert(mob == state.player);

    var drains = StackBuffer(*Machine, 32).init(null);
    for (state.dungeon.map[state.player.coord.z]) |*row| {
        for (row) |*tile| {
            if (tile.surface) |s|
                if (meta.activeTag(s) == .Machine and
                    s.Machine != machine and
                    mem.eql(u8, s.Machine.id, "drain"))
                {
                    drains.append(s.Machine) catch err.wat();
                };
        }
    }

    if (drains.len == 0) {
        return false;
    }
    const drain = rng.chooseUnweighted(*Machine, drains.constSlice());

    const succeeded = mob.teleportTo(drain.coord, null, true, false);
    assert(succeeded);

    if (rng.onein(3)) {
        mob.addStatus(.Nausea, 0, .{ .Tmp = 10 });
    }

    return true;
}

fn interact1Fountain(_: *Machine, mob: *Mob) bool {
    assert(mob == state.player);

    const HP = state.player.HP;
    const heal_amount = (state.player.max_HP - HP) / 2;
    state.player.takeHealing(heal_amount);

    // Remove some harmful statuses.
    state.player.cancelStatus(.Fire);
    state.player.cancelStatus(.Nausea);
    state.player.cancelStatus(.Pain);

    return true;
}

// ----------------------------------------------------------------------------

pub fn readProps(alloc: mem.Allocator) void {
    const PropData = struct {
        id: []u8 = undefined,
        name: []u8 = undefined,
        tile: u21 = undefined,
        sprite: ?font.Sprite = undefined,
        fg: ?u32 = undefined,
        bg: ?u32 = undefined,
        walkable: bool = undefined,
        opacity: f64 = undefined,
        flammability: usize = undefined,
        function: Function = undefined,
        holder: bool = undefined,

        pub const Function = enum { Laboratory, Vault, LaboratoryItem, Statue, Weapons, Bottles, Wearables, Tools, None };
    };

    props = PropArrayList.init(alloc);
    prison_item_props = PropArrayList.init(alloc);
    laboratory_item_props = PropArrayList.init(alloc);
    laboratory_props = PropArrayList.init(alloc);
    vault_props = PropArrayList.init(alloc);
    statue_props = PropArrayList.init(alloc);
    weapon_props = PropArrayList.init(alloc);
    bottle_props = PropArrayList.init(alloc);
    tools_props = PropArrayList.init(alloc);
    armors_props = PropArrayList.init(alloc);

    const data_dir = std.fs.cwd().openDir("data", .{}) catch unreachable;
    const data_file = data_dir.openFile("props.tsv", .{
        .read = true,
        .lock = .None,
    }) catch unreachable;

    var rbuf: [65535]u8 = undefined;
    const read = data_file.readAll(rbuf[0..]) catch unreachable;

    const result = tsv.parse(
        PropData,
        &[_]tsv.TSVSchemaItem{
            .{ .field_name = "id", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
            .{ .field_name = "name", .parse_to = []u8, .parse_fn = tsv.parseUtf8String },
            .{ .field_name = "tile", .parse_to = u21, .parse_fn = tsv.parseCharacter },
            .{ .field_name = "sprite", .parse_to = ?font.Sprite, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = null },
            .{ .field_name = "fg", .parse_to = ?u32, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = null },
            .{ .field_name = "bg", .parse_to = ?u32, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = null },
            .{ .field_name = "walkable", .parse_to = bool, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = true },
            .{ .field_name = "opacity", .parse_to = f64, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = 0.0 },
            .{ .field_name = "flammability", .parse_to = usize, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = 0 },
            .{ .field_name = "function", .parse_to = PropData.Function, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = .None },
            .{ .field_name = "holder", .parse_to = bool, .parse_fn = tsv.parsePrimitive, .optional = true, .default_val = false },
        },
        .{},
        rbuf[0..read],
        alloc,
    );

    if (!result.is_ok()) {
        err.bug(
            "Cannot read props: {} (line {}, field {})",
            .{ result.Err.type, result.Err.context.lineno, result.Err.context.field },
        );
    } else {
        const propdatas = result.unwrap();
        defer propdatas.deinit();

        for (propdatas.items) |propdata| {
            const prop = Prop{
                .id = propdata.id,
                .name = propdata.name,
                .tile = propdata.tile,
                .sprite = propdata.sprite,
                .fg = propdata.fg,
                .bg = propdata.bg,
                .walkable = propdata.walkable,
                .flammability = propdata.flammability,
                .opacity = propdata.opacity,
                .holder = propdata.holder,
            };

            switch (propdata.function) {
                .Laboratory => laboratory_props.append(prop) catch err.oom(),
                .LaboratoryItem => laboratory_item_props.append(prop) catch err.oom(),
                .Vault => vault_props.append(prop) catch err.oom(),
                .Statue => statue_props.append(prop) catch err.oom(),
                .Weapons => weapon_props.append(prop) catch err.oom(),
                .Bottles => bottle_props.append(prop) catch err.oom(),
                .Tools => tools_props.append(prop) catch err.oom(),
                .Wearables => armors_props.append(prop) catch err.oom(),
                else => {},
            }

            props.append(prop) catch unreachable;
        }

        std.log.info("Loaded {} props.", .{props.items.len});
    }
}

pub fn freeProps(alloc: mem.Allocator) void {
    for (props.items) |prop| prop.deinit(alloc);

    props.deinit();
    prison_item_props.deinit();
    laboratory_item_props.deinit();
    laboratory_props.deinit();
    vault_props.deinit();
    statue_props.deinit();
    weapon_props.deinit();
    bottle_props.deinit();
    tools_props.deinit();
    armors_props.deinit();
}

pub fn tickMachines(level: usize) void {
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new2(level, x, y);
            if (state.dungeon.at(coord).surface == null or
                meta.activeTag(state.dungeon.at(coord).surface.?) != .Machine)
                continue;

            const machine = state.dungeon.at(coord).surface.?.Machine;
            if (machine.disabled)
                continue;

            if (machine.isPowered()) {
                machine.on_power(machine);
                machine.power = machine.power -| machine.power_drain;
            }
        }
    }
}
