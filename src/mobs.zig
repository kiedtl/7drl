const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const ai = @import("ai.zig");
const state = @import("state.zig");
const items = @import("items.zig");
const buffer = @import("buffer.zig");
const dijkstra = @import("dijkstra.zig");
const rng = @import("rng.zig");
const spells = @import("spells.zig");
const err = @import("err.zig");
const types = @import("types.zig");
const utils = @import("utils.zig");

const MinMax = types.MinMax;
const minmax = types.minmax;
const Coord = types.Coord;
const Rect = types.Rect;
const Item = types.Item;
const Ring = types.Ring;
const DamageStr = types.DamageStr;
const Weapon = types.Weapon;
const Resistance = types.Resistance;
const StatusDataInfo = types.StatusDataInfo;
const Armor = types.Armor;
const SurfaceItem = types.SurfaceItem;
const Squad = types.Squad;
const Mob = types.Mob;
const AI = types.AI;
const AIPhase = types.AIPhase;
const Species = types.Species;
const Status = types.Status;
const Direction = types.Direction;
const DIRECTIONS = types.DIRECTIONS;

const LEVELS = state.LEVELS;
const HEIGHT = state.HEIGHT;
const WIDTH = state.WIDTH;

const Evocable = items.Evocable;
const Cloak = items.Cloak;
const Projectile = items.Projectile;
const StackBuffer = buffer.StackBuffer;
const SpellOptions = spells.SpellOptions;
const Generator = @import("generators.zig").Generator;
const GeneratorCtx = @import("generators.zig").GeneratorCtx;

// -----------------------------------------------------------------------------

const NONE_WEAPON = Weapon{
    .id = "",
    .name = "",
    .damage = 0,
    .strs = &[_]DamageStr{
        items._dmgstr(80, "hurl", "hurls", " at kiedtl"),
    },
};

pub const PLAYER_VISION = 12;
pub const V = PLAYER_VISION; // too lazy to type
pub const RESIST_IMMUNE = 1000;
pub const WILL_IMMUNE = 1000;

pub const GoblinSpecies = Species{ .name = "goblin" };
pub const ImpSpecies = Species{ .name = "imp" };

pub const MobTemplate = struct {
    ignore_conflicting_tiles: bool = false,

    mob: Mob,
    weapon: ?*const Weapon = null,
    backup_weapon: ?*const Weapon = null,
    armor: ?*const Armor = null,
    cloak: ?*const Cloak = null,
    statuses: []const StatusDataInfo = &[_]StatusDataInfo{},
    projectile: ?*const Projectile = null,
    evocables: []const Evocable = &[_]Evocable{},
    squad: []const []const SquadMember = &[_][]const SquadMember{},

    pub const SquadMember = struct {
        // FIXME: when Zig's #131 issue is resolved, change this to a
        // *MobTemplate instead of the mob's ID
        mob: []const u8,
        weight: usize = 1, // percentage
        count: MinMax(usize),
    };

    pub fn mobAreaRect(self: MobTemplate, coord: Coord) Rect {
        const l = self.mob.multitile orelse 1;
        return Rect{ .start = coord, .width = l, .height = l };
    }
};

pub const PlayerTemplate = MobTemplate{
    .mob = .{
        .id = "player",
        .species = &Species{
            .name = "player",
            .default_attack = &Weapon{
                .id = "none",
                .name = "none",
                .damage = 1,
                .strs = &items.FIST_STRS,
            },
        },
        .tile = '@',
        .prisoner_status = .{ .of = .CaveGoblins },
        .ai = AI{
            .profession_name = "[this is a bug]",
            .profession_description = "[this is a bug]",
            .work_fn = ai.dummyWork,
            .fight_fn = ai.meleeFight,
            .is_combative = false,
            .is_curious = false,
        },
        .faction = .Player,
        .base_night_vision = true,
        .deg360_vision = true,
        .no_show_fov = true,

        .max_HP = 30,
        .memory_duration = 10,

        .stats = .{ .Willpower = 4, .Missile = 60, .Vision = PLAYER_VISION },
    },
};

pub const GoblinChildTemplate = MobTemplate{
    .mob = .{
        .id = "goblin_child",
        .species = &GoblinSpecies,
        .tile = 'i',
        .alt_name = "meatloaf",
        .ai = AI{
            .profession_name = "goblin child",
            .profession_description = "wandering",
            .work_fn = ai.wanderWork,
            .fight_fn = ai.watcherFight,
            .flags = &[_]AI.Flag{.AvoidsEnemies},
        },
        .faction = .CaveGoblins,
        .max_HP = 3,
        .memory_duration = 15,
        .stats = .{ .Speed = 90, .Vision = V - 4 },
    },
    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "goblin_child", .weight = 1, .count = minmax(usize, 0, 2) },
        },
    },
};

pub const GoblinTemplate = MobTemplate{
    .mob = .{
        .id = "goblin",
        .species = &GoblinSpecies,
        .tile = 'g',
        .alt_name = "meatbag",
        .ai = AI{
            .profession_name = "goblin",
            .profession_description = "wandering",
            .work_fn = ai.patrolWork,
            .fight_fn = ai.meleeFight,
            .flags = &[_]AI.Flag{.AvoidsEnemies},
        },
        .faction = .CaveGoblins,
        .max_HP = 4,
        .memory_duration = 20,
        .stats = .{ .Willpower = 4, .Vision = V - 4, .Melee = 100 },
    },
    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "goblin", .weight = 1, .count = minmax(usize, 0, 1) },
        },
    },
};

pub const GoblinStayStillTemplate = MobTemplate{
    .mob = .{
        .id = "goblin_still",
        .species = &GoblinSpecies,
        .tile = 'g',
        .alt_name = "meatbag",
        .ai = AI{
            .profession_name = "goblin",
            .profession_description = "wandering",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            .flags = &[_]AI.Flag{.AvoidsEnemies},
        },
        .faction = .CaveGoblins,
        .max_HP = 4,
        .memory_duration = 20,
        .stats = .{ .Willpower = 4, .Vision = V - 4, .Melee = 100 },
    },
    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "goblin", .weight = 1, .count = minmax(usize, 0, 1) },
        },
    },
};

pub fn createFlavoredGoblinTemplate(comptime id: []const u8, comptime name: []const u8, comptime sqmax: usize) MobTemplate {
    return MobTemplate{
        .mob = .{
            .id = "goblin_" ++ id,
            .species = &GoblinSpecies,
            .tile = 'g',
            .alt_name = "meatbag " ++ name,
            .ai = AI{
                .profession_name = "goblin " ++ name,
                .profession_description = "wandering",
                .work_fn = ai.wanderWork,
                .fight_fn = ai.meleeFight,
            },
            .faction = .CaveGoblins,
            .max_HP = 4,
            .memory_duration = 20,
            .stats = .{ .Willpower = 4, .Vision = V - 4, .Melee = 100 },
        },
        .squad = &[_][]const MobTemplate.SquadMember{
            &[_]MobTemplate.SquadMember{
                .{ .mob = "goblin", .weight = 1, .count = minmax(usize, 0, sqmax) },
            },
        },
    };
}

pub const GoblinCookTemplate = createFlavoredGoblinTemplate("cook", "cook", 0);
pub const GoblinCarpenterTemplate = createFlavoredGoblinTemplate("carpenter", "carpenter", 0);
pub const GoblinSmithTemplate = createFlavoredGoblinTemplate("smith", "smith", 0);

pub const GuardTemplate = MobTemplate{
    .mob = .{
        .id = "guard",
        .species = &GoblinSpecies,
        .tile = 's',
        .alt_name = "filthy meatbag",
        .ai = AI{
            .profession_name = "sentry",
            .profession_description = "guarding",
            .work_fn = ai.guardWork,
            .fight_fn = ai.meleeFight,
        },

        .max_HP = 5,
        .memory_duration = 15,

        .innate_resists = .{ .Armor = 15 },
        .stats = .{ .Willpower = 1, .Melee = 100 },
    },
    .weapon = &items.BludgeonWeapon,
};

pub const ArbalistTemplate = MobTemplate{
    .mob = .{
        .id = "arbalist",
        .species = &GoblinSpecies,
        .tile = 'a',
        .alt_name = "meat wimp",
        .ai = AI{
            .profession_name = "arbalist",
            .profession_description = "guarding",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.mageFight,
            .spellcaster_backup_action = .Melee,
        },
        .spells = &[_]SpellOptions{
            .{ .MP_cost = 2, .spell = &spells.BOLT_BOLT, .power = 1 },
        },
        .max_MP = 2,
        .max_HP = 5,
        .memory_duration = 7,
        .stats = .{ .Missile = 60, .Vision = V - 2 },
    },
};

pub const MasterArbalistTemplate = MobTemplate{
    .mob = .{
        .id = "arbalist_sadist",
        .species = &GoblinSpecies,
        .tile = 'A',
        .alt_name = "meat pussy",
        .ai = AI{
            .profession_name = "master arbalist",
            .profession_description = "guarding",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.mageFight,
            .spellcaster_backup_action = .KeepDistance,
        },
        .spells = &[_]SpellOptions{
            .{ .MP_cost = 1, .spell = &spells.BOLT_BOLT, .power = 1 },
        },
        .max_MP = 2,
        .max_HP = 6,
        .memory_duration = 14,
        .stats = .{ .Missile = 80, .Vision = V + 1 },
    },
};

pub const WarriorTemplate = MobTemplate{
    .mob = .{
        .id = "warrior",
        .species = &GoblinSpecies,
        .tile = 'w',
        .alt_name = "meat beast",
        .ai = AI{
            .profession_name = "warrior",
            .profession_description = "resting",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            .flee_effect = .{ .status = .Enraged, .duration = .{ .Tmp = 20 }, .exhausting = true },
        },

        .max_HP = 7,
        .memory_duration = 10,
        .innate_resists = .{ .Armor = 25 },
        .stats = .{ .Willpower = 2, .Melee = 100, .Vision = V - 1 },
    },
    .weapon = &items.MaceWeapon,
};

pub const EmberMageTemplate = MobTemplate{
    .mob = .{
        .id = "ember_mage",
        .species = &GoblinSpecies,
        .tile = 'Ë',
        .alt_name = "meat sage",
        .ai = AI{
            .profession_name = "ember mage",
            .profession_description = "watching",
            // Stand still and don't be curious; don't want emberling followers
            // to burn the world down
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.mageFight,
            .spellcaster_backup_action = .Melee,
            .flags = &[_]AI.Flag{.DetectWithHeat},
        },

        .spells = &[_]SpellOptions{
            .{ .MP_cost = 10, .spell = &spells.CAST_FLAMMABLE, .power = 20 },
        },
        .max_MP = 15,

        .max_HP = 6,
        .memory_duration = 7,
        .stats = .{ .Willpower = 4, .Vision = V - 1 },
    },
    .weapon = &items.BludgeonWeapon,
    .cloak = &items.SilCloak,

    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "emberling", .weight = 1, .count = minmax(usize, 1, 2) },
        },
    },
};

pub const EmberlingTemplate = MobTemplate{
    .mob = .{
        .id = "emberling",
        .species = &Species{
            .name = "emberling",
            .default_attack = &Weapon{
                .damage = 1,
                .damage_kind = .Fire,
                .strs = &[_]DamageStr{
                    items._dmgstr(30, "burn", "burns", ""),
                    items._dmgstr(60, "sear", "sears", ""),
                    items._dmgstr(61, "torch", "torches", ""),
                    items._dmgstr(90, "blast", "blasts", ""),
                    items._dmgstr(100, "incinerate", "incinerates", ""),
                    items._dmgstr(120, "cremate", "cremates", " into steaming ashes"),
                },
            },
        },
        .tile = 'e',
        .alt_name = "meat slave",
        .ai = AI{
            .profession_description = "watching",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            .is_fearless = true,
        },
        .life_type = .Construct,

        .blood = null,
        .corpse = .None,

        .max_HP = 2,
        .memory_duration = 5,
        .innate_resists = .{ .rFume = 100, .rFire = RESIST_IMMUNE, .rElec = -100 },
        .stats = .{ .Willpower = 1, .Speed = 110, .Vision = V - 4, .Melee = 100 },
    },
    .statuses = &[_]StatusDataInfo{
        .{ .status = .Sleeping, .duration = .Prm },
        .{ .status = .Noisy, .duration = .Prm },
    },
};

const REVGEN_CLAW_WEAPON = Weapon{
    .damage = 1,
    .strs = &items.CLAW_STRS,
};

pub const RevgenunkimTemplate = MobTemplate{
    .mob = .{
        .id = "revgenunkim",
        .species = &Species{
            .name = "Revgenunkim",
            .default_attack = &REVGEN_CLAW_WEAPON,
            .aux_attacks = &[_]*const Weapon{&REVGEN_CLAW_WEAPON},
        },
        .tile = 'R',
        .alt_name = "earthen angel",
        .ai = AI{
            .profession_description = "sulking",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            //.is_fearless = true, // Flee effect won't trigger otherwise.
            .flee_effect = .{ .status = .Enraged, .duration = .{ .Tmp = 10 }, .exhausting = true },
        },

        .faction = .Revgenunkim,
        .max_HP = 10,
        .memory_duration = 99,
        .blood = null,
        .corpse = .None,

        .innate_resists = .{ .rFire = RESIST_IMMUNE },
        .stats = .{ .Willpower = 8, .Speed = 70 },
    },
};
pub const CinderBruteTemplate = MobTemplate{
    .mob = .{
        .id = "cinder_beast",
        .species = &Species{
            .name = "cinder beast",
            .default_attack = &Weapon{
                .damage = 1,
                .strs = &items.BITING_STRS,
            },
        },
        .tile = 'C',
        .alt_name = "burning saviour",
        .ai = AI{
            .profession_description = "wandering",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.mageFight,
            .flags = &[_]AI.Flag{.DetectWithHeat},
        },
        .max_HP = 8,

        .spells = &[_]SpellOptions{
            // Have cooldown period that matches time needed for flames to
            // die out, so that the brute isn't constantly vomiting fire when
            // its surroundings are already in flames
            //
            // TODO: check this in spells.zig
            .{ .MP_cost = 10, .spell = &spells.CAST_FIREBLAST, .power = 4 },
        },
        .max_MP = 10,

        .memory_duration = 999,
        .blood = .Ash,
        .corpse = .None,
        .faction = .Revgenunkim,
        .innate_resists = .{ .rFire = RESIST_IMMUNE, .rElec = -25, .rFume = 100 },

        .stats = .{ .Willpower = 6, .Vision = V + 2 },
    },
    .statuses = &[_]StatusDataInfo{.{ .status = .Fire, .duration = .Prm }},
};

pub const QuicklimeBruteTemplate = MobTemplate{
    .mob = .{
        .id = "quicklime_brute",
        .species = &Species{
            .name = "quicklime brute",
            .default_attack = &Weapon{
                .damage = 1,
                .strs = &items.BITING_STRS,
            },
        },
        .tile = 'Q',
        .alt_name = "acid angel",
        .ai = AI{
            .profession_description = "wandering",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.mageFight,
        },
        .max_HP = 10,

        .spells = &[_]SpellOptions{
            .{ .MP_cost = 0, .spell = &spells.BOLT_ACID, .power = 3 },
        },

        .memory_duration = 999,
        .corpse = .None,
        .faction = .Revgenunkim,
        .innate_resists = .{ .rFire = RESIST_IMMUNE, .rElec = -25, .rFume = 100 },

        .stats = .{ .Willpower = 8, .Vision = V + 2 },
    },
};

pub const BasaltFiendTemplate = MobTemplate{
    .mob = .{
        .id = "basalt_fiend",
        .species = &Species{ .name = "basalt fiend" },
        .tile = 'F',
        .alt_name = "golden seraph",
        .ai = AI{
            .profession_description = "patrolling",
            .work_fn = ai.patrolWork,
            .fight_fn = ai.mageFight,
            .is_fearless = true,
            .spellcaster_backup_action = .Melee,
        },

        .spells = &[_]SpellOptions{
            .{ .MP_cost = 1, .spell = &spells.CAST_POLAR_LAYER, .power = 14 },
            .{ .MP_cost = 1, .spell = &spells.CAST_RESURRECT_BASALT, .power = 21 },
        },
        .max_MP = 5,

        .faction = .Revgenunkim,
        .max_HP = 8,
        .memory_duration = 99,
        .blood = null,
        .corpse = .None,

        .innate_resists = .{ .rElec = 75, .rFire = 75 },
        .stats = .{ .Vision = V },
    },
};

pub const LivingStoneTemplate = MobTemplate{
    .mob = .{
        .id = "living_stone",
        .species = &Species{
            .name = "living stone",
            .default_attack = &Weapon{
                .damage = 3,
                .strs = &[_]DamageStr{
                    items._dmgstr(10, "hit", "hits", ""),
                },
            },
        },
        .tile = 'S',
        .ai = AI{
            .profession_description = "watching",
            .work_fn = ai.dummyWork,
            .fight_fn = ai.meleeFight,
            .is_curious = false,
            .is_fearless = true,
        },

        .faction = .Revgenunkim,
        .immobile = true,
        .max_HP = 5,
        .memory_duration = 1,

        .life_type = .Construct,

        .blood = .Water,
        .corpse = .Wall,

        .innate_resists = .{ .rFire = RESIST_IMMUNE, .rElec = RESIST_IMMUNE, .Armor = 50, .rFume = 100 },
        .stats = .{ .Melee = 100, .Vision = 2 },
    },
    // This status should be added by whatever spell created it.
    //.statuses = &[_]StatusDataInfo{.{ .status = .Lifespan, .duration = .{.Tmp=10} }},
};

const BURNING_BRUTE_CLAW_WEAPON = Weapon{
    .damage = 2,
    .strs = &items.CLAW_STRS,
};

pub const BurningBruteTemplate = MobTemplate{
    .mob = .{
        .id = "burning_brute",
        .species = &Species{
            .name = "burning brute",
            .default_attack = &BURNING_BRUTE_CLAW_WEAPON,
            .aux_attacks = &[_]*const Weapon{
                &BURNING_BRUTE_CLAW_WEAPON,
                &BURNING_BRUTE_CLAW_WEAPON,
                &Weapon{ .knockback = 5, .damage = 1, .strs = &items.KICK_STRS },
            },
        },
        .tile = 'B',
        .alt_name = "brimstone marshal",
        .ai = AI{
            .profession_description = "sulking",
            .work_fn = ai.patrolWork,
            .fight_fn = ai.mageFight,
            //.is_fearless = true, // Flee effect won't trigger otherwise.
            .flee_effect = .{ .status = .Enraged, .duration = .{ .Tmp = 10 }, .exhausting = true },
            .spellcaster_backup_action = .Melee,
            .flags = &[_]AI.Flag{.DetectWithHeat},
        },

        .spells = &[_]SpellOptions{
            .{ .MP_cost = 0, .spell = &spells.BOLT_FIREBALL, .power = 3, .duration = 5 },
            .{ .MP_cost = 5, .spell = &spells.CAST_RESURRECT_FIRE, .power = 200, .duration = 6 },
        },
        .max_MP = 5,

        .faction = .Revgenunkim,
        .multitile = 2,
        .max_HP = 15,
        .memory_duration = 99,
        .blood = null,
        .corpse = .None,

        .innate_resists = .{ .rFire = RESIST_IMMUNE },
        .stats = .{ .Vision = V + 3, .Speed = 90 },
    },
    .statuses = &[_]StatusDataInfo{
        .{ .status = .Fire, .duration = .Prm },
        .{ .status = .Noisy, .duration = .Prm },
    },
};

pub const BurningLanceTemplate = MobTemplate{
    .mob = .{
        .id = "burning_lance",
        .species = &Species{ .name = "burning lance" },
        .tile = '|',
        .ai = AI{
            .profession_description = "[this is a bug]",
            .work_fn = ai.suicideWork,
            .fight_fn = ai.combatDummyFight,
            .flags = &[_]AI.Flag{.IgnoredByEnemies},
            .is_curious = false,
            .is_fearless = true,
        },

        .deaf = true,
        .base_night_vision = true,
        .max_HP = 1,
        .memory_duration = 999999,

        .life_type = .Spectral,
        .faction = .Revgenunkim,
        .blood = null,
        .corpse = .None,

        .innate_resists = .{ .Armor = RESIST_IMMUNE, .rFire = RESIST_IMMUNE, .rElec = RESIST_IMMUNE, .rFume = 100 },
        .stats = .{ .Willpower = WILL_IMMUNE, .Vision = V },
    },
};

pub const MOBS = [_]MobTemplate{
    GuardTemplate,
    PlayerTemplate,
    GoblinChildTemplate,
    GoblinTemplate,
    GoblinStayStillTemplate,
    GoblinCookTemplate,
    GoblinCarpenterTemplate,
    GoblinSmithTemplate,
    ArbalistTemplate,
    MasterArbalistTemplate,
    WarriorTemplate,
    EmberMageTemplate,
    EmberlingTemplate,

    RevgenunkimTemplate,
    CinderBruteTemplate,
    QuicklimeBruteTemplate,
    BasaltFiendTemplate,
    BurningBruteTemplate,

    BurningLanceTemplate,
};

pub const ANGELS = [_]MobTemplate{
    RevgenunkimTemplate,
    CinderBruteTemplate,
    QuicklimeBruteTemplate,
    BasaltFiendTemplate,
    BurningBruteTemplate,
};

pub const PRISONERS = [_]MobTemplate{};

pub fn findMobById(raw_id: anytype) ?*const MobTemplate {
    const id = utils.used(raw_id);
    return for (&MOBS) |*mobt| {
        if (mem.eql(u8, mobt.mob.id, id))
            break mobt;
    } else null;
}

pub const PlaceMobOptions = struct {
    facing: ?Direction = null,
    phase: AIPhase = .Work,
    work_area: ?Coord = null,
    no_squads: bool = false,
    faction: ?types.Faction = null,
    prisoner_of: ?types.Faction = null,
    prm_status1: ?Status = null,
    prm_status2: ?Status = null,
    job: ?types.AIJob.Type = null,
};

pub fn placeMob(
    alloc: mem.Allocator,
    template: *const MobTemplate,
    coord: Coord,
    opts: PlaceMobOptions,
) *Mob {
    {
        var gen = Generator(Rect.rectIter).init(template.mobAreaRect(coord));
        while (gen.next()) |mobcoord|
            assert(state.dungeon.at(mobcoord).mob == null);
    }

    var mob = template.mob;
    mob.init(alloc);

    mob.coord = coord;
    mob.faction = opts.faction orelse mob.faction;
    mob.ai.phase = opts.phase;

    if (opts.job) |j| {
        const job = types.AIJob{ .job = j, .ctx = types.AIJob.Ctx.init(state.GPA.allocator()) };
        mob.jobs.append(job) catch err.wat();
    }

    if (opts.prisoner_of) |f|
        mob.prisoner_status = types.Prisoner{ .of = f };
    if (opts.prm_status1) |s|
        mob.addStatus(s, 0, .Prm);
    if (opts.prm_status2) |s|
        mob.addStatus(s, 0, .Prm);

    if (template.weapon) |w| mob.equipItem(.Weapon, Item{ .Weapon = w });
    if (template.backup_weapon) |w| mob.equipItem(.Backup, Item{ .Weapon = w });
    if (template.armor) |a| mob.equipItem(.Armor, Item{ .Armor = a });
    if (template.cloak) |c| mob.equipItem(.Cloak, Item{ .Cloak = c });

    if (opts.facing) |dir| mob.facing = dir;
    mob.ai.work_area.append(opts.work_area orelse coord) catch err.wat();

    for (template.evocables) |evocable_template| {
        var evocable = items.createItem(Evocable, evocable_template);
        evocable.charges = evocable.max_charges;
        mob.inventory.pack.append(Item{ .Evocable = evocable }) catch err.wat();
    }

    if (template.projectile) |proj| {
        while (!mob.inventory.pack.isFull()) {
            mob.inventory.pack.append(Item{ .Projectile = proj }) catch err.wat();
        }
    }

    for (template.statuses) |status_info| {
        mob.addStatus(status_info.status, status_info.power, status_info.duration);
    }

    state.mobs.append(mob) catch err.wat();
    const mob_ptr = state.mobs.last().?;

    // ---
    // --------------- `mob` mustn't be modified after this point! --------------
    // ---

    if (!opts.no_squads and template.squad.len > 0) {
        // TODO: allow placing squads next to multitile creatures.
        //
        // AFAIK the only thing that needs to be changed is skipping over all of
        // the squad leader's tiles instead of just the main one when choosing
        // tiles to place squadlings on.
        //
        assert(mob.multitile == null);

        const squad_template = rng.chooseUnweighted([]const MobTemplate.SquadMember, template.squad);

        var squad_member_weights = StackBuffer(usize, 20).init(null);
        for (squad_template) |s| squad_member_weights.append(s.weight) catch err.wat();

        const squad_mob_info = rng.choose(
            MobTemplate.SquadMember,
            squad_template,
            squad_member_weights.constSlice(),
        ) catch err.wat();
        const squad_mob = findMobById(squad_mob_info.mob) orelse err.bug("Mob {s} specified in template couldn't be found.", .{squad_mob_info.mob});

        const squad_mob_count = rng.range(usize, squad_mob_info.count.min, squad_mob_info.count.max);

        var i: usize = squad_mob_count;

        const squad = Squad.allocNew();

        while (i > 0) : (i -= 1) {
            var dijk = dijkstra.Dijkstra.init(coord, state.mapgeometry, 3, state.is_walkable, .{ .right_now = true }, alloc);
            defer dijk.deinit();

            const s_coord = while (dijk.next()) |child| {
                // This *should* hold true but for some reason it doesn't. Too
                // lazy to investigate.
                //assert(state.dungeon.at(child).mob == null);
                if (child.eq(coord)) continue; // Don't place in leader's coord
                if (state.dungeon.at(child).mob == null)
                    break child;
            } else null;

            if (s_coord) |c| {
                const underling = placeMob(alloc, squad_mob, c, .{ .no_squads = true });
                underling.squad = squad;
                squad.members.append(underling) catch err.wat();
            }
        }

        squad.leader = mob_ptr;
        mob_ptr.squad = squad;
    }

    {
        var gen = Generator(Rect.rectIter).init(mob_ptr.areaRect());
        while (gen.next()) |mobcoord|
            state.dungeon.at(mobcoord).mob = mob_ptr;
    }

    return mob_ptr;
}

pub fn placeMobSurrounding(c: Coord, t: *const MobTemplate, opts: PlaceMobOptions) void {
    for (&DIRECTIONS) |d| if (c.move(d, state.mapgeometry)) |neighbor| {
        if (state.is_walkable(neighbor, .{ .right_now = true })) {
            const m = placeMob(state.GPA.allocator(), t, neighbor, opts);
            m.cancelStatus(.Sleeping);
        }
    };
}
