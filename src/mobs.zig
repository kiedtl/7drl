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

pub const CoronerTemplate = MobTemplate{
    .mob = .{
        .id = "coroner",
        .species = &GoblinSpecies,
        .tile = 'a',
        .ai = AI{
            .profession_name = "coroner",
            .profession_description = "doing autopsy",
            .work_fn = ai.coronerWork,
            .fight_fn = ai.coronerFight,
        },

        .max_HP = 8,
        .memory_duration = 10,

        .stats = .{ .Willpower = 1 },
    },
};

pub const GuardTemplate = MobTemplate{
    .mob = .{
        .id = "guard",
        .species = &GoblinSpecies,
        .tile = 'ה',
        .alt_name = "filthy meatbag",
        .ai = AI{
            .profession_name = "guard",
            .profession_description = "guarding",
            .work_fn = ai.guardWork,
            .fight_fn = ai.meleeFight,
        },

        .max_HP = 5,
        .memory_duration = 15,

        .stats = .{ .Willpower = 1, .Melee = 100 },
    },
    .weapon = &items.BludgeonWeapon,
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
        .stats = .{ .Willpower = 4, .Vision = 8, .Melee = 100 },
    },
    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "goblin", .weight = 1, .count = minmax(usize, 0, 1) },
        },
    },
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

pub const WarriorTemplate = MobTemplate{
    .mob = .{
        .id = "warrior",
        .species = &GoblinSpecies,
        .tile = 'W',
        .alt_name = "meat beast",
        .ai = AI{
            .profession_name = "warrior",
            .profession_description = "resting",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            .flee_effect = .{ .status = .Enraged, .duration = .{ .Tmp = 10 }, .exhausting = true },
        },

        .max_HP = 6,
        .memory_duration = 10,
        .stats = .{ .Willpower = 2, .Melee = 100, .Vision = 10 },
    },
    .weapon = &items.MaceWeapon,
    .armor = &items.CuirassArmor,
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
            .{ .MP_cost = 5, .spell = &spells.CAST_CREATE_EMBERLING },
            .{ .MP_cost = 10, .spell = &spells.CAST_FLAMMABLE, .power = 20 },
        },
        .max_MP = 15,

        .max_HP = 7,
        .memory_duration = 10,
        .stats = .{ .Willpower = 4, .Vision = 11 },
    },
    .weapon = &items.BludgeonWeapon,
    .cloak = &items.SilCloak,

    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "emberling", .weight = 1, .count = minmax(usize, 2, 4) },
        },
    },
};

// pub const BrimstoneMageTemplate = MobTemplate{
//     .mob = .{
//         .id = "brimstone_mage",
//         .species = &GoblinSpecies,
//         .tile = 'R',
//         .ai = AI{
//             .profession_name = "brimstone mage",
//             .profession_description = "watching",
//             // Stand still and don't be curious; don't want emberling followers
//             // to burn the world down
//             .work_fn = ai.standStillAndGuardWork,
//             .fight_fn = ai.mageFight,
//             .spellcaster_backup_action = .KeepDistance,
//             .flags = &[_]AI.Flag{.DetectWithHeat},
//         },

//         .spells = &[_]SpellOptions{
//             .{ .MP_cost = 15, .spell = &spells.CAST_CREATE_EMBERLING },
//             .{ .MP_cost = 1, .spell = &spells.CAST_FLAMMABLE, .power = 20 },
//             .{ .MP_cost = 7, .spell = &spells.BOLT_FIREBALL, .power = 3, .duration = 3 },
//         },
//         .max_MP = 15,

//         .max_HP = 7,
//         .memory_duration = 10,
//         .stats = .{ .Willpower = 6 },
//     },
//     .weapon = &items.MaceWeapon,
//     .armor = &items.HauberkArmor,
//     .cloak = &items.SilCloak,

//     .squad = &[_][]const MobTemplate.SquadMember{
//         &[_]MobTemplate.SquadMember{
//             .{ .mob = "emberling", .weight = 1, .count = minmax(usize, 2, 4) },
//         },
//     },
// };

pub const EmberlingTemplate = MobTemplate{
    .mob = .{
        .id = "emberling",
        .species = &Species{
            .name = "emberling",
            .default_attack = &Weapon{
                .damage = 1,
                .damage_kind = .Fire,
                .strs = &items.CLAW_STRS,
            },
        },
        .tile = 'ë',
        .alt_name = "meat slave",
        .ai = AI{
            .profession_description = "watching",
            .work_fn = ai.standStillAndGuardWork,
            .fight_fn = ai.meleeFight,
            .is_curious = false,
            .is_fearless = true,
            .flags = &[_]AI.Flag{.DetectWithHeat},
        },
        .life_type = .Construct,

        .blood = null,
        .corpse = .None,

        .max_HP = 3,
        .memory_duration = 5,
        .innate_resists = .{ .rFume = 100, .rFire = RESIST_IMMUNE },
        .stats = .{ .Willpower = 1, .Vision = 7, .Melee = 100 },
    },
    // XXX: Emberlings are never placed alone, this determines number of
    // summoned emberlings from CAST_CREATE_EMBERLING
    .squad = &[_][]const MobTemplate.SquadMember{
        &[_]MobTemplate.SquadMember{
            .{ .mob = "emberling", .weight = 1, .count = minmax(usize, 2, 3) },
        },
    },
    .statuses = &[_]StatusDataInfo{
        .{ .status = .Sleeping, .duration = .Prm },
        .{ .status = .Fire, .duration = .Prm },
        .{ .status = .Noisy, .duration = .Prm },
    },
};

pub const CinderBruteTemplate = MobTemplate{
    .mob = .{
        .id = "cinder_brute",
        .species = &Species{
            .name = "cinder brute",
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

        .stats = .{ .Willpower = 6, .Vision = 4 },
    },
    .statuses = &[_]StatusDataInfo{.{ .status = .Fire, .duration = .Prm }},
};

pub const MOBS = [_]MobTemplate{
    CoronerTemplate,
    GuardTemplate,
    PlayerTemplate,
    GoblinTemplate,
    WarriorTemplate,
    EmberMageTemplate,
    // BrimstoneMageTemplate,
    EmberlingTemplate,
    CinderBruteTemplate,
};

pub const ANGELS = [_]MobTemplate{
    CinderBruteTemplate,
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

//comptime {
//    @setEvalBranchQuota(MOBS.len * MOBS.len * 10);

//    inline for (&MOBS) |monster| {
//        // Ensure no monsters have conflicting tiles
//        const pu: ?[]const u8 = inline for (&MOBS) |othermonster| {
//            if (!mem.eql(u8, monster.mob.id, othermonster.mob.id) and
//                monster.mob.tile == othermonster.mob.tile and
//                !monster.ignore_conflicting_tiles and
//                !othermonster.ignore_conflicting_tiles)
//            {
//                break othermonster.mob.id;
//            }
//        } else null;
//        if (pu) |prevuse| {
//            @compileError("Monster " ++ prevuse ++ " tile conflicts w/ " ++ monster.mob.id);
//        }

//        // Ensure that no resist is equal to 100
//        //
//        // (Because that usually means that I intended to make them immune to
//        // that damage type, but forgot that terrain and spells can affect that
//        // resist and occasionally make them less-than-immune.)
//        if (monster.mob.innate_resists.rFire == 100 or
//            monster.mob.innate_resists.rElec == 100 or
//            monster.mob.innate_resists.Armor == 100)
//        {
//            @compileError("Monster " ++ monster.mob.id ++ " has false immunity in one or more resistances");
//        }
//    }
//}
