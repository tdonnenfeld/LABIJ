# The Expedition Journal — UI art direction

## Identity

A worn expedition journal carried through an old stone crypt. Menus are aged parchment, grimoire leaves, annotations and ledger pages. Combat HUD is leather, dark wood and brass, with small restrained paper accents. Never cover the dungeon in oversized bright panels. Preserve status readability and exact numerical values. Avoid glossy modern gradients, neon, dense ornaments and faux handwriting for functional text.

## Palette

| Role | Colour |
| --- | --- |
| Parchment | #D5C19A |
| Aged paper | #B39A70 |
| Ink | #30271E |
| Leather | #49362B |
| Antique brass | #94784B |
| Health | #8C3935 |
| Mana | #526D88 |
| Stamina | #78804A |
| Poison | #617E52 |
| Rare magic | #79618C |
| Jewel | #DBBC69 |
| Dungeon | #1E211D |

Use colour plus labels/symbols for status; do not rely on hue alone. Menus: dark ink on paper; gameplay: light ink on dark plates. Keep text at least 12 logical pixels at the 960x540 baseline, with larger headlines. Use available serif system fonts for titles and Godot's readable default for gameplay text. No new font dependency for this pass.

## Reusable components

- Parchment page: original generated 96px paper texture, nine-slice edge, 10px content margin. Use for setup/results and future journal windows.
- Dark HUD plate: thin brass edge, opaque enough for readability, no large ornamental frames.
- Controls: weathered brown buttons with gold focus outline and distinct hover/pressed/disabled states.
- Resource bar: labelled exact value/max, dark trough, muted red/olive/blue fill.
- Sound gauge: segmented brass-framed meter retaining peak indicator.
- Action slots: 3 separate labelled panels, readable cooldown text.
- Map: paper scrap, brown explored cells, red player arrow, distinct route markers. Never reveal additional gameplay information.
- Log: dark expedition record with event colours. Party panel: compact companion lines with HP/floor/aggro preserved.
- Layout: respect 960x540 logical viewport; use containers and anchors, test 8-player HUD and long names. No gameplay changes or new inputs.

## Items and character pages — next pass

Icons 64x64 source, 32-40px displayed, transparent background, dark outline and simple material shading. Prioritize recognizable silhouette and type, not decoration. Starter weapons: sword, axe, dagger, bow, staff; shields, leather/chainmail, potion, noise stone, elemental scrolls and Jewel. Variants share silhouette but differ in accent or small emblem; label rarity/affix explicitly. Keep icon lookup separate from catalog and simulation. Prefer original authored SVG or pixel art, licensed packs only with provenance.

Inventory: satchel grid/list and selected-item parchment detail, equipped seals and clear drop/use actions. Talents: manuscript tabs and connected seals, available/learned/locked states discernible without colour alone. Result screen: expedition record, no resurrection. 3D loot and first-person item models are later independent work.

## Implementation sequence

1. Shared theme, menu page, framed HUD and map. Retain current inventory/talent interactions and reskin inherited controls.
2. Inventory item icons, details and equipment cards; talents as grimoire.
3. First-person weapon/shield and world loot models, then animated creatures.
4. Review readability, long names, eight-player party layout, resolution scaling and accessibility.

## Deferred audio backlog

- Equipment-dependent footsteps and clothing/chainmail layers.
- Inventory/consumable cues, sleeping creature breathing, elemental magic cues.
- Reverb and wall muffling, additional ambience loops, boss/expedition music.
- Persist audio settings, microphone gain calibration, echo cancellation.
