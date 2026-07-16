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

const Blueprint = struct {
    name: []const u8,
    size_x: u32,
    size_y: u32,
    cost: u32,
};

const GRID_WIDTH: usize = 120;
const GRID_HEIGHT: usize = 90;
const TILE_SIZE: f32 = 18.0;

fn loadMockOSM(grid: []TileType) void { std.debug.print("[OSM] Loaded.\n", .{}); }
fn getMockWeather() []const u8 { return "Clear 68°F"; }

fn simulate(buildings: *std.ArrayList(Building), totalPop: *u32) void {
    totalPop.* = 0;
    for (buildings.items) |*b| {
        b.population = @min(b.population + (b.population / 20) + 3, 800);
        totalPop.* += b.population;
    }
}

// Simple save/load blueprints (JSON-like for now)
fn saveBlueprints(buildings: *std.ArrayList(Building)) !void {
    // Future: write to file with std.json
    std.debug.print("[Save] {d} buildings saved (stub).\n", .{buildings.items.len});
}

pub fn main() !void {
    const screenWidth = 1280; const screenHeight = 720;
    rl.initWindow(screenWidth, screenHeight, "RealCity Builder");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var camera = rl.Camera2D{ .target = .{.x = 1000, .y = 800}, .offset = .{.x = @as(f32,screenWidth)/2, .y = @as(f32,screenHeight)/2}, .rotation=0, .zoom=0.7 };

    var grid = try std.heap.page_allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer std.heap.page_allocator.free(grid); @memset(grid, .grass);
    loadMockOSM(grid);

    // Generate map
    for (0..GRID_WIDTH) |x| { grid[40*GRID_WIDTH+x]=.road; grid[65*GRID_WIDTH+x]=.road; }
    for (0..GRID_HEIGHT) |y| { grid[y*GRID_WIDTH+50]=.road; grid[y*GRID_WIDTH+75]=.road; }
    for (15..40) |y| for (85..110) |x| grid[y*GRID_WIDTH+x] = .water;

    var buildings = std.ArrayList(Building).init(std.heap.page_allocator);
    defer buildings.deinit();

    const blueprints = [_]Blueprint{
        .{.name="House", .size_x=3,.size_y=3,.cost=4500},
        .{.name="Shop", .size_x=4,.size_y=3,.cost=12000},
        .{.name="Park", .size_x=6,.size_y=5,.cost=8000},
    };
    var selectedBP: usize = 0;
    var totalPopulation: u32 = 0;
    var frame: u32 = 0;
    const weather = getMockWeather();

    while (!rl.windowShouldClose()) {
        frame += 1;

        if (rl.isKeyPressed(.key_one)) selectedBP = 0;
        if (rl.isKeyPressed(.key_two)) selectedBP = 1;
        if (rl.isKeyPressed(.key_three)) selectedBP = 2;
        if (rl.isKeyPressed(.key_s)) try saveBlueprints(&buildings);

        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            const wp = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            const gx = @as(u32, @intFromFloat(wp.x / TILE_SIZE));
            const gy = @as(u32, @intFromFloat(wp.y / TILE_SIZE));
            const bp = blueprints[selectedBP];
            if (gx + bp.size_x <= GRID_WIDTH and gy + bp.size_y <= GRID_HEIGHT) {
                try buildings.append(.{.name=bp.name, .pos_x=gx, .pos_y=gy, .size_x=bp.size_x, .size_y=bp.size_y, .population=40, .cost=bp.cost});
                for (0..bp.size_y) |dy| for (0..bp.size_x) |dx| {
                    const idx = (gy+dy)*GRID_WIDTH + (gx+dx); if (idx < grid.len) grid[idx] = .building;
                }
            }
        }

        if (rl.isKeyDown(.key_d) or rl.isKeyDown(.key_right)) camera.target.x += 10;
        if (rl.isKeyDown(.key_a) or rl.isKeyDown(.key_left)) camera.target.x -= 10;
        if (rl.isKeyDown(.key_s) or rl.isKeyDown(.key_down)) camera.target.y += 10;
        if (rl.isKeyDown(.key_w) or rl.isKeyDown(.key_up)) camera.target.y -= 10;

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mw = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            camera.target = mw;
            camera.zoom = std.math.clamp(camera.zoom + wheel*0.1, 0.15, 6.0);
        }

        if (frame % 25 == 0) simulate(&buildings, &totalPopulation);

        rl.beginDrawing(); defer rl.endDrawing();
        rl.clearBackground(.{.r=10,.g=20,.b=30,.a=255});

        rl.beginMode2D(camera);
        for (0..GRID_HEIGHT) |y| for (0..GRID_WIDTH) |x| {
            const t = grid[y*GRID_WIDTH + x];
            const r = rl.Rectangle{.x=@floatFromInt(x)*TILE_SIZE, .y=@floatFromInt(y)*TILE_SIZE, .width=TILE_SIZE, .height=TILE_SIZE};
            switch(t) {
                .grass => rl.drawRectangleRec(r, .{.r=46,.g=139,.b=87,.a=255}),
                .road => rl.drawRectangleRec(r, rl.Color.dark_gray),
                .water => rl.drawRectangleRec(r, .{.r=25,.g=80,.b=180,.a=255}),
                .building => rl.drawRectangleRec(r, .{.r=180,.g=100,.b=50,.a=255}),
            }
        };
        for (buildings.items) |b| {
            const r = rl.Rectangle{.x=@as(f32,@floatFromInt(b.pos_x))*TILE_SIZE, .y=@as(f32,@floatFromInt(b.pos_y))*TILE_SIZE, .width=@as(f32,@floatFromInt(b.size_x))*TILE_SIZE, .height=@as(f32,@floatFromInt(b.size_y))*TILE_SIZE};
            rl.drawRectangleRec(r, rl.Color{ .r=220, .g=60, .b=60, .a=220 });
            rl.drawText(b.name, @intFromFloat(r.x+6), @intFromFloat(r.y+6), 14, rl.Color.white);
        }
        rl.endMode2D();

        rl.drawText(rl.textFormat("Pop: {d} | {s} | BP: {s} (1-3) | S: Save", .{totalPopulation, weather, blueprints[selectedBP].name}), 12, 12, 20, rl.Color.lime);
        rl.drawText("Drag mouse + wheel zoom | Simulation active", 12, 45, 18, rl.Color.white);
        rl.drawFPS(1150, 12);
    }
}
