const std = @import("std");
const rl = @import("raylib");

const SAVE_VERSION: u32 = 5;

const TileType = enum(u8) { grass, road, water, building };
const ZoneType = enum(u8) { none, residential, commercial };
const ServiceType = enum(u8) { none, power_plant, water_pump, police, fire, hospital, school };

const Building = struct {
    name: []const u8,
    pos_x: u32,
    pos_y: u32,
    size_x: u32,
    size_y: u32,
    population: u32,
    cost: u32,
    zone: ZoneType,
    level: u8 = 1,
    service: ServiceType = .none,
    happiness: f32 = 50.0, // Step 3
};

var funds: i32 = 75000;
var currentZone: ZoneType = .residential;
var currentService: ServiceType = .none;
var currentTile: TileType = .road; // For roads

var timeOfDay: f32 = 0.0;

var powerGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);
var waterGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);

// ... (keep idx, updateGrids, save/load stubs)

// Step 3: Happiness
fn updateHappiness(buildings: *std.ArrayList(Building)) void {
    for (buildings.items) |*b| {
        if (b.zone == .residential) {
            const powered = powerGrid[idx(b.pos_x, b.pos_y)];
            const watered = waterGrid[idx(b.pos_x, b.pos_y)];
            b.happiness = if (powered and watered) @min(b.happiness + 2.0, 100.0) else @max(b.happiness - 1.0, 0.0);
        }
    }
}

fn simulate(...) void { ... // integrate happiness into growth }

pub fn main() !void {
    // ...
    while (!rl.windowShouldClose()) {
        // Key input for modes
        if (rl.isKeyPressed(.key_p)) currentService = .power_plant;
        if (rl.isKeyPressed(.key_w)) currentService = .water_pump;
        if (rl.isKeyPressed(.key_r)) currentTile = .road;

        // Placement logic for roads & services
        if (rl.isMouseButtonPressed(.mouse_left_button)) {
            // ... handle road placement on grid, service placement
        }

        updateGrids(...);
        updateHappiness(&buildings);
        simulate(...);

        // Render improvements
        // Draw roads, buildings with happiness tint, etc.

        rl.drawText(rl.textFormat("Funds: {d} | Pop: {d} | Avg Happiness: {d:.0}", .{funds, totalPop, avgHappiness}), 10, 10, 20, rl.Color.white);
    }
}
