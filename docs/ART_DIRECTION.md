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

## Phase 1 implementation: Old Stone Crypt

The runtime kit is generated in Godot, with no external asset dependencies. `stone_theme.gd` creates original 128x128 nearest-filtered stone textures and shared materials; `dungeon_visual_builder.gd` batches the existing 3m cells into 8x8-cell chunks. Floor/ceiling/wall dimensions and physics remain unchanged. Wall base/crown trim, narrow corridor entrance lintels and jambs, wall pilasters, torch sconces and decorative route stair plaques are render-only. Stairs are shallow visual markers, not physical stair geometry: the existing E transfer remains authoritative. Four nearest torch lights per viewed floor use a small pool of non-shadow-casting warm lights with flicker. Distance fog and a softer player light establish atmosphere. The original primitive render path remains available using `-- --debug-geometry`. Dedicated/headless generation does not build art unless explicitly requested by a test. A graphical playtest is necessary to tune brightness and assess actual performance; this is not final art.

Future Blender kit dimensions: floor/ceiling 3 x 0.3 x 3m; wall 3 x 3 x 0.2m (width, height, depth); doorway trim within the 3m cell, full walkable clearance; sconce wall anchor at 1.7m; creature and weapon scenes remain next. Replace the generated meshes through the visual builder, not collision generation.

## Interface art

See [UI_ART_DIRECTION.md](UI_ART_DIRECTION.md) for the Expedition Journal palette, reusable parchment/leather components, item-icon conventions, roadmap and deferred audio backlog. The first UI pass generates paper textures in Godot, skins menus and HUD, and keeps game state and controls unchanged. Inventory and talent windows inherit the theme; their structural redesign and item icons are deferred.

## Compact dungeon layout

Keep 3m navigation tiles, but use small 2×2 to 3×3 rooms, 3×3 entrance/exit and 5×5 boss chambers. Straight connecting cells have thick masonry sides narrowing their physical width to 1.2 or 1.9 metres; corners stay open. Render the extra wall blocks using the same dimensions as collision. The map shows the narrow cross-section, and team collision makes single-file movement meaningful. Avoid obstructing entrance/stair landings. No new monster collision or traversal rules in this pass.
