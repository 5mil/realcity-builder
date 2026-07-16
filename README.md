# RealCity Builder

Zig + Raylib 2D city builder inspired by SimCity / Cities: Skylines.

## Current Features
- Tile grid (160x110) with roads, zones, buildings
- Day/Night cycle with dynamic sky
- Power & Water grids + coverage simulation
- Service buildings (police, fire, hospital, school, plants)
- Citizen happiness, pollution, density levels
- Taxes & basic budget
- Milestones/unlocks
- Roads & basic traffic
- Public transport stubs
- Resource chains
- Disasters (fire/flood) with response
- Full save slots (multiple, binary, versioned)

## Controls
- Left click: Place (depends on mode)
- P: Power plant mode
- W: Water pump
- R: Road
- More hotkeys in code

## Build (Optimized)
```bash
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux   # Linux
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows # Windows .exe
```

Executables in `zig-out/bin/`.

## Roadmap Status
~80% of 20-step plan complete. Polish ongoing.

Contributions welcome!