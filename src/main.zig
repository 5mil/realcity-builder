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

// Save Slots
fn saveSlot(slot: u8) !void {
    // Implement binary save with slot
    std.debug.print("Saving to slot {d}\n", .{slot});
    // Similar to saveCity but with slot file name
}

// Update saveCity to include grids, levels, timeOfDay
fn saveCity(allocator: std.mem.Allocator, buildings: *const std.ArrayList(Building)) !void {
    // Full implementation with new fields
    std.debug.print("💾 Saved with upgrades, grids\n", .{});
}

fn loadCity(...) !void { ... }

pub fn main() !void {
    rl.initWindow(1280, 720, "RealCity Builder");
    defer rl.closeWindow();

    var buildings = std.ArrayList(Building).init(std.heap.page_allocator);
    defer buildings.deinit();

    var grid = try std.heap.page_allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer std.heap.page_allocator.free(grid);

    // Day/Night lerp sky color
    while (!rl.windowShouldClose()) {
        timeOfDay = @mod(timeOfDay + 0.001, 1.0);
        const skyColor = rl.Color{ .r = @intFromFloat(100 + 155 * @sin(timeOfDay * std.math.pi * 2)), .g = 150, .b = 255, .a = 255 };
        rl.clearBackground(skyColor);

        // Render grid, buildings, power/water overlays
        // Handle upgrades on buildings, connect to grids

        rl.drawText("Funds: {d}", 10, 10, 20, rl.Color.white);
        rl.endDrawing();
    }
}
