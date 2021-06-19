const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;

const rng = @import("rng.zig");
const items = @import("items.zig");
const machines = @import("machines.zig");
const materials = @import("materials.zig");
const utils = @import("utils.zig");
const state = @import("state.zig");
usingnamespace @import("types.zig");

// Dimensions include the first wall, so a minimum width of 2 guarantee that
// there will be one empty space in the room, minimum.
const MIN_ROOM_WIDTH: usize = 4;
const MIN_ROOM_HEIGHT: usize = 4;
const MAX_ROOM_WIDTH: usize = 10;
const MAX_ROOM_HEIGHT: usize = 10;

const LIMIT = Room{ .start = Coord.new(0, 0), .width = state.WIDTH, .height = state.HEIGHT };
const DISTANCES = [2][6]usize{ .{ 0, 1, 2, 3, 4, 8 }, .{ 3, 8, 4, 3, 2, 1 } };

fn _createItem(comptime T: type, item: T) *T {
    comptime const list = switch (T) {
        Potion => &state.potions,
        Ring => &state.rings,
        Armor => &state.armors,
        Weapon => &state.weapons,
        else => @compileError("uh wat"),
    };
    list.append(item) catch @panic("OOM");
    return list.lastPtr().?;
}

fn _place_prop(coord: Coord, prop_template: *const Prop) *Prop {
    var prop = prop_template.*;
    prop.coord = coord;
    state.props.append(prop) catch unreachable;
    const propptr = state.props.lastPtr().?;
    state.dungeon.at(coord).surface = SurfaceItem{ .Prop = propptr };
    return state.props.lastPtr().?;
}

fn _place_machine(coord: Coord, machine_template: *const Machine) void {
    var machine = machine_template.*;
    machine.coord = coord;
    state.machines.append(machine) catch unreachable;
    const machineptr = state.machines.lastPtr().?;
    state.dungeon.at(coord).surface = SurfaceItem{ .Machine = machineptr };
}

fn _place_normal_door(coord: Coord) void {
    var door = machines.NormalDoor;
    door.coord = coord;
    state.machines.append(door) catch unreachable;
    const doorptr = state.machines.lastPtr().?;
    state.dungeon.at(coord).surface = SurfaceItem{ .Machine = doorptr };
    state.dungeon.at(coord).type = .Floor;
}

// STYLE: make top level public func, call directly, rename placePlayer
fn _add_player(coord: Coord, alloc: *mem.Allocator) void {
    const echoring = _createItem(Ring, items.EcholocationRing);
    echoring.worn_since = state.ticks;

    const armor = _createItem(Armor, items.LeatherArmor);
    const weapon = _createItem(Weapon, items.DaggerWeapon);

    var player = ElfTemplate;
    player.init(alloc);
    player.occupation.phase = .SawHostile;
    player.coord = coord;
    player.inventory.r_rings[0] = echoring;
    player.inventory.armor = armor;
    player.inventory.wielded = weapon;
    state.mobs.append(player) catch unreachable;
    state.dungeon.at(coord).mob = state.mobs.lastPtr().?;
    state.player = state.mobs.lastPtr().?;
}

fn _choosePrefab(prefabs: *PrefabArrayList) ?Prefab {
    var i: usize = 255;
    while (i > 0) : (i -= 1) {
        // Don't use rng.chooseUnweighted, as we need a pointer to manage the
        // restriction amount should we choose it.
        const p = &prefabs.items[rng.range(usize, 0, prefabs.items.len - 1)];
        if (p.invisible) continue;
        if (p.restriction) |res| if (res == 0) continue;

        return p.*;
    }

    return null;
}

fn _room_intersects(rooms: *const RoomArrayList, room: *const Room, ignore: ?*const Room) bool {
    if (room.start.x == 0 or room.start.y == 0)
        return true;
    if (room.start.x >= state.WIDTH or room.start.y >= state.HEIGHT)
        return true;
    if (room.end().x >= state.WIDTH or room.end().y >= state.HEIGHT)
        return true;

    for (rooms.items) |otherroom| {
        // Yes, I understand that this is ugly. No, I don't care.
        if (ignore) |ign| {
            if (otherroom.start.eq(ign.start))
                if (otherroom.width == ign.width)
                    if (otherroom.height == ign.height)
                        continue;
        }
        if (room.intersects(&otherroom, 1)) return true;
    }

    return false;
}

fn _excavate_prefab(room: *const Room, fab: *const Prefab, allocator: *mem.Allocator) void {
    var y: usize = 0;
    while (y < fab.height) : (y += 1) {
        var x: usize = 0;
        while (x < fab.width) : (x += 1) {
            const rc = Coord.new2(room.start.z, x + room.start.x, y + room.start.y);
            assert(rc.x < WIDTH);
            assert(rc.y < HEIGHT);

            const tt: ?TileType = switch (fab.content[y][x]) {
                .Any => null,
                .Wall, .Connection => .Wall,
                .Feature,
                .LockedDoor,
                .Door,
                .Bars,
                .Lamp,
                .Floor,
                => .Floor,
                .Water => .Water,
                .Lava => .Lava,
            };
            if (tt) |_tt| state.dungeon.at(rc).type = _tt;

            switch (fab.content[y][x]) {
                .Feature => |feature_id| {
                    const feature = fab.features[feature_id].?;
                    switch (feature) {
                        .Prop => |pid| {
                            const prop = utils.findById(&machines.PROPS, pid).?;
                            _ = _place_prop(rc, &machines.PROPS[prop]);
                        },
                        .Machine => |mid| {
                            if (utils.findById(&machines.MACHINES, mid)) |mach| {
                                _place_machine(rc, &machines.MACHINES[mach]);
                            } else {
                                std.log.warn(
                                    "{}: Couldn't load machine {}, skipping.",
                                    .{ utils.used(fab.name), utils.used(mid) },
                                );
                            }
                        },
                    }
                },
                .LockedDoor, .Door => _place_normal_door(rc),
                .Lamp => _place_machine(rc, &machines.Lamp),
                .Bars => _ = _place_prop(rc, &machines.IronBarProp),
                else => {},
            }
        }
    }

    for (fab.mobs) |maybe_mob| {
        if (maybe_mob) |mob_f| {
            if (utils.findById(&MOBS, mob_f.id)) |mob_template| {
                var coord = room.start.add(mob_f.spawn_at);
                var mob = MOBS[mob_template];
                mob.init(allocator);
                if (mob_f.work_at) |work_at|
                    mob.occupation.work_area.append(room.start.add(work_at)) catch @panic("OOM");
                mob.coord = coord;
                state.mobs.append(mob) catch @panic("OOM");
                const mobptr = state.mobs.lastPtr().?;
                state.dungeon.at(coord).mob = mobptr;
            } else {
                std.log.warn(
                    "{}: Couldn't load mob {}, skipping.",
                    .{ utils.used(fab.name), utils.used(mob_f.id) },
                );
            }
        }
    }
}

fn _excavate_room(room: *const Room) void {
    var y = room.start.y;
    while (y < room.end().y) : (y += 1) {
        var x = room.start.x;
        while (x < room.end().x) : (x += 1) {
            const c = Coord.new2(room.start.z, x, y);
            assert(c.x < WIDTH and c.y < HEIGHT);
            state.dungeon.at(c).type = .Floor;
        }
    }
}

fn _place_rooms(rooms: *RoomArrayList, fabs: *PrefabArrayList, level: usize, allocator: *mem.Allocator) void {
    // parent is non-const because we might need to update connectors on it.
    var parent = rng.chooseUnweighted(Room, rooms.items);

    var fab: ?Prefab = null;
    var distance = rng.choose(usize, &DISTANCES[0], &DISTANCES[1]) catch unreachable;
    var child: Room = undefined;
    var side = rng.chooseUnweighted(Direction, &CARDINAL_DIRECTIONS);

    if (rng.onein(3)) {
        if (parent.prefab != null and distance == 0) distance += 1;

        var child_w = rng.range(usize, MIN_ROOM_WIDTH, MAX_ROOM_WIDTH);
        var child_h = rng.range(usize, MIN_ROOM_HEIGHT, MAX_ROOM_HEIGHT);
        child = parent.attach(side, child_w, child_h, distance, null) orelse return;

        while (_room_intersects(rooms, &child, &parent) or child.overflowsLimit(&LIMIT)) {
            if (child_w < MIN_ROOM_WIDTH or child_h < MIN_ROOM_HEIGHT)
                return;

            child_w -= 1;
            child_h -= 1;
            child = parent.attach(side, child_w, child_h, distance, null).?;
        }

        _excavate_room(&child);
    } else {
        if (distance == 0) distance += 1;

        var child_w = rng.range(usize, MIN_ROOM_WIDTH, MAX_ROOM_WIDTH);
        var child_h = rng.range(usize, MIN_ROOM_HEIGHT, MAX_ROOM_HEIGHT);
        fab = _choosePrefab(fabs) orelse return;
        child = parent.attach(side, fab.?.width, fab.?.height, distance, &fab.?) orelse return;
        child.prefab = fab;

        if (_room_intersects(rooms, &child, &parent) or child.overflowsLimit(&LIMIT))
            return;

        _excavate_prefab(&child, &fab.?, allocator);
    }

    rooms.append(child) catch unreachable;

    // Now we're finally sure that we've used the prefab, we can decrement the
    // restriction counter.
    if (child.prefab) |f|
        Prefab.decrementPrefabRestrictionCounter(utils.used(f.name), fabs);

    // --- add corridors ---

    if (distance > 0) corridor: {
        var corridor_coord = Coord.new2(level, 0, 0);
        var parent_connector_coord: ?Coord = null;
        var child_connector_coord: ?Coord = null;

        if (parent.prefab != null or child.prefab != null) {
            if (parent.prefab) |*f| {
                const con = f.connectorFor(side) orelse break :corridor;
                corridor_coord.x = parent.start.x + con.x;
                corridor_coord.y = parent.start.y + con.y;
                parent_connector_coord = corridor_coord;
                f.useConnector(con) catch unreachable;
            }
            if (child.prefab) |*f| {
                const con = f.connectorFor(side.opposite()) orelse break :corridor;
                corridor_coord.x = child.start.x + con.x;
                corridor_coord.y = child.start.y + con.y;
                child_connector_coord = corridor_coord;
                f.useConnector(con) catch unreachable;
            }
        } else {
            const rsx = math.max(parent.start.x, child.start.x);
            const rex = math.min(parent.end().x, child.end().x);
            const rsy = math.max(parent.start.y, child.start.y);
            const rey = math.min(parent.end().y, child.end().y);
            corridor_coord.x = rng.range(usize, math.min(rsx, rex), math.max(rsx, rex) - 1);
            corridor_coord.y = rng.range(usize, math.min(rsy, rey), math.max(rsy, rey) - 1);
        }

        var corridor = switch (side) {
            .North => Room{
                .start = Coord.new2(level, corridor_coord.x, child.end().y),
                .height = parent.start.y - child.end().y,
                .width = 1,
            },
            .South => Room{
                .start = Coord.new2(level, corridor_coord.x, parent.end().y),
                .height = child.start.y - parent.end().y,
                .width = 1,
            },
            .West => Room{
                .start = Coord.new2(level, child.end().x, corridor_coord.y),
                .height = 1,
                .width = parent.start.x - child.end().x,
            },
            .East => Room{
                .start = Coord.new2(level, parent.end().x, corridor_coord.y),
                .height = 1,
                .width = child.start.x - parent.end().x,
            },
            else => unreachable,
        };

        _excavate_room(&corridor);
        rooms.append(corridor) catch unreachable;

        // When using a prefab, the corridor doesn't include the connectors. Excavate
        // the connectors (both the beginning and the end) manually.
        if (parent_connector_coord) |acon| state.dungeon.at(acon).type = .Floor;
        if (child_connector_coord) |acon| state.dungeon.at(acon).type = .Floor;

        if (distance == 1) _place_normal_door(corridor.start);
    }
}

pub fn placeRandomRooms(fabs: *PrefabArrayList, level: usize, num: usize, allocator: *mem.Allocator) void {
    var rooms = RoomArrayList.init(allocator);

    const x = rng.range(usize, 1, state.WIDTH / 2);
    const y = rng.range(usize, 1, state.HEIGHT / 2);
    var first: Room = undefined;

    if (Configs[level].starting_prefab) |prefab_name| {
        const prefab = Prefab.findPrefabByName(prefab_name, fabs).?;
        first = Room{
            .start = Coord.new2(level, x, y),
            .width = prefab.width,
            .height = prefab.height,
            .prefab = prefab,
        };
        _excavate_prefab(&first, &prefab, allocator);
    } else {
        const width = rng.range(usize, MIN_ROOM_WIDTH, MAX_ROOM_WIDTH);
        const height = rng.range(usize, MIN_ROOM_HEIGHT, MAX_ROOM_HEIGHT);
        first = Room{ .start = Coord.new2(level, x, y), .width = width, .height = height };
        _excavate_room(&first);
    }

    rooms.append(first) catch unreachable;

    if (level == PLAYER_STARTING_LEVEL) {
        var p = Coord.new2(level, first.start.x + 1, first.start.y + 1);
        if (first.prefab) |prefab|
            if (prefab.player_position) |pos| {
                p = Coord.new2(level, first.start.x + pos.x, first.start.y + pos.y);
            };
        _add_player(p, allocator);
    }

    var c = num;
    while (c > 0) : (c -= 1) _place_rooms(&rooms, fabs, level, allocator);

    state.dungeon.rooms[level] = rooms;
}

pub fn placeItems(level: usize) void {
    for (state.dungeon.rooms[level].items) |room| {
        if (room.prefab) |rfb| if (rfb.noitems) continue;
        if ((room.height * room.width) < 20) continue;

        if (rng.onein(3)) {
            var place = rng.range(usize, 1, 4);
            while (place > 0) {
                const coord = room.randomCoord();
                if (state.dungeon.hasMachine(coord) or state.dungeon.at(coord).item != null)
                    continue;

                const potion = rng.chooseUnweighted(Potion, &items.POTIONS);
                state.potions.append(potion) catch unreachable;
                state.dungeon.at(coord).item = Item{ .Potion = state.potions.lastPtr().? };

                place -= 1;
            }
        }
    }
}

pub fn placeTraps(level: usize) void {
    for (state.dungeon.rooms[level].items) |room| {
        if (room.prefab) |rfb| if (rfb.notraps) continue;

        // Don't place traps in places where it's impossible to avoid
        if (room.height == 1 or room.width == 1) continue;

        if (rng.onein(2)) {
            const trap_coord = room.randomCoord();
            if (state.dungeon.at(trap_coord).surface != null) continue;

            var trap: Machine = undefined;
            if (rng.onein(3)) {
                trap = machines.AlarmTrap;
            } else {
                trap = if (rng.onein(3)) machines.PoisonGasTrap else machines.ParalysisGasTrap;
                var num_of_vents = rng.range(usize, 1, 3);
                while (num_of_vents > 0) : (num_of_vents -= 1) {
                    const vent = room.randomCoord();
                    if (state.dungeon.hasMachine(vent)) continue;

                    const prop = _place_prop(vent, &machines.GasVentProp);
                    trap.props[num_of_vents] = prop;
                }
            }
            _place_machine(trap_coord, &trap);
        }
    }
}

pub fn placeGuards(level: usize, allocator: *mem.Allocator) void {
    var squads: usize = rng.range(usize, 3, 5);
    while (squads > 0) : (squads -= 1) {
        const room = rng.chooseUnweighted(Room, state.dungeon.rooms[level].items);
        const patrol_units = rng.range(usize, 2, 4) % math.max(room.width, room.height);
        var patrol_warden: ?*Mob = null;

        if (room.prefab) |rfb| if (rfb.noguards) continue;

        var placed_units: usize = 0;
        while (placed_units < patrol_units) {
            const rnd = room.randomCoord();

            if (state.dungeon.at(rnd).mob == null) {
                const armor = _createItem(Armor, items.HeavyChainmailArmor);
                const weapon = _createItem(Weapon, items.SpearWeapon);

                var guard = GuardTemplate;
                guard.init(allocator);
                guard.occupation.work_area.append(rnd) catch unreachable;
                guard.coord = rnd;
                guard.inventory.armor = armor;
                guard.inventory.wielded = weapon;
                state.mobs.append(guard) catch unreachable;
                const mobptr = state.mobs.lastPtr().?;
                state.dungeon.at(rnd).mob = mobptr;

                if (patrol_warden) |warden| {
                    warden.squad_members.append(mobptr) catch unreachable;
                } else {
                    patrol_warden = mobptr;
                }

                placed_units += 1;
            }
        }
    }

    for (state.dungeon.rooms[level].items) |room| {
        if (room.prefab) |rfb| if (rfb.noguards) continue;

        if (rng.onein(14)) {
            const post_coord = room.randomCoord();
            var watcher = WatcherTemplate;
            watcher.init(allocator);
            watcher.occupation.work_area.append(post_coord) catch unreachable;
            watcher.coord = post_coord;
            watcher.facing = .North;
            state.mobs.append(watcher) catch unreachable;
            state.dungeon.at(post_coord).mob = state.mobs.lastPtr().?;
        }
    }
}

pub fn placeLights(level: usize) void {
    for (state.dungeon.rooms[level].items) |room| {
        if (room.prefab) |rfb| if (rfb.nolights) continue;

        // Don't light small rooms.
        if ((room.width * room.height) < 10)
            continue;

        // Don't light corridors.
        if (room.width == 1 or room.height == 1)
            continue;

        var spacing: usize = rng.range(usize, 0, 2);
        var y: usize = 0;
        while (y < room.height) : (y += 1) {
            if (spacing == 0) {
                spacing = rng.range(usize, 4, 8);

                const coord1 = Coord.new2(level, room.start.x, room.start.y + y);
                var lamp1 = machines.Lamp;
                lamp1.powered_luminescence -= rng.range(usize, 0, 30);

                const coord2 = Coord.new2(level, room.end().x - 1, room.start.y + y);
                var lamp2 = machines.Lamp;
                lamp2.powered_luminescence -= rng.range(usize, 0, 30);

                if (!state.dungeon.hasMachine(coord1) and
                    state.dungeon.neighboringWalls(coord1, false) == 2 and
                    state.dungeon.neighboringMachines(coord1) == 0 and
                    state.dungeon.at(coord1).type == .Floor)
                {
                    _place_machine(coord1, &lamp1);
                }

                if (!state.dungeon.hasMachine(coord2) and
                    state.dungeon.neighboringWalls(coord2, false) == 2 and
                    state.dungeon.neighboringMachines(coord2) == 0 and
                    state.dungeon.at(coord2).type == .Floor)
                {
                    _place_machine(coord2, &lamp2);
                }
            }

            spacing -= 1;
        }
    }
}

pub fn placeRandomStairs(level: usize) void {
    if (level == (state.LEVELS - 1)) {
        return;
    }

    var placed: usize = 0;
    while (placed < 5) {
        const room = rng.chooseUnweighted(Room, state.dungeon.rooms[level].items);
        const rand = room.randomCoord();
        const above = Coord.new2(level, rand.x, rand.y);
        const below = Coord.new2(level + 1, rand.x, rand.y);

        if (!state.dungeon.hasMachine(above) and
            !state.dungeon.hasMachine(below) and
            state.is_walkable(below) and
            state.is_walkable(above))
        {
            _place_machine(above, &machines.StairDown);
            _place_machine(below, &machines.StairUp);

            placed += 1;
        }
    }
}

pub fn cellularAutomata(avoid: *const [HEIGHT][WIDTH]bool, level: usize, wall_req: usize, isle_req: usize) void {
    var old: [HEIGHT][WIDTH]TileType = undefined;
    {
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < WIDTH) : (x += 1)
                old[y][x] = state.dungeon.at(Coord.new2(level, x, y)).type;
        }
    }

    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            if (avoid[y][x]) continue;
            const coord = Coord.new2(level, x, y);

            var neighbor_walls: usize = if (old[coord.y][coord.x] == .Wall) 1 else 0;
            for (&DIRECTIONS) |direction| {
                var new = coord;
                if (!new.move(direction, state.mapgeometry))
                    continue;
                if (old[new.y][new.x] == .Wall)
                    neighbor_walls += 1;
            }

            if (neighbor_walls >= wall_req) {
                state.dungeon.at(coord).type = .Wall;
            } else if (neighbor_walls <= isle_req) {
                state.dungeon.at(coord).type = .Wall;
            } else {
                state.dungeon.at(coord).type = .Floor;
            }
        }
    }
}

pub fn fillBar(level: usize, height: usize) void {
    // add a horizontal bar of floors in the center of the map as it may
    // prevent a continuous vertical wall from forming during cellular automata,
    // thus preventing isolated sections
    const halfway = HEIGHT / 2;
    var y: usize = halfway;
    while (y < (halfway + height)) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            state.dungeon.at(Coord.new2(level, x, y)).type = .Floor;
        }
    }
}

pub fn fillRandom(avoid: *const [HEIGHT][WIDTH]bool, level: usize, floor_chance: usize) void {
    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            if (avoid[y][x]) continue;
            const coord = Coord.new2(level, x, y);

            const t: TileType = if (rng.range(usize, 0, 100) > floor_chance) .Wall else .Floor;
            state.dungeon.at(coord).type = t;
        }
    }
}

pub fn cellularAutomataAvoidanceMap(level: usize) [HEIGHT][WIDTH]bool {
    var res: [HEIGHT][WIDTH]bool = undefined;

    const rooms = &state.dungeon.rooms[level];

    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const coord = Coord.new2(level, x, y);
            const room = Room{ .start = coord, .width = 1, .height = 1 };
            res[y][x] = _room_intersects(rooms, &room, null);
        }
    }

    return res;
}

pub const Prefab = struct {
    invisible: bool = false,
    restriction: ?usize = null,
    noitems: bool = false,
    noguards: bool = false,
    nolights: bool = false,
    notraps: bool = false,

    name: [32:0]u8 = mem.zeroes([32:0]u8),
    player_position: ?Coord = null,

    height: usize = 0,
    width: usize = 0,
    content: [40][40]FabTile = undefined,
    connections: [80]?Connection = undefined,
    features: [255]?Feature = [_]?Feature{null} ** 255,
    mobs: [20]?FeatureMob = [_]?FeatureMob{null} ** 20,

    pub const FabTile = union(enum) {
        Wall, LockedDoor, Door, Lamp, Floor, Connection, Water, Lava, Bars, Feature: u8, Any
    };

    pub const FeatureMob = struct {
        id: [32:0]u8,
        spawn_at: Coord,
        work_at: ?Coord,
    };

    pub const Feature = union(enum) {
        Machine: [32:0]u8,
        Prop: [32:0]u8,
    };

    pub const Connection = struct {
        c: Coord,
        d: Direction,
        used: bool = false,
    };

    pub fn useConnector(self: *Prefab, c: Coord) !void {
        for (self.connections) |maybe_con, i| {
            const con = maybe_con orelse break;
            if (con.c.eq(c)) {
                if (con.used) return error.ConnectorAlreadyUsed;
                self.connections[i].?.used = true;
                return;
            }
        }
        return error.NoSuchConnector;
    }

    pub fn connectorFor(self: *const Prefab, d: Direction) ?Coord {
        for (self.connections) |maybe_con| {
            const con = maybe_con orelse break;
            if (con.d == d and !con.used) return con.c;
        }
        return null;
    }

    pub fn parse(from: []const u8) !Prefab {
        var f: Prefab = .{};
        for (f.content) |*row| mem.set(FabTile, row, .Wall);
        mem.set(?Connection, &f.connections, null);

        var ci: usize = 0; // index for f.connections
        var cm: usize = 0; // index for f.mobs
        var w: usize = 0;
        var y: usize = 0;

        var lines = mem.tokenize(from, "\n");
        while (lines.next()) |line| {
            switch (line[0]) {
                '%' => {}, // ignore comments
                ':' => {
                    var words = mem.tokenize(line[1..], " ");
                    const key = words.next() orelse return error.MalformedMetadata;
                    const val = words.next() orelse "";

                    if (mem.eql(u8, key, "invisible")) {
                        if (val.len != 0) return error.UnexpectedMetadataValue;
                        f.invisible = true;
                    } else if (mem.eql(u8, key, "restriction")) {
                        if (val.len == 0) return error.ExpectedMetadataValue;
                        f.restriction = std.fmt.parseInt(usize, val, 0) catch |_| return error.InvalidMetadataValue;
                    } else if (mem.eql(u8, key, "noguards")) {
                        if (val.len != 0) return error.UnexpectedMetadataValue;
                        f.noguards = true;
                    } else if (mem.eql(u8, key, "nolights")) {
                        if (val.len != 0) return error.UnexpectedMetadataValue;
                        f.nolights = true;
                    } else if (mem.eql(u8, key, "notraps")) {
                        if (val.len != 0) return error.UnexpectedMetadataValue;
                        f.notraps = true;
                    } else if (mem.eql(u8, key, "spawn")) {
                        const spawn_at_str = words.next() orelse return error.ExpectedMetadataValue;
                        const maybe_work_at_str: ?[]const u8 = words.next() orelse null;

                        var spawn_at = Coord.new(0, 0);
                        var spawn_at_tokens = mem.tokenize(spawn_at_str, ",");
                        const spawn_at_str_a = spawn_at_tokens.next() orelse return error.InvalidMetadataValue;
                        const spawn_at_str_b = spawn_at_tokens.next() orelse return error.InvalidMetadataValue;
                        spawn_at.x = std.fmt.parseInt(usize, spawn_at_str_a, 0) catch |_| return error.InvalidMetadataValue;
                        spawn_at.y = std.fmt.parseInt(usize, spawn_at_str_b, 0) catch |_| return error.InvalidMetadataValue;

                        f.mobs[cm] = FeatureMob{
                            .id = undefined,
                            .spawn_at = spawn_at,
                            .work_at = null,
                        };
                        utils.copyZ(&f.mobs[cm].?.id, val);

                        if (maybe_work_at_str) |work_at_str| {
                            var work_at = Coord.new(0, 0);
                            var work_at_tokens = mem.tokenize(work_at_str, ",");
                            const work_at_str_a = work_at_tokens.next() orelse return error.InvalidMetadataValue;
                            const work_at_str_b = work_at_tokens.next() orelse return error.InvalidMetadataValue;
                            work_at.x = std.fmt.parseInt(usize, work_at_str_a, 0) catch |_| return error.InvalidMetadataValue;
                            work_at.y = std.fmt.parseInt(usize, work_at_str_b, 0) catch |_| return error.InvalidMetadataValue;
                            f.mobs[cm].?.work_at = work_at;
                        }

                        cm += 1;
                    }
                },
                '@' => {
                    var words = mem.tokenize(line, " ");
                    _ = words.next(); // Skip the '@<ident>' bit

                    const identifier = line[1];
                    const feature_type = words.next() orelse return error.MalformedFeatureDefinition;
                    if (feature_type.len != 1) return error.InvalidFeatureType;

                    switch (feature_type[0]) {
                        'p' => {
                            const id = words.next() orelse return error.MalformedFeatureDefinition;
                            f.features[identifier] = Feature{ .Prop = [_:0]u8{0} ** 32 };
                            mem.copy(u8, &f.features[identifier].?.Prop, id);
                        },
                        'm' => {
                            const id = words.next() orelse return error.MalformedFeatureDefinition;
                            f.features[identifier] = Feature{ .Machine = [_:0]u8{0} ** 32 };
                            mem.copy(u8, &f.features[identifier].?.Machine, id);
                        },
                        else => return error.InvalidFeatureType,
                    }
                },
                else => {
                    if (y > f.content.len) return error.FabTooTall;

                    var x: usize = 0;
                    var utf8view = std.unicode.Utf8View.init(line) catch |_| {
                        return error.InvalidUtf8;
                    };
                    var utf8 = utf8view.iterator();
                    while (utf8.nextCodepointSlice()) |encoded_codepoint| : (x += 1) {
                        if (x > f.content[0].len) return error.FabTooWide;

                        const c = std.unicode.utf8Decode(encoded_codepoint) catch |_| {
                            return error.InvalidUtf8;
                        };

                        f.content[y][x] = switch (c) {
                            '#' => .Wall,
                            '+' => .Door,
                            '±' => .LockedDoor,
                            '•' => .Lamp,
                            '@' => player: {
                                f.player_position = Coord.new(x, y);
                                break :player .Floor;
                            },
                            '.' => .Floor,
                            '*' => con: {
                                f.connections[ci] = .{
                                    .c = Coord.new(x, y),
                                    .d = .North,
                                };
                                ci += 1;

                                break :con .Connection;
                            },
                            '~' => .Water,
                            '≈' => .Lava,
                            '≡' => .Bars,
                            '?' => .Any,
                            '0'...'9', 'a'...'z' => FabTile{ .Feature = @intCast(u8, c) },
                            else => return error.InvalidFabTile,
                        };
                    }

                    if (x > w) w = x;
                    y += 1;
                },
            }
        }

        f.width = w;
        f.height = y;

        for (&f.connections) |*con, i| {
            if (con.*) |c| {
                if (c.c.x == 0) {
                    f.connections[i].?.d = .West;
                } else if (c.c.y == 0) {
                    f.connections[i].?.d = .North;
                } else if (c.c.y == (f.height - 1)) {
                    f.connections[i].?.d = .South;
                } else if (c.c.x == (f.width - 1)) {
                    f.connections[i].?.d = .East;
                } else {
                    return error.InvalidConnection;
                }
            }
        }

        return f;
    }

    pub fn findPrefabByName(name: []const u8, fabs: *const PrefabArrayList) ?Prefab {
        for (fabs.items) |f| if (mem.eql(u8, name, f.name[0..mem.lenZ(f.name)])) return f;
        return null;
    }

    pub fn decrementPrefabRestrictionCounter(id: []const u8, lst: *const PrefabArrayList) void {
        for (lst.items) |*f| {
            if (mem.eql(u8, id, f.name[0..mem.lenZ(f.name)])) {
                if (f.restriction) |_| f.restriction.? -= 1;
            }
        }
    }
};

pub const PrefabArrayList = std.ArrayList(Prefab);

// FIXME: error handling
pub fn readPrefabs(alloc: *mem.Allocator) PrefabArrayList {
    var buf: [2048]u8 = undefined;
    var fabs = PrefabArrayList.init(alloc);

    const fabs_dir = std.fs.cwd().openDir("prefabs", .{
        .iterate = true,
    }) catch unreachable;

    var fabs_dir_iterator = fabs_dir.iterate();
    while (fabs_dir_iterator.next() catch unreachable) |fab_file| {
        if (fab_file.kind != .File) continue;

        var fab_f = fabs_dir.openFile(fab_file.name, .{
            .read = true,
            .lock = .None,
        }) catch unreachable;
        defer fab_f.close();

        const read = fab_f.readAll(buf[0..]) catch unreachable;

        var f = Prefab.parse(buf[0..read]) catch |e| {
            const msg = switch (e) {
                error.InvalidFabTile => "Invalid prefab tile",
                error.InvalidConnection => "Out of place connection tile",
                error.FabTooWide => "Prefab exceeds width limit",
                error.FabTooTall => "Prefab exceeds height limit",
                error.InvalidFeatureType => "Unknown feature type encountered",
                error.MalformedFeatureDefinition => "Invalid syntax for feature definition",
                error.MalformedMetadata => "Malformed metadata",
                error.InvalidMetadataValue => "Invalid value for metadata",
                error.UnexpectedMetadataValue => "Unexpected value for metadata",
                error.ExpectedMetadataValue => "Expected value for metadata",
                error.InvalidUtf8 => "Encountered invalid UTF-8",
            };
            std.log.warn("{}: Couldn't load prefab: {}", .{ fab_file.name, msg });
            continue;
        };
        mem.copy(u8, &f.name, mem.trimRight(u8, fab_file.name, ".fab"));

        fabs.append(f) catch @panic("OOM");
    }

    return fabs;
}

pub const LevelConfig = struct {
    starting_prefab: ?[]const u8 = null,
};

pub const Configs = [LEVELS]LevelConfig{
    .{ .starting_prefab = "ENT_start" },
    .{ .starting_prefab = "PRI_start" },
    .{},
};
