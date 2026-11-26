# LABIJ art direction

## Target

Native PC, dark fantasy, late-1990s low-poly atmosphere, strong silhouettes and readable combat. Use deliberately limited textures, rather than making every object visually noisy. Keep a clean HUD at native resolution. Compatibility is the baseline until an actual scene benchmark justifies Forward+.

## Vertical slice first

Build one representative dungeon room with stone walls, uneven floor, archway, torch, stairs and a few props. Add one complete Goblin, a sword/shield viewmodel, one loot pickup, one spell projectile and one readable attack telegraph. Test this in a real expedition with several monsters before scaling production.

## Asset pipeline

- Blender source files (meters, 1 unit = 1 meter, apply scale, origin at feet for creatures; front faces -Z after import into Godot).
- Export runtime meshes and animations as glTF binary (.glb); keep source files separate from runtime assets. Use a stable asset ID, scene wrapper and independently defined gameplay collision. Do not derive monster damage, reach or AI from art.
- Monster wrapper: visual root, animation player/tree, sockets for weapon and effects, label anchor; gameplay state drives idle, sleep, walk, windup, attack, recovery, hit and death. Keep telegraph timing authoritative.
- Dungeon kit: modular 3m floor/ceiling/wall, corner, door arch, stairs, columns and props. Use shared materials, atlases and seeded decorative variation; separate collision and walkable tiles. Batch static meshes per room/chunk when profiling indicates a bottleneck.
- Texture target: 64-256px per prop/creature or shared 512px atlas; nearest filtering, restrained palette, hand-painted or baked detail. Suggested initial triangles: 300-1500 for common monsters, 1000-3000 for bosses. These are starting budgets, not limits.
- Audio: replace synthesized cues with licensed or original WAV/OGG files via stable sound IDs. Record provenance and license for every external asset.
- Lighting: flickering torches and local lights; keep visibility of attacks and enemy facing. Test low internal resolution and optional vertex jitter/dithering as presentation-only settings, without affecting simulation.

## Milestones

1. Modular stone dungeon kit and first lighting pass.
2. Goblin rig, animations and first-person weapon/shield viewmodels.
3. Visual asset registry and replacement of capsules by scenes, retaining debug fallback.
4. Distinct silhouettes for remaining monsters, biome-specific materials and boss rooms.
5. Spell VFX, hit reactions, sound assets and final HUD icon set.
6. Profile CPU/GPU in a populated multiplayer scene and select rendering settings.

Asset sources can be original Blender work, commissioned art or compatible licensed packs. Verify asset licenses before committing; avoid importing copyrighted game assets. Procedural and AI-generated references can inform concept art, but actual game assets require usable meshes, textures and animations.
