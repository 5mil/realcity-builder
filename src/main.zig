const std = @import("std");
const rl = @import("raylib");

const TileType = enum { grass, road, water, building };
const Building = struct {
    name: []const u8,
    pos_x: u32,
    pos_y: u32,
    size_x: u32,
    size_y: u32,
    population: u32,
    cost: u32,
};

// Blueprint system
const Blueprint = struct {
    name: []const u8,
    size_x: u32,
    size_y: u32,
    cost: u32,
};

const GRID_WIDTH: usize = 100;
const GRID_HEIGHT: usize = 80;
const TILE_SIZE: f32 = 20.0;

fn loadMockOSM(grid: []TileType) void {
    std.debug.print("[OSM] Mock real map data loaded.\n", .{});
}

fn getMockWeather() []const u8 {
    return "Sunny, 72°F - Wind: 8 mph";
}

// Simple simulation step
fn simulate(buildings: *std.ArrayList(Building), totalPop: *u32) void {
    totalPop.* = 0;
    for (buildings.items) |*b| {
        b.population = @min(b.population + 5, 500); // Growth
        totalPop.* += b.population;
    }
}

pub fn main() !void {
    const screenWidth = 1280;
    const screenHeight = 720;

    rl.initWindow(screenWidth, screenHeight, "RealCity Builder - Zig + Raylib");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var camera = rl.Camera2D{
        .target = rl.Vector2{ .x = @as(f32, @floatFromInt(GRID_WIDTH)) * TILE_SIZE / 2.0, .y = @as(f32, @floatFromInt(GRID_HEIGHT)) * TILE_SIZE / 2.0 },
        .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(screenWidth)) / 2.0, .y = @as(f32, @floatFromInt(screenHeight)) / 2.0 },
        .rotation = 0.0,
        .zoom = 0.8,
    };

    var grid = try std.heap.page_allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer std.heap.page_allocator.free(grid);
    @memset(grid, .grass);
    loadMockOSM(grid);

    // Roads + water
    for (0..GRID_WIDTH) |x| {
        grid[35 * GRID_WIDTH + x] = .road;
        grid[55 * GRID_WIDTH + x] = .road;
    }
    for (0..GRID_HEIGHT) |y| {
        grid[y * GRID_WIDTH + 40] = .road;
        grid[y * GRID_WIDTH + 60] = .road;
    }
    for (10..30) |y| for (70..90) |x| grid[y * GRID_WIDTH + x] = .water;

    var buildings = std.ArrayList(Building).init(std.heap.page_allocator);
    defer buildings.deinit();

    var blueprints = [_]Blueprint{
        .{ .name = "House", .size_x = 2, .size_y = 2, .cost = 3000 },
        .{ .name = "Apartment", .size_x = 4, .size_y = 3, .cost = 15000 },
    };

    var totalPopulation: u32 = 0;
    var frame: u32 = 0;
    const weather = getMockWeather();

    std.debug.print("=== RealCity Builder - Simulation Active ===\n", .{});

    while (!rl.windowShouldClose()) {
        frame += 1;

        // Input & placement (select blueprint with 1/2 keys)
        var selectedBP: usize = 0;
        if (rl.isKeyPressed(.key_one)) selectedBP = 0;
        if (rl.isKeyPressed(.key_two)) selectedBP = 1;

        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            const worldPos = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            const gx = @as(u32, @intFromFloat(worldPos.x / TILE_SIZE));
            const gy = @as(u32, @intFromFloat(worldPos.y / TILE_SIZE));
            if (gx + blueprints[selectedBP].size_x <= GRID_WIDTH and gy + blueprints[selectedBP].size_y <= GRID_HEIGHT) {
                const bp = blueprints[selectedBP];
                try buildings.append(.{
                    .name = bp.name,
                    .pos_x = gx,
                    .pos_y = gy,
                    .size_x = bp.size_x,
                    .size_y = bp.size_y,
                    .population = 50,
                    .cost = bp.cost,
                });
                // Mark tiles
                for (0..bp.size_y) |dy| for (0..bp.size_x) |dx| {
                    const idx = (gy + dy) * GRID_WIDTH + (gx + dx);
                    if (idx < grid.len) grid[idx] = .building;
                }
            }
        }

        // Camera
        if (rl.isKeyDown(.key_right) or rl.isKeyDown(.key_d)) camera.target.x += 8;
        if (rl.isKeyDown(.key_left) or rl.isKeyDown(.key_a)) camera.target.x -= 8;
        if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_s)) camera.target.y += 8;
        if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_w)) camera.target.y -= 8;

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mouseWorld = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            camera.target = mouseWorld;
            camera.zoom += wheel * 0.08;
            camera.zoom = std.math.clamp(camera.zoom, 0.2, 5.0);
        }

        // Simulation (every 30 frames)
        if (frame % 30 == 0) {
            simulate(&buildings, &totalPopulation);
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color{ .r = 15, .g = 25, .b = 35, .a = 255 });

        rl.beginMode2D(camera);
        // Grid rendering (same)
        for (0..GRID_HEIGHT) |y| {
            for (0..GRID_WIDTH) |x| {
                const tile = grid[y * GRID_WIDTH + x];
                const rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x)) * TILE_SIZE, .y = @as(f32, @floatFromInt(y)) * TILE_SIZE, .width = TILE_SIZE, .height = TILE_SIZE };
                switch (tile) {
                    .grass => rl.drawRectangleRec(rect, rl.Color{ .r = 40, .g = 150, .b = 40, .a = 255 }),
                    .road => rl.drawRectangleRec(rect, rl.Color.dark_gray),
                    .water => rl.drawRectangleRec(rect, rl.Color{ .r = 20, .g = 90, .b = 180, .a = 255 }),
                    .building => rl.drawRectangleRec(rect, rl.Color{ .r = 160, .g = 82, .b = 45, .a = 255 }),
                }
            }
        }

        for (buildings.items) |b| {
            const rect = rl.Rectangle{
                .x = @as(f32,@floatFromInt(b.pos_x))*TILE_SIZE,
                .y = @as(f32,@floatFromInt(b.pos_y))*TILE_SIZE,
                .width = @as(f32,@floatFromInt(b.size_x))*TILE_SIZE,
                .height = @as(f32,@floatFromInt(b.size_y))*TILE_SIZE,
            };
            rl.drawRectangleLinesEx(rect, 3, rl.Color.yellow);
            rl.drawText(b.name, @intFromFloat(rect.x+4), @intFromFloat(rect.y+4), 12, rl.Color.white);
        }

        rl.endMode2D();

        // HUD
        rl.drawText(rl.textFormat("Population: {d} | Weather: {s}", .{ totalPopulation, weather }), 10, 10, 22, rl.Color.lime);
        rl.drawText("1: House | 2: Apartment | Click to build | Simulation running", 10, 40, 18, rl.Color.white);
        rl.drawFPS(10, 70);
    }
}
