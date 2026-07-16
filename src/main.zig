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

const GRID_WIDTH: usize = 100;
const GRID_HEIGHT: usize = 80;
const TILE_SIZE: f32 = 20.0;

// Stub for OSM loader
fn loadMockOSM(grid: []TileType) void {
    // In future: parse real OSM XML/JSON for roads, water, buildings
    std.debug.print("[OSM] Mock real map data loaded.\n", .{});
}

// Stub for weather
fn getMockWeather() []const u8 {
    // Future: HTTP call to OpenWeatherMap or similar
    return "Sunny, 72°F";
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
        .zoom = 1.0,
    };

    var grid = try std.heap.page_allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer std.heap.page_allocator.free(grid);
    @memset(grid, .grass);

    loadMockOSM(grid);

    // Mock OSM-style map
    for (0..GRID_WIDTH) |x| {
        grid[35 * GRID_WIDTH + x] = .road;
        grid[55 * GRID_WIDTH + x] = .road;
    }
    for (0..GRID_HEIGHT) |y| {
        grid[y * GRID_WIDTH + 40] = .road;
        grid[y * GRID_WIDTH + 60] = .road;
    }
    for (10..30) |y| {
        for (70..90) |x| grid[y * GRID_WIDTH + x] = .water;
    }

    var buildings = std.ArrayList(Building).init(std.heap.page_allocator);
    defer buildings.deinit();

    const weather = getMockWeather();
    std.debug.print("=== RealCity Builder Zig + Raylib ===\nWeather: {s}\n", .{weather});

    while (!rl.windowShouldClose()) {
        // Update (camera, input, etc. same as before)
        if (rl.isMouseButtonDown(.mouse_button_left)) {
            const worldPos = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            const gridX = @as(u32, @intFromFloat(worldPos.x / TILE_SIZE));
            const gridY = @as(u32, @intFromFloat(worldPos.y / TILE_SIZE));
            if (gridX < GRID_WIDTH and gridY < GRID_HEIGHT) {
                try buildings.append(.{
                    .name = "Residential",
                    .pos_x = gridX,
                    .pos_y = gridY,
                    .size_x = 3,
                    .size_y = 3,
                    .population = 120,
                    .cost = 5000,
                });
                const idx = gridY * GRID_WIDTH + gridX;
                if (idx < grid.len) grid[idx] = .building;
            }
        }

        if (rl.isKeyDown(.key_right) or rl.isKeyDown(.key_d)) camera.target.x += 10;
        if (rl.isKeyDown(.key_left) or rl.isKeyDown(.key_a)) camera.target.x -= 10;
        if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_s)) camera.target.y += 10;
        if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_w)) camera.target.y -= 10;

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mouseWorldPos = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            camera.target = mouseWorldPos;
            camera.zoom += wheel * 0.1;
            if (camera.zoom < 0.2) camera.zoom = 0.2;
            if (camera.zoom > 5.0) camera.zoom = 5.0;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color{ .r = 20, .g = 20, .b = 30, .a = 255 });

        rl.beginMode2D(camera);

        for (0..GRID_HEIGHT) |y| {
            for (0..GRID_WIDTH) |x| {
                const tile = grid[y * GRID_WIDTH + x];
                const rect = rl.Rectangle{
                    .x = @as(f32, @floatFromInt(x)) * TILE_SIZE,
                    .y = @as(f32, @floatFromInt(y)) * TILE_SIZE,
                    .width = TILE_SIZE,
                    .height = TILE_SIZE,
                };
                switch (tile) {
                    .grass => rl.drawRectangleRec(rect, rl.Color{ .r = 34, .g = 139, .b = 34, .a = 255 }),
                    .road => rl.drawRectangleRec(rect, rl.Color{ .r = 80, .g = 80, .b = 80, .a = 255 }),
                    .water => rl.drawRectangleRec(rect, rl.Color{ .r = 30, .g = 100, .b = 200, .a = 255 }),
                    .building => rl.drawRectangleRec(rect, rl.Color{ .r = 139, .g = 69, .b = 19, .a = 255 }),
                }
            }
        }

        for (buildings.items) |b| {
            const rect = rl.Rectangle{
                .x = @as(f32, @floatFromInt(b.pos_x)) * TILE_SIZE,
                .y = @as(f32, @floatFromInt(b.pos_y)) * TILE_SIZE,
                .width = @as(f32, @floatFromInt(b.size_x)) * TILE_SIZE,
                .height = @as(f32, @floatFromInt(b.size_y)) * TILE_SIZE,
            };
            rl.drawRectangleRec(rect, rl.Color{ .r = 200, .g = 50, .b = 50, .a = 200 });
            rl.drawText(b.name, @intFromFloat(rect.x + 5), @intFromFloat(rect.y + 5), 10, rl.Color.white);
        }

        rl.endMode2D();

        rl.drawText("RealCity Builder | Click to place | WASD/Mouse pan | Wheel zoom | Weather stub active", 10, 10, 20, rl.Color.white);
        rl.drawText(weather, 10, 40, 20, rl.Color.yellow);
        rl.drawFPS(10, 70);
    }
}
