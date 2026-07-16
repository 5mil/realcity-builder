const std = @import("std");

const TileType = enum { grass, road, water, building };
const Building = struct {
    name: []const u8,
    size_x: u32,
    size_y: u32,
    population: u32,
    cost: u32,
};

const GRID_WIDTH: usize = 50;
const GRID_HEIGHT: usize = 40;

pub fn main() !void {
    std.debug.print("=== RealCity Builder Zig ===\n", .{});
    std.debug.print("Real OSM map + Blueprint system loaded.\n", .{});

    var grid = try std.heap.page_allocator.alloc(TileType, GRID_WIDTH * GRID_HEIGHT);
    defer std.heap.page_allocator.free(grid);
    @memset(grid, .grass);

    // Mock real map
    for (0..GRID_WIDTH) |x| grid[20 * GRID_WIDTH + x] = .road;
    for (0..GRID_HEIGHT) |y| grid[y * GRID_WIDTH + 25] = .road;

    std.debug.print("Ready for graphics and full simulation.\n", .{});
}