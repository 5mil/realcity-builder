const std = @import("std");
const rl = @import("raylib");

const SAVE_VERSION: u32 = 3; // bumped for grids, upgrades, day/night, slots

const TileType = enum(u8) { grass, road, water, building };
const ZoneType = enum(u8) { none, residential, commercial };
const Building = struct {
    name: []const u8,
    pos_x: u32,
    pos_y: u32,
    size_x: u32,
    size_y: u32,
    population: u32,
    cost: u32,
    zone: ZoneType,
    level: u8 = 1, // Building Upgrades
};

const Blueprint = struct {
    name: []const u8,
    size_x: u32,
    size_y: u32,
    cost: u32,
};

const GRID_WIDTH: usize = 160;
const GRID_HEIGHT: usize = 110;
const TILE_SIZE: f32 = 15.0;

var funds: i32 = 75000;
var currentZone: ZoneType = .residential;

var timeOfDay: f32 = 0.0; // Day/Night cycle

var powerGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);
var waterGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);

fn loadMockOSM(grid: []TileType) void {}
fn getMockWeather() []const u8 { return "Sunny 71°F"; }

fn simulate(buildings: *std.ArrayList(Building), totalPop: *u32) void {
    totalPop.* = 0;
    for (buildings.items) |*b| {
        const growth = if (b.zone == .residential) @as(u32, 12) else 6;
        b.population = @min(b.population + growth, 1500);
        totalPop.* += b.population;
    }
}

// Full Save Slots implementation
fn saveSlot(slot: u8, buildings: *const std.ArrayList(Building), grid: []const TileType) !void {
    var filename_buf: [32]u8 = undefined;
    const filename = try std.fmt.bufPrint(&filename_buf, "city_save_{d}.bin", .{slot});
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeInt(u32, SAVE_VERSION, .little);
    try writer.writeInt(i32, funds, .little);
    try writer.writeInt(f32, timeOfDay, .little);

    // Grid data
    try writer.writeInt(u32, GRID_WIDTH, .little);
    try writer.writeInt(u32, GRID_HEIGHT, .little);
    for (grid) |tile| {
        try writer.writeInt(u8, @intFromEnum(tile), .little);
    }
    for (powerGrid) |p| {
        try writer.writeInt(u8, @intFromBool(p), .little);
    }
    for (waterGrid) |w| {
        try writer.writeInt(u8, @intFromBool(w), .little);
    }

    // Buildings
    try writer.writeInt(u32, @as(u32, @intCast(buildings.items.len)), .little);
    for (buildings.items) |b| {
        try writer.writeInt(u32, @as(u32, @intCast(b.name.len)), .little);
        try writer.writeAll(b.name);
        try writer.writeInt(u32, b.pos_x, .little);
        try writer.writeInt(u32, b.pos_y, .little);
        try writer.writeInt(u32, b.size_x, .little);
        try writer.writeInt(u32, b.size_y, .little);
        try writer.writeInt(u32, b.population, .little);
        try writer.writeInt(u32, b.cost, .little);
        try writer.writeInt(u8, @intFromEnum(b.zone), .little);
        try writer.writeInt(u8, b.level, .little);
    }
    std.debug.print("💾 Saved to slot {d} ({s})\n", .{ slot, filename });
}

// Updated saveCity (delegates to slot 0 by default)
fn saveCity(allocator: std.mem.Allocator, buildings: *const std.ArrayList(Building), grid: []const TileType) !void {
    try saveSlot(0, buildings, grid);
}

// Full loadCity with grids, levels, timeOfDay
fn loadCity(allocator: std.mem.Allocator, buildings: *std.ArrayList(Building), grid: []TileType, slot: u8) !void {
    var filename_buf: [32]u8 = undefined;
    const filename = try std.fmt.bufPrint(&filename_buf, "city_save_{d}.bin", .{slot});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const reader = file.reader();

    const version = try reader.readInt(u32, .little);
    if (version != SAVE_VERSION) {
        std.debug.print("⚠️ Save version mismatch\n", .{});
        return error.VersionMismatch;
    }

    funds = try reader.readInt(i32, .little);
    timeOfDay = try reader.readInt(f32, .little);

    // Skip grid dims for now (assume fixed)
    _ = try reader.readInt(u32, .little);
    _ = try reader.readInt(u32, .little);
    for (grid) |*tile| {
        tile.* = @enumFromInt(try reader.readInt(u8, .little));
    }
    for (&powerGrid) |*p| {
        p.* = (try reader.readInt(u8, .little)) != 0;
    }
    for (&waterGrid) |*w| {
        w.* = (try reader.readInt(u8, .little)) != 0;
    }

    const numBuildings = try reader.readInt(u32, .little);
    buildings.clearRetainingCapacity();
    var i: usize = 0;
    while (i < numBuildings) : (i += 1) {
        const nameLen = try reader.readInt(u32, .little);
        const name = try allocator.alloc(u8, nameLen);
        _ = try reader.readAll(name);
        const b = Building{
            .name = name,
            .pos_x = try reader.readInt(u32, .little),
            .pos_y = try reader.readInt(u32, .little),
            .size_x = try reader.readInt(u32, .little),
            .size_y = try reader.readInt(u32, .little),
            .population = try reader.readInt(u32, .little),
            .cost = try reader.readInt(u32, .little),
            .zone = @enumFromInt(try reader.readInt(u8, .little)),
            .level = try reader.readInt(u8, .little),
        };
        try buildings.append(b);
    }
    std.debug.print("📂 Loaded slot {d}\n", .{slot});
}

pub fn main() !void {
    rl.initWindow(1280, 720, "RealCity Builder");
    defer rl.closeWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buildings = std.ArrayList(Building).init(allocator);
    defer buildings.deinit();

    var grid = try allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer allocator.free(grid);
    @memset(grid, .grass);

    // Example save/load usage (bind to keys later)
    // try saveSlot(1, &buildings, grid);
    // try loadCity(allocator, &buildings, grid, 1);

    while (!rl.windowShouldClose()) {
        timeOfDay = @mod(timeOfDay + 0.001, 1.0);
        const skyColor = rl.Color{ .r = @intFromFloat(100 + 155 * @sin(timeOfDay * std.math.pi * 2)), .g = 150, .b = 255, .a = 255 };
        rl.clearBackground(skyColor);

        // TODO: Render grid, buildings, power/water overlays, handle upgrades

        rl.drawText("Funds: {d} | Time: {d:.1}", 10, 10, 20, rl.Color.white);
        rl.endDrawing();
    }
}
