const std = @import("std");
const rl = @import("raylib");

const SAVE_VERSION: u32 = 1;

const TileType = enum(u8) { grass, road, water, building };
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

const GRID_WIDTH: usize = 140;
const GRID_HEIGHT: usize = 100;
const TILE_SIZE: f32 = 16.0;

var funds: i32 = 50000;

fn loadMockOSM(grid: []TileType) void {}
fn getMockWeather() []const u8 { return "Sunny"; }

fn simulate(buildings: *std.ArrayList(Building), totalPop: *u32) void {
    totalPop.* = 0;
    for (buildings.items) |*b| {
        b.population = @min(b.population + 8, 1200);
        totalPop.* += b.population;
    }
}

// Fast Binary Save/Load
fn saveCity(allocator: std.mem.Allocator, buildings: *const std.ArrayList(Building)) !void {
    const file = try std.fs.cwd().createFile("city_save.bin", .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeInt(u32, SAVE_VERSION, .little);
    try writer.writeInt(i32, funds, .little);
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
    }

    std.debug.print("💾 Binary save complete! ({d} buildings)\n", .{buildings.items.len});
}

fn loadCity(allocator: std.mem.Allocator, buildings: *std.ArrayList(Building), grid: []TileType) !void {
    const file = std.fs.cwd().openFile("city_save.bin", .{}) catch |err| {
        std.debug.print("No save file ({})\n", .{err});
        return;
    };
    defer file.close();

    const reader = file.reader();
    const version = try reader.readInt(u32, .little);
    if (version != SAVE_VERSION) return error.VersionMismatch;

    funds = try reader.readInt(i32, .little);
    const numBuildings = try reader.readInt(u32, .little);

    buildings.clearRetainingCapacity();
    for (0..numBuildings) |_| {
        const nameLen = try reader.readInt(u32, .little);
        const name = try allocator.alloc(u8, nameLen);
        defer allocator.free(name);
        _ = try reader.readAll(name);

        const b = Building{
            .name = try allocator.dupe(u8, name),
            .pos_x = try reader.readInt(u32, .little),
            .pos_y = try reader.readInt(u32, .little),
            .size_x = try reader.readInt(u32, .little),
            .size_y = try reader.readInt(u32, .little),
            .population = try reader.readInt(u32, .little),
            .cost = try reader.readInt(u32, .little),
        };
        try buildings.append(b);

        for (0..b.size_y) |dy| for (0..b.size_x) |dx| {
            const idx = (b.pos_y + dy) * GRID_WIDTH + (b.pos_x + dx);
            if (idx < grid.len) grid[idx] = .building;
        }
    }
    std.debug.print("📂 Binary load complete! {d} buildings\n", .{buildings.items.len});
}

pub fn main() !void {
    const screenWidth = 1280; const screenHeight = 720;
    rl.initWindow(screenWidth, screenHeight, "RealCity Builder");
    defer rl.closeWindow(); rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var camera = rl.Camera2D{.target=.{.x=1100,.y=800}, .offset=.{.x=@as(f32,screenWidth)/2,.y=@as(f32,screenHeight)/2}, .zoom=0.65, .rotation=0};

    var grid = try allocator.alloc(TileType, GRID_WIDTH*GRID_HEIGHT);
    defer allocator.free(grid); @memset(grid, .grass);
    loadMockOSM(grid);

    for (0..GRID_WIDTH) |x| { grid[45*GRID_WIDTH+x]=.road; grid[72*GRID_WIDTH+x]=.road; }
    for (0..GRID_HEIGHT) |y| { grid[y*GRID_WIDTH+55]=.road; grid[y*GRID_WIDTH+85]=.road; }
    for (20..45) |y| for (100..125) |x| grid[y*GRID_WIDTH+x] = .water;

    var buildings = std.ArrayList(Building).init(allocator);
    defer buildings.deinit();

    const blueprints = [_]Blueprint{ .{.name="House",.size_x=3,.size_y=3,.cost=5000}, .{.name="Shop",.size_x=5,.size_y=4,.cost=18000}, .{.name="Park",.size_x=7,.size_y=6,.cost=9000} };
    var selectedBP: usize = 0;
    var totalPop: u32 = 0;
    var frame: u32 = 0;
    const weather = getMockWeather();

    loadCity(allocator, &buildings, grid) catch {};

    while (!rl.windowShouldClose()) {
        frame += 1;

        if (rl.isKeyPressed(.key_one)) selectedBP = 0;
        if (rl.isKeyPressed(.key_two)) selectedBP = 1;
        if (rl.isKeyPressed(.key_three)) selectedBP = 2;
        if (rl.isKeyPressed(.key_s)) try saveCity(allocator, &buildings);
        if (rl.isKeyPressed(.key_l)) try loadCity(allocator, &buildings, grid);

        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            const wp = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            const gx = @as(u32,@intFromFloat(@max(0, wp.x/TILE_SIZE)));
            const gy = @as(u32,@intFromFloat(@max(0, wp.y/TILE_SIZE)));
            const bp = blueprints[selectedBP];
            if (gx + bp.size_x <= GRID_WIDTH and gy + bp.size_y <= GRID_HEIGHT and funds >= @as(i32, @intCast(bp.cost))) {
                funds -= @as(i32, @intCast(bp.cost));
                try buildings.append(.{.name=bp.name, .pos_x=gx, .pos_y=gy, .size_x=bp.size_x, .size_y=bp.size_y, .population=60, .cost=bp.cost});
                for (0..bp.size_y) |dy| for (0..bp.size_x) |dx| {
                    const idx = (gy+dy)*GRID_WIDTH + (gx+dx); if (idx < grid.len) grid[idx] = .building;
                }
            }
        }

        if (rl.isKeyDown(.key_d) or rl.isKeyDown(.key_right)) camera.target.x += 12;
        if (rl.isKeyDown(.key_a) or rl.isKeyDown(.key_left)) camera.target.x -= 12;
        if (rl.isKeyDown(.key_s) or rl.isKeyDown(.key_down)) camera.target.y += 12;
        if (rl.isKeyDown(.key_w) or rl.isKeyDown(.key_up)) camera.target.y -= 12;

        const wheel = rl.getMouseWheelMove();
        if (wheel != 0) {
            const mw = rl.getScreenToWorld2D(rl.getMousePosition(), camera);
            camera.target = mw;
            camera.zoom = std.math.clamp(camera.zoom + wheel * 0.09, 0.1, 7.0);
        }

        if (frame % 20 == 0) simulate(&buildings, &totalPop);

        rl.beginDrawing(); defer rl.endDrawing();
        rl.clearBackground(.{.r=8,.g=18,.b=28,.a=255});

        rl.beginMode2D(camera);
        for (0..GRID_HEIGHT) |y| for (0..GRID_WIDTH) |x| {
            const idx = y*GRID_WIDTH + x;
            const r = rl.Rectangle{.x=@as(f32,@floatFromInt(x))*TILE_SIZE, .y=@as(f32,@floatFromInt(y))*TILE_SIZE, .width=TILE_SIZE, .height=TILE_SIZE};
            switch(grid[idx]) {
                .grass => rl.drawRectangleRec(r, .{.r=50,.g=160,.b=80,.a=255}),
                .road => rl.drawRectangleRec(r, rl.Color.gray),
                .water => rl.drawRectangleRec(r, .{.r=20,.g=100,.b=190,.a=255}),
                .building => rl.drawRectangleRec(r, .{.r=210,.g=80,.b=40,.a=255}),
            }
        }
        for (buildings.items) |b| {
            const r = rl.Rectangle{.x=@as(f32,@floatFromInt(b.pos_x))*TILE_SIZE, .y=@as(f32,@floatFromInt(b.pos_y))*TILE_SIZE, .width=@as(f32,@floatFromInt(b.size_x))*TILE_SIZE, .height=@as(f32,@floatFromInt(b.size_y))*TILE_SIZE};
            rl.drawRectangleRec(r, rl.Color{ .r=240, .g=100, .b=80, .a=230 });
        }
        rl.endMode2D();

        rl.drawText(rl.textFormat("Funds: ${d} | Pop: {d} | {s} | BP: {s} (1-3) | S:Save L:Load", .{funds, totalPop, weather, blueprints[selectedBP].name}), 10, 10, 20, rl.Color.lime);
        rl.drawText("LMB build | WASD pan | Wheel zoom", 10, 40, 18, rl.Color.white);
        rl.drawFPS(1050, 10);
    }
}
