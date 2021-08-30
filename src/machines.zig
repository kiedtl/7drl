// TODO: rename this file to surfaces.zig
// TODO: add state to machines
// STYLE: remove pub marker from power funcs

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

const main = @import("root");
const state = @import("state.zig");
const gas = @import("gas.zig");
const rng = @import("rng.zig");
const materials = @import("materials.zig");
usingnamespace @import("types.zig");

const mkprop_opts = struct {
    bg: ?u32 = null,
    walkable: bool = false,
    opacity: f64 = 0.0,
    function: PropFunction = .None,
};

fn mkprop(id: []const u8, name: []const u8, tile: u21, fg: ?u32, opts: mkprop_opts) Prop {
    return .{
        .id = id,
        .name = name,
        .tile = tile,
        .fg = fg,
        .bg = opts.bg,
        .walkable = opts.walkable,
        .opacity = opts.opacity,
        .function = opts.function,
    };
}

const STEEL_SUPPORT_COLOR: u32 = 0xa6c2d4;
const VANGEN_WALL_COLOR: u32 = materials.Vangenite.color_fg;
const MARBLE_WALL_COLOR: u32 = materials.Marble.color_floor;
const CNCRTE_WALL_COLOR: u32 = materials.Concrete.color_floor;
const COPPER_COIL_COLOR: u32 = 0xe99c39;
const COPPER_WIRE_COLOR: u32 = 0xffe5d3;

pub const STATUES = [_]Prop{
    GoldStatue,
    RealgarStatue,
    IronStatue,
    SodaliteStatue,
    HematiteStatue,
};

pub const LAB_UTILITY_ITEMS = [_]Prop{
    mkprop("", "beaker", '~', 0xffffff, .{}),
    mkprop("", "large beaker", '~', 0xffffff, .{}),
    mkprop("", "mesh", '~', 0xffffff, .{}),
    mkprop("", "strainer", '~', 0xffffff, .{}),
    mkprop("", "scale", '~', 0xffffff, .{}),
    mkprop("", "lens", '~', 0xffffff, .{}),
    mkprop("", "battery", '~', 0xffffff, .{}),
    mkprop("", "test-tube", '~', 0xffffff, .{}),
    mkprop("", "large battery", '~', 0xffffff, .{}),
    mkprop("", "empty vial", '~', 0xffffff, .{}),
    mkprop("", "test-tube holder", '~', 0xffffff, .{}),
    mkprop("", "stirring rod", '~', 0xffffff, .{}),
    mkprop("", "laboratory balance", '~', 0xffffff, .{}),
    mkprop("", "crucible", '~', 0xffffff, .{}),
    mkprop("", "crucible tongs", '~', 0xffffff, .{}),
    mkprop("", "filter paper", '~', 0xffffff, .{}),
    mkprop("", "flask", '~', 0xffffff, .{}),
    mkprop("", "filter flask", '~', 0xffffff, .{}),
    mkprop("", "pipet", '~', 0xffffff, .{}),
    mkprop("", "buret", '~', 0xffffff, .{}),
    mkprop("", "ring stand", '~', 0xffffff, .{}),
    mkprop("", "double buret clamp", '~', 0xffffff, .{}),
    mkprop("", "mortar/pestle", '~', 0xffffff, .{}),
    mkprop("", "evaporating dish", '~', 0xffffff, .{}),
    mkprop("", "flame spreader", '~', 0xffffff, .{}),
    mkprop("", "burner lighter", '~', 0xffffff, .{}),
    mkprop("", "utility clamps", '~', 0xffffff, .{}),
    mkprop("", "separatory funnel", '~', 0xffffff, .{}),
    mkprop("", "reagent bottle", '~', 0xffffff, .{}),
    mkprop("", "graduated cylinder", '~', 0xffffff, .{}),
    mkprop("", "petri dish", '~', 0xffffff, .{}),
    mkprop("", "rubber stopper", '~', 0xffffff, .{}),
    mkprop("", "thermometer", '~', 0xffffff, .{}),
    mkprop("", "Buchner funnel", '~', 0xffffff, .{}),
    mkprop("", "Erlenmeyer flask", '~', 0xffffff, .{}),
};

pub const LABSTUFF = [_]Prop{
    Centrifuge,
    XRayAppar,
    WaterPurifierAppar,
    FracDistillAppar,
    LaserEtcher,
    DistillAppar,
    BunsenBurner,
    TirrillBurner,
    Microscope,
    Calorimeter,
    VacuumChamber,
};

pub const PROPS = [_]Prop{
    GoldStatue,
    RealgarStatue,
    IronStatue,
    SodaliteStatue,
    HematiteStatue,
    MarbleWall_Upper,
    MarbleWall_Lower,
    ConcreteWall_Upper,
    ConcreteWall_Lower,
    ConcreteWall_Full,
    Wall_E1W1_Prop,
    Wall_S1W1_Prop,
    Wall_N1S1W1_Prop,
    Wall_N1S1_Prop,
    Wall_N1S1E1_Prop,
    Wall_N1W1_Prop,
    Wall_N1E1_Prop,
    Wall_S1E1_Prop,
    Wall_E1W1_thinE_Prop,
    Wall_E1W1_thinW_Prop,
    Pipe_E1W1_Prop,
    Pipe_S1W1_Prop,
    Pipe_S1E1_Prop,
    Pipe_N1W1_Prop,
    Pipe_N1S1W1_Prop,
    Pipe_N1S1E1_Prop,
    Pipe_N1S1_Prop,
    Pipe_S1E1W1_Prop,
    Pipe_N1E1W1_Prop,
    Wire_S2E1_Prop,
    Wire_E1W1_Prop,
    Wire_S1W1_Prop,
    Wire_S1E1_Prop,
    Wire_N1W1_Prop,
    Wire_N2S2_Prop,
    Wire_N1S1W1_Prop,
    Wire_N2W1_Prop,
    Wire_N1E2_Prop,
    Wire_S1W2_Prop,
    Wire_N1S1W2_Prop,
    Wire_N1S1E2_Prop,
    Wire_N1S1E2W2_Prop,
    Wire_N1S1_Prop,
    Wire_S1E1W1_Prop,
    Wire_N2E1W1_Prop,
    TableProp,
    Gearbox,
    PowerSwitchProp,
    ControlPanelProp,
    SmallTransformerProp,
    LargeTransformerProp,
    SwitchingStationProp,
    Centrifuge,
    XRayAppar,
    WaterPurifierAppar,
    FracDistillAppar,
    LaserEtcher,
    DistillAppar,
    BunsenBurner,
    TirrillBurner,
    Microscope,
    Calorimeter,
    VacuumChamber,
    ItemLocationProp,
    WorkstationProp,
    MediumSieve,
    SteelGasReservoir,
    SteelGasPin,
    SteelSupport_NE2_Prop,
    SteelSupport_SE2_Prop,
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
    LabGasVentProp,
    BedProp,
    IronBarProp,
    TitaniumBarProp,
};

pub const MACHINES = [_]Machine{
    ResearchCore,
    ElevatorMotor,
    Extractor,
    PowerSupply,
    NuclearPowerSupply,
    HealingGasPump,
    Brazier,
    Altar,
    Lamp,
    StairExit,
    StairUp,
    NormalDoor,
    LockedDoor,
    ParalysisGasTrap,
    PoisonGasTrap,
    ConfusionGasTrap,
    AlarmTrap,
    NetTrap,
    RestrictedMachinesOpenLever,
};

pub const Bin = Container{ .name = "bin", .tile = '╳', .capacity = 14, .type = .Utility, .item_repeat = 20 };
pub const Barrel = Container{ .name = "barrel", .tile = 'ʊ', .capacity = 7, .type = .Eatables, .item_repeat = 0 };
pub const Cabinet = Container{ .name = "cabinet", .tile = 'π', .capacity = 5, .type = .Wearables };
pub const Chest = Container{ .name = "chest", .tile = 'æ', .capacity = 7, .type = .Valuables };
pub const LabCabinet = Container{ .name = "cabinet", .tile = 'π', .capacity = 8, .type = .Utility, .item_repeat = 70 };
pub const VOreCrate = Container{ .name = "crate", .tile = '∐', .capacity = 21, .type = .VOres, .item_repeat = 60 };

// zig fmt: off

pub const GoldStatue     = mkprop("gold_statue",     "gold statue",     '☺', 0xfff720, .{});
pub const RealgarStatue  = mkprop("realgar_statue",  "realgar statue",  '☺', 0xff343f, .{});
pub const IronStatue     = mkprop("iron_statue",     "iron statue",     '☻', 0xcacad2, .{});
pub const SodaliteStatue = mkprop("sodalite_statue", "sodalite statue", '☺', 0xa4cfff, .{});
pub const HematiteStatue = mkprop("hematite_statue", "hematite statue", '☺', 0xff7f70, .{});

pub const Wall_E1W1_Prop       = mkprop("wall_e1w1",       "vangenite wall", '━', VANGEN_WALL_COLOR, .{});
pub const Wall_S1W1_Prop       = mkprop("wall_s1w1",       "vangenite wall", '┓', VANGEN_WALL_COLOR, .{});
pub const Wall_N1S1W1_Prop     = mkprop("wall_n1s1w1",     "vangenite wall", '┫', VANGEN_WALL_COLOR, .{});
pub const Wall_N1S1_Prop       = mkprop("wall_n1s1",       "vangenite wall", '┃', VANGEN_WALL_COLOR, .{});
pub const Wall_N1S1E1_Prop     = mkprop("wall_n1s1e1",     "vangenite wall", '┣', VANGEN_WALL_COLOR, .{});
pub const Wall_N1W1_Prop       = mkprop("wall_n1w1",       "vangenite wall", '┛', VANGEN_WALL_COLOR, .{});
pub const Wall_N1E1_Prop       = mkprop("wall_n1e1",       "vangenite wall", '┗', VANGEN_WALL_COLOR, .{});
pub const Wall_S1E1_Prop       = mkprop("wall_s1e1",       "vangenite wall", '┏', VANGEN_WALL_COLOR, .{});
pub const Wall_E1W1_thinE_Prop = mkprop("wall_e1w1_thine", "vangenite wall", '╾', VANGEN_WALL_COLOR, .{});
pub const Wall_E1W1_thinW_Prop = mkprop("wall_e1w1_thinw", "vangenite wall", '╼', VANGEN_WALL_COLOR, .{});

pub const Pipe_E1W1_Prop     = mkprop("pipe_e1w1",     "steel pipe",  '─', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_S1W1_Prop     = mkprop("pipe_s1w1",     "steel pipe",  '┐', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_S1E1_Prop     = mkprop("pipe_s1e1",     "steel pipe",  '┌', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_N1W1_Prop     = mkprop("pipe_n1w1",     "steel pipe",  '┘', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_N1S1W1_Prop   = mkprop("pipe_n1s1w1",   "steel pipe",  '┤', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_N1S1E1_Prop   = mkprop("pipe_n1s1e1",   "steel pipe",  '├', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_N1S1_Prop     = mkprop("pipe_n1s1",     "steel pipe",  '│', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_S1E1W1_Prop   = mkprop("pipe_s1e1w1",   "steel pipe",  '┬', STEEL_SUPPORT_COLOR, .{.walkable=true});
pub const Pipe_N1E1W1_Prop   = mkprop("pipe_n1e1w1",   "steel pipe",  '┴', STEEL_SUPPORT_COLOR, .{.walkable=true});

pub const Wire_S2E1_Prop     = mkprop("wire_s2e1",     "copper wire", '╓', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_E1W1_Prop     = mkprop("wire_e1w1",     "copper wire", '─', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_S1W1_Prop     = mkprop("wire_s1w1",     "copper wire", '┐', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_S1E1_Prop     = mkprop("wire_s1e1",     "copper wire", '┌', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1W1_Prop     = mkprop("wire_n1w1",     "copper wire", '┘', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N2S2_Prop     = mkprop("wire_n2s2",     "copper wire", '║', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1S1W1_Prop   = mkprop("wire_n1s1w1",   "copper wire", '┤', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N2W1_Prop     = mkprop("wire_n2w1",     "copper wire", '╜', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1E2_Prop     = mkprop("wire_n1e2",     "copper wire", '╘', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_S1W2_Prop     = mkprop("wire_s1w2",     "copper wire", '╕', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1S1W2_Prop   = mkprop("wire_n1s1w2",   "copper wire", '╡', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1S1E2_Prop   = mkprop("wire_n1s1e2",   "copper wire", '╞', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1S1E2W2_Prop = mkprop("wire_n1s1e2w2", "copper wire", '╪', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N1S1_Prop     = mkprop("wire_n1s1",     "copper wire", '│', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_S1E1W1_Prop   = mkprop("wire_s1e1w1",   "copper wire", '┬', COPPER_WIRE_COLOR,   .{.walkable=true});
pub const Wire_N2E1W1_Prop   = mkprop("wire_n2e1w1",   "copper wire", '╨', COPPER_WIRE_COLOR,   .{.walkable=true});

pub const SteelSupport_NE2_Prop    = mkprop("steel_support_ne2",    "steel support", '╘', STEEL_SUPPORT_COLOR, .{});
pub const SteelSupport_SE2_Prop    = mkprop("steel_support_se2",    "steel support", '╒', STEEL_SUPPORT_COLOR, .{});
pub const SteelSupport_NSE2_Prop   = mkprop("steel_support_nse2",   "steel support", '╞', STEEL_SUPPORT_COLOR, .{});
pub const SteelSupport_NSW2_Prop   = mkprop("steel_support_nsw2",   "steel support", '╡', STEEL_SUPPORT_COLOR, .{});
pub const SteelSupport_NSE2W2_Prop = mkprop("steel_support_nse2w2", "steel support", '╪', STEEL_SUPPORT_COLOR, .{});
pub const SteelSupport_E2W2_Prop   = mkprop("steel_support_e2w2",   "steel support", '═', STEEL_SUPPORT_COLOR, .{});

pub const MarbleWall_Upper     = mkprop("marble_wall_upper",   "marble wall", '▀', MARBLE_WALL_COLOR , .{});
pub const MarbleWall_Lower     = mkprop("marble_wall_lower",   "marble wall", '▄', MARBLE_WALL_COLOR , .{});

pub const ConcreteWall_Upper   = mkprop("concrete_wall_upper", "concrete wall", '▀', CNCRTE_WALL_COLOR , .{});
pub const ConcreteWall_Lower   = mkprop("concrete_wall_lower", "concrete wall", '▄', CNCRTE_WALL_COLOR , .{});
pub const ConcreteWall_Full    = mkprop("concrete_wall_full",  "concrete wall", '█', CNCRTE_WALL_COLOR , .{});

pub const LeftCopperCoilProp   = mkprop("left_copper_coil",    "half copper coil",  '▌', COPPER_COIL_COLOR, .{.walkable = false});
pub const RightCopperCoilProp  = mkprop("right_copper_coil",   "half copper coil",  '▐', COPPER_COIL_COLOR, .{.walkable = false});
pub const LowerCopperCoilProp  = mkprop("lower_copper_coil",   "half copper coil",  '▄', COPPER_COIL_COLOR, .{.walkable = false});
pub const UpperCopperCoilProp  = mkprop("upper_copper_coil",   "half copper coil",  '▀', COPPER_COIL_COLOR, .{.walkable = false});
pub const FullCopperCoilProp   = mkprop("full_copper_coil",    "large copper coil", '█', COPPER_COIL_COLOR, .{.walkable = false});

pub const TableProp            = mkprop("table",               "table",               '⊺', 0xffffff,            .{});
pub const Gearbox              = mkprop("gearbox",             "gearbox",             '■', 0xffffff,            .{});
pub const PowerSwitchProp      = mkprop("power_switch",        "power switch",        '♥', 0xffffff,            .{});
pub const ControlPanelProp     = mkprop("control_panel",       "control panel",       '⌨', 0xffffff,            .{});
pub const SmallTransformerProp = mkprop("small_transformer",   "machine",             '■', COPPER_WIRE_COLOR,   .{});
pub const LargeTransformerProp = mkprop("large_transformer",   "machine",             '█', COPPER_WIRE_COLOR,   .{});
pub const SwitchingStationProp = mkprop("switching_station",   "machine",             '⊡', 0xffaf9a,            .{});
pub const SteelGasReservoir    = mkprop("steel_gas_reservoir", "steel gas reservoir", '■', 0xd7d7ff,            .{});
pub const SteelGasPin          = mkprop("steel_pin",           "steel pin",           '·', STEEL_SUPPORT_COLOR, .{});

pub const Centrifuge           = mkprop("centrifuge",          "centrifuge",          '⊜', 0xffe4e1,            .{});
pub const XRayAppar            = mkprop("xray_appar",          "x-ray machine",       '‡', 0xa8ffa8,            .{});
pub const WaterPurifierAppar   = mkprop("water_purifi_appar",  "water purifier",      '⊝', 0xe0ffff,            .{});
pub const FracDistillAppar     = mkprop("frac_distill_appar",  "fractional distiller",'∓', 0xe6e6fa,            .{});
pub const LaserEtcher          = mkprop("laser_etcher",        "laser etcher",        '⊎', 0xfff0f5,            .{});
pub const DistillAppar         = mkprop("simp_distill_appar",  "distiller",           '∔', 0xd0e4fe,            .{});
pub const BunsenBurner         = mkprop("b_burner",            "bunsen burner",       '⊼', 0xffffe0,            .{});
pub const TirrillBurner        = mkprop("t_burner",            "tirrill burner",      '⊼', 0xffffe0,            .{});
pub const Microscope           = mkprop("microscope",          "microscope",          '†', 0xffeaca,            .{});
pub const Calorimeter          = mkprop("calorimeter",         "calorimeter",         '⊝', 0xf5f5dc,            .{});
pub const VacuumChamber        = mkprop("vacuum_chmbr",        "vacuum chamber",      '⊜', 0xffefdf,            .{});

pub const StairDstProp         = mkprop("stair_dst",           "downward stair",      '×', 0xffffff,          .{.walkable = true});
pub const ItemLocationProp     = mkprop("item_location",       "mat",                 '░', 0x989898,          .{ .walkable = true, .function = .ActionPoint });
pub const WorkstationProp      = mkprop("workstation",         "workstation",         '░', 0xffffff,          .{.walkable = true});
pub const MediumSieve          = mkprop("medium_sieve",        "medium_sieve",        '▒', 0xffe7e7,          .{ .walkable = false, .function = .ActionPoint });
pub const GasVentProp          = mkprop("gas_vent",            "gas vent",            '=', 0xffffff,          .{ .bg = 0x888888, .walkable = false, .opacity = 1.0 });
pub const LabGasVentProp       = mkprop("gas_vent",            "gas vent",            '=', 0xffffff,          .{ .walkable = false, .opacity = 0.0 });
pub const BedProp              = mkprop("bed",                 "bed",                 'Θ', 0xdaa520,          .{ .opacity = 0.6, .walkable = true });
pub const IronBarProp          = mkprop("iron_bars",           "iron bars",           '≡', 0x000012,          .{ .bg = 0xdadada, .opacity = 0.0, .walkable = false });
pub const TitaniumBarProp      = mkprop("titanium_bars",       "titanium bars",       '*', 0xeaecef,          .{ .opacity = 0.0, .walkable = false });

// zig fmt: on

pub const ResearchCore = Machine{
    .id = "research_core",
    .name = "research core",

    .powered_tile = '█',
    .unpowered_tile = '▓',

    .power_drain = 50,
    .power_add = 100,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerResearchCore,
};

pub const ElevatorMotor = Machine{
    .id = "elevator_motor",
    .name = "motor",

    .powered_tile = '⊛',
    .unpowered_tile = '⊚',

    .power_drain = 50,
    .power_add = 100,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerElevatorMotor,
};

pub const Extractor = Machine{
    .id = "extractor",
    .name = "machine",

    .powered_tile = '⊟',
    .unpowered_tile = '⊞',

    .power_drain = 50,
    .power_add = 100,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .on_power = powerExtractor,
};

pub const PowerSupply = Machine{
    .id = "power_supply",
    .name = "machine",

    .powered_tile = '█',
    .unpowered_tile = '▓',

    .power_drain = 30,
    .power_add = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .powered_luminescence = 75,
    .unpowered_luminescence = 5,

    .on_power = powerPowerSupply,
};

pub const NuclearPowerSupply = Machine{
    .id = "nuclear_power_supply",
    .name = "orthire furnace",

    .powered_tile = '≡',
    .unpowered_tile = '≡',

    .power_drain = 0,
    .power_add = 100,
    .power = 100, // Start out fully powered

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .powered_luminescence = 100,
    .unpowered_luminescence = 20,

    .on_power = powerPowerSupply,
};

pub const HealingGasPump = Machine{
    .id = "healing_gas_pump",
    .name = "machine",

    .powered_tile = '█',
    .unpowered_tile = '▓',

    .power_drain = 100,
    .power_add = 100,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0,
    .unpowered_opacity = 0,

    .on_power = powerHealingGasPump,
};

pub const Brazier = Machine{
    .name = "a brazier",

    .powered_tile = '╋',
    .unpowered_tile = '┽',

    .powered_fg = 0xeee088,
    .unpowered_fg = 0xffffff,

    .powered_bg = 0xb7b7b7,
    .unpowered_bg = 0xaaaaaa,

    .power_drain = 10,
    .power_add = 100,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 1.0,
    .unpowered_opacity = 1.0,

    // maximum, could be much lower (see mapgen:placeLights)
    .powered_luminescence = 90,
    .unpowered_luminescence = 0,

    .on_power = powerNone,
};

pub const Altar = Machine{
    .id = "altar",
    .name = "an altar",

    .powered_tile = '☼',
    .unpowered_tile = '☼',

    .powered_fg = 0xf0e68c,
    .unpowered_fg = 0xeeeeee,

    .power_drain = 1,
    .power_add = 20,
    .power = 100, // start out with full power

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 0.0,
    .unpowered_opacity = 0.0,

    .powered_luminescence = 100,
    .unpowered_luminescence = 0,
    .dims = true,

    .on_power = powerNone,
};

pub const Lamp = Machine{
    .name = "a lamp",

    .powered_tile = '•',
    .unpowered_tile = '○',

    .powered_fg = 0xffdf12,
    .unpowered_fg = 0x88e0ee,

    .power_drain = 10,
    .power_add = 100,
    .auto_power = true,

    .powered_walkable = false,
    .unpowered_walkable = false,

    .powered_opacity = 1.0,
    .unpowered_opacity = 1.0,

    // maximum, could be lower (see mapgen:placeLights)
    .powered_luminescence = 100,
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

pub const AlarmTrap = Machine{
    .name = "alarm trap",
    .powered_tile = '^',
    .unpowered_tile = '^',
    .on_power = powerAlarmTrap,
};

pub const NetTrap = Machine{
    .name = "net",
    .powered_fg = 0xffff00,
    .unpowered_fg = 0xffff00,
    .powered_tile = ':',
    .unpowered_tile = ':',
    .on_power = powerNetTrap,
    .pathfinding_penalty = 80,
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
    .powered_tile = '□',
    .unpowered_tile = '■',
    .unpowered_fg = 0xcfcfff,
    .power_drain = 90,
    .restricted_to = .Sauron,
    .powered_walkable = true,
    .unpowered_walkable = false,
    .on_power = powerNone,
};

pub const RestrictedMachinesOpenLever = Machine{
    .id = "restricted_machines_open_lever",
    .name = "lever",
    .powered_tile = '/',
    .unpowered_tile = '\\',
    .unpowered_fg = 0xdaa520,
    .powered_fg = 0xdaa520,
    .power_drain = 90,
    .powered_walkable = false,
    .unpowered_walkable = false,
    .on_power = powerRestrictedMachinesOpenLever,
};

pub fn powerNone(_: *Machine) void {}

pub fn powerResearchCore(machine: *Machine) void {
    // Only function on every 32nd turn, to give the impression that it takes
    // a while to process vials
    if ((state.ticks % 32) != 0 or rng.onein(3)) return;

    for (&DIRECTIONS) |direction| if (machine.coord.move(direction, state.mapgeometry)) |neighbor| {
        for (state.dungeon.itemsAt(neighbor).constSlice()) |item, i| switch (item) {
            .Vial => {
                _ = state.dungeon.itemsAt(neighbor).orderedRemove(i) catch unreachable;
                return;
            },
            else => {},
        };
    };
}

pub fn powerElevatorMotor(machine: *Machine) void {
    // Only function on every 32th turn or so, to give the impression that it takes
    // a while to bring up more ores
    if ((state.ticks % 32) != 0 or rng.onein(3)) return;

    for (&CARDINAL_DIRECTIONS) |direction| if (machine.coord.move(direction, state.mapgeometry)) |neighbor| {
        if (state.dungeon.at(neighbor).surface) |surface| {
            if (std.meta.activeTag(surface) == .Prop and surface.Prop.function == .ActionPoint) {
                if (!state.dungeon.itemsAt(neighbor).isFull()) {
                    const v = rng.choose(Vial.OreAndVial, &Vial.VIAL_ORES, &Vial.VIAL_COMMONICITY) catch unreachable;
                    if (v.m) |material| {
                        state.dungeon.itemsAt(neighbor).append(Item{ .Boulder = material }) catch unreachable;
                    }
                }
            }
        }
    };
}

pub fn powerExtractor(machine: *Machine) void {
    // Only function on every 32th turn, to give the impression that it takes
    // a while to extract more vials
    if ((state.ticks % 32) != 0) return;

    var input: Coord = undefined;
    var output: Coord = undefined;
    var found_coords = false;

    for (&CARDINAL_DIRECTIONS) |direction| if (machine.coord.move(direction, state.mapgeometry)) |neighbor| {
        if (state.dungeon.at(neighbor).surface) |surface| {
            if (std.meta.activeTag(surface) == .Prop and surface.Prop.function == .ActionPoint) {
                if (machine.coord.move(direction.opposite(), state.mapgeometry)) |opposite_neighbor| {
                    input = opposite_neighbor;
                    output = neighbor;
                    found_coords = true;
                    break;
                }
            }
        }
    };

    if (!found_coords) unreachable;

    if (state.dungeon.itemsAt(output).isFull())
        return;

    // TODO: don't eat items that can't be processed

    var input_item: ?Item = null;
    if (state.dungeon.hasContainer(input)) |container| {
        if (container.items.len > 0) input_item = container.items.pop() catch unreachable;
    } else {
        const t_items = state.dungeon.itemsAt(input);
        if (t_items.len > 0) input_item = t_items.pop() catch unreachable;
    }

    if (input_item != null) switch (input_item.?) {
        .Boulder => |b| for (&Vial.VIAL_ORES) |vd| if (vd.m) |m|
            if (mem.eql(u8, m.name, b.name)) {
                state.dungeon.itemsAt(output).append(Item{ .Vial = vd.v }) catch unreachable;
                state.dungeon.atGas(machine.coord)[gas.Dust.id] = rng.range(f64, 0.1, 0.2);
            },
        else => {},
    };
}

pub fn powerPowerSupply(machine: *Machine) void {
    var iter = state.machines.iterator();
    while (iter.nextPtr()) |mach| {
        if (mach.coord.z == machine.coord.z and mach.auto_power)
            mach.addPower(null);
    }
}

pub fn powerHealingGasPump(machine: *Machine) void {
    for (&CARDINAL_DIRECTIONS) |direction| {
        if (machine.coord.move(direction, state.mapgeometry)) |neighbor| {
            if (state.dungeon.at(neighbor).surface) |surface| {
                if (std.meta.activeTag(surface) == .Prop and surface.Prop.function == .ActionPoint)
                    state.dungeon.atGas(neighbor)[gas.Healing.id] = 1.0;
            }
        }
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

pub fn powerNetTrap(machine: *Machine) void {
    if (machine.last_interaction) |culprit| {
        culprit.addStatus(.Held, 0, null, false);
    }
    state.dungeon.at(machine.coord).surface = null;
    machine.disabled = true;
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
    const culprit = machine.last_interaction.?;
    if (!culprit.coord.eq(state.player.coord)) return;

    const dst = Coord.new2(machine.coord.z - 1, machine.coord.x, machine.coord.y);
    if (culprit.teleportTo(dst, null))
        state.message(.Move, "You ascend.", .{});
}

pub fn powerRestrictedMachinesOpenLever(machine: *Machine) void {
    const room_i = switch (state.layout[machine.coord.z][machine.coord.y][machine.coord.x]) {
        .Unknown => return,
        .Room => |r| r,
    };
    const room = &state.dungeon.rooms[machine.coord.z].items[room_i];

    var y: usize = room.start.y;
    while (y < room.end().y) : (y += 1) {
        var x: usize = room.start.x;
        while (x < room.end().x) : (x += 1) {
            const coord = Coord.new2(machine.coord.z, x, y);

            if (state.dungeon.at(coord).surface) |surface| {
                switch (surface) {
                    .Machine => |m| if (m.restricted_to != null)
                        m.addPower(null),
                    else => {},
                }
            }
        }
    }
}
