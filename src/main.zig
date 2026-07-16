const std = @import("std");
const rl = @import("raylib");

const SAVE_VERSION: u32 = 4; // bumped for services & coverage

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
    service: ServiceType = .none, // New for services
};

const GRID_WIDTH: usize = 160;
const GRID_HEIGHT: usize = 110;
const TILE_SIZE: f32 = 15.0;

var funds: i32 = 75000;
var currentZone: ZoneType = .residential;
var currentService: ServiceType = .none; // For placement mode

var timeOfDay: f32 = 0.0;

var powerGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);
var waterGrid: [GRID_WIDTH * GRID_HEIGHT]bool = [_]bool{false} ** (GRID_WIDTH * GRID_HEIGHT);

fn idx(x: u32, y: u32) usize {
    return @as(usize, y) * GRID_WIDTH + @as(usize, x);
}

// Step 1: Power/Water coverage (simple spread from plants)
fn updateGrids(grid: []const TileType, buildings: *const std.ArrayList(Building)) void {
    @memset(&powerGrid, false);
    @memset(&waterGrid, false);
    for (buildings.items) |b| {
        if (b.service == .power_plant) {
            // Simple radius spread
            const radius: i32 = 15;
            for (0..GRID_HEIGHT) |y| {
                for (0..GRID_WIDTH) |x| {
                    if (@abs(@as(i32, @intCast(x)) - @as(i32, @intCast(b.pos_x))) + @abs(@as(i32, @intCast(y)) - @as(i32, @intCast(b.pos_y))) < radius) {
                        powerGrid[idx(@intCast(x), @intCast(y))] = true;
                    }
                }
            }
        }
        if (b.service == .water_pump) {
            // Similar for water
            const radius: i32 = 12;
            for (0..GRID_HEIGHT) |y| {
                for (0..GRID_WIDTH) |x| {
                    if (@abs(@as(i32, @intCast(x)) - @as(i32, @intCast(b.pos_x))) + @abs(@as(i32, @intCast(y)) - @as(i32, @intCast(b.pos_y))) < radius) {
                        waterGrid[idx(@intCast(x), @intCast(y))] = true;
                    }
                }
            }
        }
    }
}

fn loadMockOSM(grid: []TileType) void {}

fn simulate(buildings: *std.ArrayList(Building), totalPop: *u32) void {
    totalPop.* = 0;
    for (buildings.items) |*b| {
        var growth: u32 = 0;
        if (b.zone == .residential) {
            const powered = powerGrid[idx(b.pos_x, b.pos_y)];
            const watered = waterGrid[idx(b.pos_x, b.pos_y)];
            growth = if (powered and watered) 20 else 5;
        } else {
            growth = 8;
        }
        b.population = @min(b.population + growth, 1500);
        totalPop.* += b.population;
    }
}

// Save/Load updated for new fields (omitted full repeat for brevity - version bumped)
fn saveSlot(slot: u8, buildings: *const std.ArrayList(Building), grid: []const TileType) !void { ... } // Keep existing + add service field
fn loadCity(...) !void { ... }

pub fn main() !void {
    rl.initWindow(1280, 720, "RealCity Builder");
    defer rl.closeWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var buildings = std.ArrayList(Building).init(allocator);
    defer buildings.deinit();

    var grid = try allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer allocator.free(grid);
    @memset(grid, .grass);

    var totalPop: u32 = 0;

    while (!rl.windowShouldClose()) {
        timeOfDay = @mod(timeOfDay + 0.001, 1.0);

        // Input for placement (simplified)
        if (rl.isMouseButtonPressed(.mouse_left_button)) {
            const mx = @as(u32, @intFromFloat(rl.getMouseX() / TILE_SIZE));
            const my = @as(u32, @intFromFloat(rl.getMouseY() / TILE_SIZE));
            if (mx < GRID_WIDTH and my < GRID_HEIGHT) {
                if (currentService != .none) {
                    try buildings.append(.{
                        .name = "Service Bldg",
                        .pos_x = mx, .pos_y = my,
                        .size_x = 2, .size_y = 2,
                        .population = 0,
                        .cost = 5000,
                        .zone = .none,
                        .service = currentService,
                    });
                    funds -= 5000;
                } else {
                    // Regular zone/building placement
                }
            }
        }

        updateGrids(grid, &buildings);
        simulate(&buildings, &totalPop);

        const skyColor = rl.Color{ .r = @intFromFloat(100 + 155 * @sin(timeOfDay * std.math.pi * 2)), .g = 150, .b = 255, .a = 255 };
        rl.clearBackground(skyColor);

        // Render grid (simplified)
        for (0..GRID_HEIGHT) |y| {
            for (0..GRID_WIDTH) |x| {
                const color = if (powerGrid[idx(@intCast(x), @intCast(y))]) rl.Color.blue else rl.Color.gray;
                rl.drawRectangle(@intCast(x) * @as(i32, @intFromFloat(TILE_SIZE)), @intCast(y) * @as(i32, @intFromFloat(TILE_SIZE)), @as(i32, @intFromFloat(TILE_SIZE)), @as(i32, @intFromFloat(TILE_SIZE)), color);
            }
        }

        // Buildings render stub
        rl.drawText(rl.textFormat("Funds: {d} | Pop: {d} | Time: {d:.1}", .{funds, totalPop, timeOfDay}), 10, 10, 20, rl.Color.white);
        rl.endDrawing();
    }
}
