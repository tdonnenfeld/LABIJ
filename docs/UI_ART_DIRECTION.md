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

## Satchel implementation and icon specification

The inventory now opens as an illustrated parchment spread. The left page contains three selectable equipment cards and a fixed 4×3 carried-item grid. W/S/A marks mean weapon/shield/armour; tooltip and detail text identify the exact item. The right page displays a larger illustration, type, equipped/enchanted/unique status, actual catalog stats and contextual actions. Equipped items cannot be dropped; selecting another compatible item replaces the current equipment. No unequip action is added. All requests still use authoritative inventory indices. The UI is centered in the logical 960×540 viewport and does not pause simulation.

Original 64×64 transparent SVG artwork lives in `art/ui/icons/items/`. `item_icons.gd` is the presentation registry and strips affix suffixes for icon lookup. The 25 catalog IDs each have an icon; Jewel (objective only) and unknown-item fallback are additional assets. Artwork uses dark 2px ink contour, warm metal/wood/leather and restrained facet/shading details. No external art or fonts required.

| Family | Visual treatment |
| --- | --- |
| Sword, dagger, axe, spear | Distinct diagonal silhouette, engraved steel and wrapped wood; venom dagger green accent |
| Bow, longbow | Bent wood, taut pale string, arrow; longer profile for longbow |
| Staff, Ember Staff, Oracle's Ember | Wooden shaft, bronze head, muted green/orange/gold gem |
| Wooden, iron and Warden shields | Broad shield silhouette, rivets, boss; Warden adds a gold diamond |
| Leather, mail, ward mail | Tunic silhouette, belt, seams or link pattern; ward mail adds a violet rune |
| Potion and noise stone | Red liquid in corked glass, faceted grey rock |
| Scrolls | Rolled parchment with wax seal; fire red flame, ice blue snowflake, air violet lightning, earth olive stone; advanced spells add a gold crest |
| Jewel | Angular pale-green faceted gem; not a carried inventory item |
| Enchanted variants | Same base icon; explicit ENCHANTED label and catalog item title/stat changes |

Next: grimoire talent layout and actual 3D item/world pickup models. No external source licenses are required for these original SVGs. Art is provisional pending in-game readability review.

## Spatial satchel revision

Replace the 12 equal slots with 8×5 leather cells. Equipment cards remain outside the grid. Use fixed footprints, quantity counters and drag/drop, Shift-drag to split stacks. Potions/stone/scrolls occupy 1×1; dagger/arrows 1×2; swords/staves 1×3; spears 1×4; shields 2×2; axes/bows/armour 2×3. Stack counts are legible over icons, and selected details show size and quantity. No item weight. The backpack uses server-provided placement and quantity state. Rotation and auto-sort are deferred.

## Backpack expansion

Rotation and compacting are explicit controls in the satchel. A four-dose leather belt appears above the action bar with keys 4–7; use parchment inventory buttons to load/return potions. Companion exchange is a separate parchment window opened with J: clear offered quantities and explicit confirmation status. Current trades exchange one stack per side or gifts. Ground loot uses original procedural low-poly silhouettes (blade, axe, bow, staff, shield, armour, bottle, scroll, stone, arrows) with material colours from the icon palette; no collision added. Meshes are presentation only and remain replaceable with authored glTF assets. Visual and network playtesting still required.

## Paper doll and placement preview

Three-column parchment spread: backpack on left, original ink character silhouette in centre with nine labelled leather slots, inspection on right. The drop preview uses exactly the same inventory operation on a copy of the current server state, including stacks, rotations and equipped-to-grid moves. Green for valid, red for blocked, gold for merge; equipment targets highlight when valid. Right-click gear to equip/unequip. Head, chest, gloves, boots, amulet and two rings are functional slots. The character is a static illustrated silhouette with equipped item icons, not a 3D outfit preview.

## Expedition menu

Esc opens a modal parchment journal overlay with Keybinds, Sound, Lobby and Exit tabs. Resume remains visible. The room continues behind the dimmed overlay: never imply multiplayer pause or safety. Use local persisted settings, confirmation for destructive lobby and exit actions, and display the current party roster without changing generation size. Host-only join lock and removal are available before claiming the Jewel.

## Animated world assets

Use `art/models/characters/*.gltf` for original segmented low-poly characters, regenerated by `tools/generate_characters.mjs`. `asset_registry.gd` caches imported scenes and low-resolution grain materials; `actor_rig.gd` animates articulated parts from movement and combat state. Keep actor collision bodies independent. First-person hands and companions reuse `loot_models.gd`; no collision geometry is added to presentation assets. Floor decoration is batched, with muted floor-specific material tints. Keep motion effects adjustable and impact bursts bounded. The generated assets establish proportions and silhouettes for later artist-authored Blender/glTF replacements.
