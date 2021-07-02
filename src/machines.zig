// TODO: add state to machines
// STYLE: remove pub marker from power funcs

const std = @import("std");
const assert = std.debug.assert;

const main = @import("root");
const state = @import("state.zig");
const gas = @import("gas.zig");
const rng = @import("rng.zig");
usingnamespace @import("types.zig");

const STEEL_SUPPORT_COLOR: u32 = 0xa6c2d4;
const COPPER_COIL_COLOR: u32 = 0xd96c00;

pub const PROPS = [_]Prop{
    WorkstationProp,
    SteelSupport_NSE2_Prop,
    SteelSupport_NSW2_Prop,
    SteelSupport_NSE2W2_Prop,
    SteelSupport_E2W2_Prop,
    LeftCopperCoilProp,
    RightCopperCoilProp,
    UpperCopperCoilProp,
    LowerCopperCoilProp,
    FullCopperCoilProp,
    GasVentProp,
    BedProp,
    IronBarProp,
};

pub const MACHINES = [_]Machine{
    PowerSupply,
    Brazier,
    StairExit,
    StairUp,
    StairDown,
    NormalDoor,
    LockedDoor,
    ParalysisGasTrap,
    PoisonGasTrap,
    ConfusionGasTrap,
    AlarmTrap,
};

pub const WorkstationProp = Prop{
    .id = "workstation",
    .name = "workstation",
    .tile = '░',
    .fg = 0xffffff,
    .opacity = 0.0,
    .walkable = true,
};

pub const SteelSupport_NSE2_Prop = Prop{
    .id = "steel_support_nse2",
    .name = "steel support",
    .tile = '╞',
    .fg = STEEL_SUPPORT_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const SteelSupport_NSW2_Prop = Prop{
    .id = "steel_support_nsw2",
    .name = "steel support",
    .tile = '╡',
    .fg = STEEL_SUPPORT_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const SteelSupport_NSE2W2_Prop = Prop{
    .id = "steel_support_nse2w2",
    .name = "steel support",
    .tile = '╪',
    .fg = STEEL_SUPPORT_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const SteelSupport_E2W2_Prop = Prop{
    .id = "steel_support_e2w2",
    .name = "steel support",
    .tile = '═',
    .fg = STEEL_SUPPORT_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const LeftCopperCoilProp = Prop{
    .id = "left_copper_coil",
    .name = "half copper coil",
    .tile = '▌',
    .fg = COPPER_COIL_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const RightCopperCoilProp = Prop{
    .id = "right_copper_coil",
    .name = "half copper coil",
    .tile = '▐',
    .fg = COPPER_COIL_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const LowerCopperCoilProp = Prop{
    .id = "lower_copper_coil",
    .name = "half copper coil",
    .tile = '▄',
    .fg = COPPER_COIL_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const UpperCopperCoilProp = Prop{
    .id = "upper_copper_coil",
    .name = "half copper coil",
    .tile = '▀',
    .fg = COPPER_COIL_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const FullCopperCoilProp = Prop{
    .id = "full_copper_coil",
    .name = "large copper coil",
    .tile = '█',
    .fg = COPPER_COIL_COLOR,
    .opacity = 0.0,
    .walkable = false,
};

pub const GasVentProp = Prop{
    .name = "gas vent",
    .tile = '=',
};

pub const BedProp = Prop{
    .id = "bed",
    .name = "bed",
    .tile = 'Θ',
    .fg = 0xdaa520,
    .opacity = 0.6,
    .walkable = true,
};

pub const IronBarProp = Prop{
    .name = "iron bars",
    .tile = '≡',
    .fg = 0x000012,
    .bg = 0xdadada,
    .opacity = 0.3,
    .walkable = false,
};

pub const PowerSupply = Machine{
    .id = "power_supply",
    .name = "machine",

    .powered_tile = '⊻',
    .unpowered_tile = '⊻',

    .power_drain = 100,
    .power_add = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .powered_luminescence = 10,
    .unpowered_luminescence = 10,

    .on_power = powerPowerSupply,
};

pub const Brazier = Machine{
    .name = "a brazier",

    .powered_tile = '☐',
    .unpowered_tile = '☐',

    .power_drain = 30,
    .power_add = 50,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0.5,
    .unpowered_opacity = 0.5,

    // maximum, could be much lower (see mapgen:placeLights)
    .powered_luminescence = 90,
    .unpowered_luminescence = 0,

    .on_power = powerNone,
};

pub const StairExit = Machine{
    .id = "stair_exit",
    .name = "exit staircase",
    .powered_tile = '»',
    .unpowered_tile = '»',
    .on_power = powerStairExit,
};

// TODO: Maybe define a "Doormat" prop that stairs have? And doormats should have
// a very welcoming message on it, of course
pub const StairUp = Machine{
    .name = "ascending staircase",
    .powered_tile = '▲',
    .unpowered_tile = '▲',
    .on_power = powerStairUp,
};

pub const StairDown = Machine{
    .name = "descending staircase",
    .powered_tile = '▼',
    .unpowered_tile = '▼',
    .on_power = powerStairDown,
};

pub const AlarmTrap = Machine{
    .name = "alarm trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .on_power = powerAlarmTrap,
};

pub const PoisonGasTrap = Machine{
    .name = "poison gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .on_power = powerPoisonGasTrap,
};

pub const ParalysisGasTrap = Machine{
    .name = "paralysis gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .on_power = powerParalysisGasTrap,
};

pub const ConfusionGasTrap = Machine{
    .name = "confusion gas trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .on_power = powerConfusionGasTrap,
};

pub const NormalDoor = Machine{
    .name = "door",
    .powered_tile = '□',
    .unpowered_tile = '■',
    .power_drain = 49,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .powered_opacity = 0.0,
    .unpowered_opacity = 1.0,
    .on_power = powerNone,
};

pub const LockedDoor = Machine{
    .name = "locked door",
    .powered_tile = '⌂',
    .unpowered_tile = '⌂',
    .power_drain = 100,
    .treat_as_walkable_by = .Sauron,
    .powered_walkable = false,
    .unpowered_walkable = false,
    .powered_opacity = 0.7,
    .unpowered_opacity = 0.7,
    .on_power = powerLockedDoor,
};

pub fn powerNone(_: *Machine) void {}

pub fn powerPowerSupply(machine: *Machine) void {
    var iter = state.machines.iterator();
    while (iter.nextPtr()) |mach| {
        if (mach.coord.z == state.player.coord.z and mach.auto_power)
            mach.addPower(null);
    }
}

pub fn powerAlarmTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Sauron) return;

        culprit.makeNoise(2048); // muahahaha
        if (culprit.coord.eq(state.player.coord))
            state.message(.Trap, "You hear a loud clanging noise!", .{});
    }
}

pub fn powerPoisonGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Sauron) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Poison.id] = 1.0;
            }
        }

        if (culprit.coord.eq(state.player.coord))
            state.message(.Trap, "Noxious fumes seep through the gas vents!", .{});
    }
}

pub fn powerParalysisGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Sauron) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Paralysis.id] = 1.0;
            }
        }

        if (culprit.coord.eq(state.player.coord))
            state.message(.Trap, "Paralytic gas seeps out of the gas vents!", .{});
    }
}

pub fn powerConfusionGasTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (culprit.allegiance == .Sauron) return;

        for (machine.props) |maybe_prop| {
            if (maybe_prop) |vent| {
                state.dungeon.atGas(vent.coord)[gas.Confusion.id] = 1.0;
            }
        }

        if (culprit.coord.eq(state.player.coord))
            state.message(.Trap, "Confusing gas seeps out of the gas vents!", .{});
    }
}

pub fn powerStairExit(machine: *Machine) void {
    assert(machine.coord.z == 0);
    if (machine.last_interaction) |culprit| {
        if (!culprit.coord.eq(state.player.coord)) return;
        state.state = .Win;
    }
}

pub fn powerStairUp(machine: *Machine) void {
    assert(machine.coord.z >= 1);
    if (machine.last_interaction) |culprit| {
        if (!culprit.coord.eq(state.player.coord)) return;

        const uplevel = Coord.new2(machine.coord.z - 1, machine.coord.x, machine.coord.y);

        var dest: ?Coord = null;
        for (&CARDINAL_DIRECTIONS) |d| {
            var desttmp = uplevel;
            if (desttmp.move(d, state.mapgeometry) and state.is_walkable(desttmp, .{ .right_now = true }))
                dest = desttmp;
        }

        if (dest) |spot| {
            const moved = culprit.teleportTo(spot, null);
            assert(moved);
            state.message(.Move, "You ascend.", .{});
        }
    }
}

pub fn powerStairDown(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        if (!culprit.coord.eq(state.player.coord)) return;

        const downlevel = Coord.new2(machine.coord.z + 1, machine.coord.x, machine.coord.y);
        assert(downlevel.z < state.LEVELS);

        var dest: ?Coord = null;
        for (&CARDINAL_DIRECTIONS) |d| {
            var desttmp = downlevel;
            if (desttmp.move(d, state.mapgeometry) and state.is_walkable(desttmp, .{ .right_now = true }))
                dest = desttmp;
        }

        if (dest) |spot| {
            const moved = culprit.teleportTo(spot, null);
            assert(moved);
            state.message(.Move, "You descend.", .{});
        }
    }
}

pub fn powerLockedDoor(machine: *Machine) void {
    // Shouldn't be auto-powered
    const culprit = machine.last_interaction.?;

    if (culprit.allegiance == .Sauron) {
        const direction = Direction.from_coords(culprit.coord, machine.coord) catch return;

        var newcoord = machine.coord;
        if (!newcoord.move(direction, state.mapgeometry)) return;

        if (!state.is_walkable(newcoord, .{ .right_now = true })) return;

        _ = culprit.teleportTo(newcoord, null);
    } else {
        state.message(.Move, "You feel a malevolent force forbidding you to pass.", .{});
    }
}
