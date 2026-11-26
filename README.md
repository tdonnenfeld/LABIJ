# LABIJ

**Labyrinths, Abysses & the Buried Immortal Jewel** (working expansion).

Descend. Loot. Return.

A first-person cooperative dungeon roguelike inspired by DCSS, with retro 3D visuals.

## Prototype

Godot 4.7.2 stable (recommended; also used in CI). Open project.godot and press F6 on main.tscn or F5. Select Solo, Host or Join. Use physical WASD (ZQSD on AZERTY), mouse and Escape to release the cursor.

Host listens on UDP 7777. Join using the host IP. For online play use a VPN or appropriate UDP forwarding.

Dedicated server:
```sh
godot --headless --path . -- --server
```

Four main floors, two rune branches and the Jewel Sanctuary are connected by explicit stair interactions. Approach a gold DOWN or blue UP marker and press E. Players travel independently; pursuing monsters within 3 m of both the player and stairs follow. Floors and monster positions persist for the session. Red capsules pursue and attack; orange indicates a wind-up. Left click swings the sword, hold right click to block frontal attacks. Health and stamina appear in the HUD; green crosshair indicates a successful hit. Dead players spectate a surviving teammate, or see defeat when no one survives. Restart the game for a new run. Monsters drop shared physical loot. Press F near an item to pick it up, I to open the 12-slot inventory, and select Equip / use or Drop. Each player starts with a sword, shield and healing potion. The game does not pause while inventory or skills is open. Press K to allocate XP and purchase talents outside combat. Eleven domains have independent XP wallets; successful hits, blocks, near-miss dodges and kills award usage XP. Assign learned active abilities to slots 1–3. Discover a random secret at the tablet on Dungeon 2 (T). Talent purchases are permanent. Kills grant XP to the killer and living teammates within 15 m on the same floor. Purchased talents grant passive effects and active abilities; earning XP alone does not improve stats. Identical inventory items retain separate equipped slots. No resurrection. PS1 shader and disk saves are future work. Remote movement is not predicted/interpolated. Multiplayer and visual testing are still required.

See docs/GAME_DESIGN.md and docs/ARCHITECTURE.md.

## Monster and talent expansion

Each floor has a different roster: fast cave rats, goblins, slow heavy ogres, skeleton archers with telegraphed aimed ranged hits, and armored iron guardians. All can follow stairs when close. K opens connected talent nodes with a details panel; scroll to see deeper tiers. New effects include bleed, stagger, armor penetration, perfect guard, cleave, riposte and temporary defensive abilities. Monsters still use placeholder geometry; archer attacks use physical projectiles.

## Elemental magic and sprinting

Hold Shift while moving to sprint at 155% speed (22 stamina/s, no regeneration while sprinting). Release Shift after exhaustion. K now includes Fire, Ice, Air and Earth trees; allocate XP, find and read spell scrolls and assign learned spells to 1–3. Spells use mana (blue bar), windup and cooldowns. Aim horizontally; projectiles collide with walls and targets. Fire burns, ice slows/freezes, air interrupts and earth staggers. Fire and ice consume opposing status effects for bonus damage. Skeleton archers and Hex Mages fire physical projectiles. Sprinting, spell casts and projectile simulation are authoritative.

## Expedition generation

Solo uses a random seed and party size one. Host selects expected party size before starting; dedicated server accepts `--party-size=4` after `--`. Clients receive the seed and size before spawning. Each floor has a finite population of randomly selected monsters at unique tiles away from entry and exit. No respawns or join-time scaling. Scrolls permanently teach spells outside combat if school mastery meets the requirement (25 lifetime XP for basic, 100 for advanced). Reading consumes the scroll only on success. Armour and a mana-regeneration staff are available as loot. No respec in the prototype.

## Threat and ranged combat

Monsters acquire the first visible player (nearest if several become visible in the same tick). Initial threat is 20. Actual damage and damage-over-time generate threat; a challenger must exceed current threat by 10% within 3m or 30% farther away. Dead/disconnected/off-floor players are removed from threat tables; nearby followers retain their target across stairs. Protector (Shields) increases generated direct damage threat by 50%. Bows use stamina and finite stackable arrows; Archery has its own XP tree. Poison blades, enchanted staves, runed mail and monster magic resistances are available. Cross-domain talents remain deferred.

## Branches, bosses and hazards

Dungeon 2 leads to the Iron Crypt; Dungeon 3 leads to the Ember Vault. Purple stairs use E, and return to the same entry. Both rune branches are required to unlock the sanctuary, but may be explored in either order. All floors are generated from the expedition seed. Each has a finite roster and a guaranteed boss at its end: the Crypt Warden uses a close-range area slam, the Ember Oracle a three-projectile volley. Bosses stay in their branch and scale health with party size; their guaranteed artefacts are the Aegis of the Crypt and Oracle's Ember. Ordinary monsters still follow stairs. Each floor contains visible, single-use spike/fire plates with 0.65s warning. Challenge (Shields) forces an aimed enemy to target you for 3s, matching highest threat; Fade (Dodging) halves your threat on the floor. Eligible weapon loot has a 12% enchantment roll (Precision, Haste or Venom). Enchantments are stable item IDs shared by server and clients. No respec or respawns.

## Complete expedition

Defeat the Crypt Warden and Ember Oracle to earn shared Iron and Ember runes. The sanctuary gate at the end of Dungeon 4 opens only with both runes. Defeat the Jewel Sentinel and press E at the Jewel marker to claim it. The Jewel is a separate shared objective: G drops it, and disconnect leaves it on the ground. Returning to the Dungeon 1 entrance with the Jewel and pressing E wins the expedition for the party. The death of any party member immediately ends the expedition in defeat. No resurrection or spectating continuation. New joins are disabled once the Jewel is claimed. The result screen returns clients to the menu; a dedicated server must be restarted for another run.

Claiming the Jewel wakes a pre-generated, finite reserve of hunters (one per two configured players, rounded up, on each main floor). They grant no loot or kill XP; normal action-based domain XP still applies. Remaining enemies gain pursuit range and movement speed in three stages, increasing every 45 seconds; hunters can sense the carrier on their floor. No monster respawns, including on Jewel handoff. The carrier does not need a free inventory slot.

## Party HUD and combat feedback

The shared party log records actual damage, blocked/parried hits, dodges, kills, status effects, kill and usage XP, loot drops/pickups/equipment, talents and objective milestones. L toggles the log; Esc releases the mouse for filters and scrolling. The party panel lists each member's floor, HP and aggro count, and the bottom action strip shows ability names/cooldowns. Floating combat text rises and fades over targets on the viewed floor; incoming damage and heals appear near the local crosshair. Damage-over-time messages aggregate at roughly one-second intervals. Events originate on the server and are sent reliably in batches; late joiners receive the recent 200-event history without replaying floating text. Player names are temporary numbered labels.

## Noise and enemy awareness

Hold Ctrl to quiet-walk at 45% normal speed. Footstep noise is based on actual movement: quiet 2.5, normal 6, sprint 12 nominal metres. Melee swings, bow shots, spells and explosions emit noise too. Noise travels along connected dungeon tiles, never directly through walls or between floors. Roughly 45% of ordinary enemies start asleep; awake idle enemies roam on occupied floors, pause between steps and investigate audible disturbances without acquiring aggro until they see a player or take damage. Sleeping enemies can detect players within 1.8 m or wake from sound/damage. Bosses and escape hunters stay awake; bosses do not roam. Silent Steps in Dodging reduces player noise by 30%. The HUD shows recent noise, aimed enemy health/status/awareness, current target and your threat relative to its current target. No respawns or changes to shared permadeath.

## Stealth and exploration

M toggles the local minimap. Only tiles observed from the player's current tile are revealed; exploration persists per floor during the expedition. U/D/B/S indicate discovered up/down/branch/surface routes. Teammates on explored tiles are marked in blue; enemy positions and unexplored rooms are not shown. Ctrl quiet-walk reduces sight detection; heavy armour increases footstep noise and some weapons have distinct attack noise. Stealth has six talents: Soft Step, Concealment, Ambush, Deep Cut, Misdirection and Shadow Step. Quiet movement near an unengaged enemy gives a one-time usage XP award per player/enemy; ambush XP is earned on eligible attacks. Ambush is a melee opening against enemies with no target or threat. H throws a consumable Noise Stone along the player's facing direction; stones travel up to 12m, stop at walls, and emit noise on landing without damage or threat. They are available as loot and can also be thrown via inventory. Noise values remain provisional.

## Character creation and peak noise meter

Before Solo, Host or Join, choose a name, species and background. Human is neutral; Dwarf has +15 HP, -8% movement and +20% Shields/Earth XP; Elf has -10 HP, +20% mana regen and +20% Ice/Air XP; Halfling has -10 HP, -20% noise and +20% Archery/Stealth XP. Backgrounds set starting gear, XP and training priorities (Adventurer, Vanguard, Scout, Arcanist). No class restrictions, respec or resurrection. All profiles are immutable during the run; the server validates incoming profile IDs before spawning. The noise meter shows a segmented current level and a thin peak marker: current decays at 8 units/s, peak holds 0.65s and falls at 2 units/s. Both values are authoritative and replicated.

## Native platform

LABIJ targets desktop clients and dedicated Linux servers using ENet. Browser integration is out of scope. Compatibility rendering remains the current default, with a future native renderer evaluation.

## Directional vision and positional audio

Awake enemies have forward vision arcs (120 degrees default, 150 ranged, 180 rats and bosses), with close-range detection within 1.25m regardless of facing. Sleeping detection remains 1.8m. Walls, stealth and noise still matter; existing threat targets remain tracked outside the cone. Enemies turn toward movement, attack preparation and audible disturbances. Backstab (Stealth, 50 XP after Ambush) adds 35% of base attack damage from the rear 90-degree sector on awake enemies not targeting the attacker. It can combine additively with Ambush. Backstab usage XP is awarded once per player/enemy. A small front marker identifies placeholder enemy facing.

Positional sound cues cover footsteps, weapons, spell casts, hits, blocks, waking, explosions and noise stones. Sounds are synthesized placeholder effects, not final recorded assets. They are sent only to nearby players on the same floor and checked against corridor propagation on playback. Sound cues do not create additional AI noise beyond the existing authoritative noise events. See docs/ART_DIRECTION.md for the asset pipeline.

## Proximity voice chat (experimental)

Choose Microphone off (default), Push to talk [V] or Open mic before joining/hosting. N toggles outgoing mute during play. Only focused gameplay with captured mouse transmits; menus, defeat and disconnect stop capture. A live microphone indicator shows voice noise. Audio is ephemeral: 16 kHz mono PCM in 20ms frames over ENet, relayed only to nearby same-floor teammates along connected corridors. No recordings, transcription or external voice service. ENet does not encrypt voice traffic; use trusted networks/servers. Headphones are recommended: no echo cancellation, gain calibration or advanced noise suppression yet.

The server measures RMS of the actual voice packets, applies a -48 dBFS gate and maps amplitude to a 2–18m hearing radius. Whispers investigate/wake enemies; loud voice (12m threshold) directly pulls unengaged ordinary enemies that can hear it. Engaged enemies retain their existing threat rules; bosses are excluded from direct sound pulls. Voice noise contributes to the peak meter and is not reduced by stealth, species or armour. Voice is available in solo too. The values are provisional and depend on microphone gain. The server rate-limits frames and derives source position from the actual player. Modified clients could still suppress or fake microphone input; this is cooperative gameplay, not anti-cheat.

## Stone dungeon art pass

The first environment theme uses original procedural low-resolution stone textures, modular wall trim, corridor frames, decorative stair plaques, warm flickering sconces and distance fog. Repeated architecture is batched by material and 8x8-cell chunk; no gameplay geometry, floor layouts, monsters, loot or routes changed. The torch light pool uses up to four nearby non-shadow-casting lights per visible floor. Use `godot --path . -- --debug-geometry` to restore the original primitive rendering. See `docs/ART_DIRECTION.md` for art dimensions and follow-up milestones.

## Recorded audio assets

Stone footsteps now use six CC0 Fantozzi recordings, enemy footsteps use four CC0 Kenney RPG Audio variants, and hit/block sounds use two Kenney Impact Sounds samples. Variants avoid immediate repetition, with presentation-only randomized pitch and volume. Quiet movement uses softer playback; sprinting uses louder, slightly lower-pitched playback. Existing authoritative noise radius, voice chat and enemy detection are unchanged. Other cues retain synthesized placeholders. Assets are committed, so no external download is needed at runtime. See `art/audio/CREDITS.md` for provenance.

## Expanded sound library

24 more CC0 sounds are bundled under `art/audio/`: melee swings, bow, magic, explosions, stone impacts, a second shield block, three creature wake cues, plus future inventory, doors, chainmail, cloth, potion, bite and UI assets. Current combat/wake events select the new samples; future assets are staged but not triggered yet. Variants avoid immediate repetition. Simulation and voice noise rules are unchanged. See `art/audio/CREDITS.md` for source paths and checksums. Dungeon ambience and torch/water loops remain to be acquired; no runtime asset downloads are required.

## Environmental sound

The client plays a quiet wind bed with faded edges, occasional spatial water drips and up to two nearest audible torch loops. Torch/drip selection is limited to the current floor and connected dungeon tiles. Environmental audio is cosmetic only: it does not create noise or alter enemy AI, combat, voice chat, or authoritative simulation. Separate Effects, Ambience and Voice playback sliders in the main menu adjust output only, not microphone sensitivity or AI loudness. Settings last for the current game process. Sources and licenses (including the CC BY 3.0 fire loop) are in `art/audio/CREDITS.md`. No external downloads needed. The short wind/drip excerpts are not a full authored dungeon ambience track; audio balance still needs playtesting.

## Expedition Journal UI

The setup menu and expedition result use parchment pages, and the combat HUD uses dark brass-framed plates with labelled HP/stamina/mana, separate ability slots, a parchment minimap and expedition log. Existing inventory and talent controls inherit the shared dark theme. No extra assets or fonts are required. See `docs/UI_ART_DIRECTION.md` for the palette, UI roadmap and deferred audio work. Final item icons and 3D models are not included in this pass.

## Illustrated satchel

The inventory [I] now has a parchment equipment spread, an 8×5 spatial backpack with illustrated items, clickable weapon/shield/armour cards, and selected-item stats with contextual actions. All catalog IDs have original 64×64 SVG icons; enchanted variants use their base illustration. Jewel and fallback icons are included. Equipment replacement, scroll conditions and server-authoritative item actions are unchanged. See `docs/UI_ART_DIRECTION.md` for icon conventions and the next grimoire milestone.

## Spatial backpack

No weight or encumbrance. An 8×5 grid uses item footprints from the catalog; worn weapon/shield/armour are outside the grid. Drag items to rearrange; drag compatible stacks together to merge, Shift-drag a stack to an empty space to split in half. Potions stack to 5, stones 10, arrows 40. Scrolls and equipment are single items. Dropping drops the whole selected stack; using consumes one. Pickup is all-or-nothing, and a gear replacement fails if the old item cannot fit in the freed space or elsewhere. Items have fixed orientation. Scout starts with 24 arrows, archers drop 12, new bows drop 16 alongside; one arrow per bow shot. No ammunition recovery yet. Server validates grid operations and rejects stale item requests using inventory revision. Sizes and ammo supply are provisional balancing values.

## Backpack tools, potion belt and trading

Select a non-square carried item and press R (or Rotate) to turn it 90 degrees in place; blocked rotations leave the item untouched. Auto-sort merges compatible stacks, packs larger items first and tries rotated placement where needed. If the complete packing fails, the old inventory is retained. Equipment stays outside the backpack. The four-dose belt is separate storage: select a potion and click Belt +1; Return dose moves one back if it fits. Press 4–7 to drink the corresponding occupied belt slot. The belt compacts when a dose is removed; potion use respects health, attack and cast rules. Belt loading/returning, rotation and sorting are revision-checked on the server.

Press J to open Companion exchange. Invite a nearby companion (same floor, within 3.5m, both out of combat). They accept the invitation, each may offer one complete unequipped stack (or nothing for a gift), then both confirm the displayed offers. Changing an offer resets confirmations. A trade expires after 45s or is cancelled if either player moves out of range, enters combat, changes inventory, disconnects, or cancels. Server commits both inventories only if both have space. No currency, multi-stack offers, escrow or cross-floor trading yet. Dedicated servers do not create UI or loot meshes. Ground drops use original item-family low-poly meshes with shared materials; loot pickup range and replicated position/quantity are unchanged. The Jewel objective remains separate. All clients and server must use the same build (inventory snapshot expanded).

## Equipment paper doll

The satchel now has a central engraved character silhouette, nine equipment slots and live backpack placement previews (green valid, red blocked, gold stack merge). Drag a carried weapon to Right hand, shield to Left hand, armour to Chest; head/gloves/boots/amulet/two ring slots accept matching new loot. Drag worn items back to a valid backpack position or right-click to unequip automatically. Right-click carried gear to equip; ring quick-equip fills the first empty ring slot. Equipment replacement is atomic if old gear cannot fit. Empty right hand uses weak unarmed strikes (6 base damage, 1.3m reach, 8 stamina), empty left hand cannot block. Dual wielding and two-handed occupancy remain deferred. New helmet/gloves/boots reduce damage by 4/2.5/3.5%; ward amulet/ring reduce magical damage by 10/5% each. Piece reductions multiply rather than add. These are provisional balance values. State snapshot includes accessory indices; update server and clients together.

## Compact dungeons and physical bottlenecks

Ordinary rooms are 2–3 cells per side (6–9m nominal), with 3×3 arrival/exit chambers and 5×5 boss chambers. Seeded bent corridors connect the rooms; straight sections outside rooms narrow to 1.2m (single-file for 0.64m-wide players) or 1.9m (passing). Turns remain full width, and room geometry/physics agree. The minimap shows corridor widths. Players now physically collide with each other; ranged attacks and sight retain the existing wall-only collision query. Stairs choose a clear landing position within interaction range, rather than stacking party members. Larger parties get three additional compact rooms per extra member per floor to retain encounter capacity. Monsters retain their tile-based movement, not new physical player/monster collision. The current room topology remains a connected chain with bends, not a maze with loops. Live co-op navigation and difficulty balancing still need playtesting.

## Branching exploration and client motion

Floors retain the guaranteed main route but now have optional alternate loops, side dead-end chambers, concealed masonry chambers (E at nearby loose masonry, optional treasure), and one-way escape shafts on Dungeon 3/4 and the Sanctuary when suitable side chambers exist. Shafts remain sealed until the Jewel is first claimed, then ascend to the preceding main floor entrance; normal stairs remain usable. The minimap excludes concealed tiles until the door opens. Secret discovery and rewards are server-authoritative and shared. Monster bodies collide with players, walls and each other; local sliding allows queues rather than deliberate pushing. Dead and dormant monsters do not block movement. Floor transfers search room clearance for both party and followers; followers without a free landing stay behind. Client motion uses frame-rate interpolation between authoritative 20Hz snapshots for players, monsters and projectiles, snapping on floor transitions or large corrections. Mouse look updates per rendered frame, and ENet range-coder compression reduces snapshot bandwidth. No local movement prediction or lag compensation yet; real two-machine playtesting is required. Both clients and server need the same version.

## Escape menu

Esc opens the parchment Expedition Journal menu from gameplay or other in-game panels. Esc again resumes; while capturing a new key it cancels the capture instead. Movement, attacking and microphone capture are disabled locally while open, but the live expedition continues (even in Solo). Keybinds use physical keys, including rebindable attack/block with mouse buttons, plus mouse sensitivity. Duplicate bindings and Escape are rejected; restore defaults is available. Keybinds, sensitivity and master/effects/ambience/voice volumes save in `user://settings.cfg`; microphone mode is session-only and defaults off on startup. The lobby page shows members and floors; listen host can lock/unlock new joins and remove companions with confirmation before the Jewel is claimed. Guests cannot administer the server; no remote admin RPC exists. Party capacity is fixed at generation. Return to menu and Quit both require confirmation; leaving as host ends the session. Existing disconnect semantics are retained. Some static world inscriptions still display default control letters; the action HUD and keybind menu show current bindings. No pregame ready room or server restart command is added.

## Grimoire readability and level-up feedback

The talent screen is an opaque, nearly full-screen parchment spread rendered above the gameplay HUD. The dependency tree measures its nodes and reserves horizontal/vertical gaps; wider branches can scroll in both directions. Talent details and active ability assignment stay in a separate column, with current ability keybinds. The close button returns to gameplay. A large gold LEVEL UP banner appears on the local player when their authoritative character level increases, including on joining clients; it shows the new level, prompts the current talent shortcut, and fades after about four seconds. It neither pauses the expedition nor intercepts input. No XP or talent rules changed.

## Display settings

LABIJ now opens in a larger 1280×720 window by default (fitted to the monitor work area). The logical 960×540 canvas remains unchanged so the HUD, inventory and grimoire scale with the window. Choose windowed, maximized or fullscreen in the main menu or Esc → Display. Window-size presets range from 960×540 to 2560×1440 and are clamped to fit the current monitor in windowed mode. Preferences persist locally in `user://settings.cfg`. Fullscreen uses the desktop display size; this does not change the monitor resolution. Dedicated/headless instances skip window operations.

## Animated world art pass

Original reproducible glTF models for the ten enemy types and a companion adventurer replace the visible capsules. `node tools/generate_characters.mjs` regenerates the models. Rigs use articulated rigid mesh parts with idle, gait, attack, hurt, sleep and death poses driven by existing authoritative state; no animation changes hit timing. Models load when their floor becomes visible, with a fallback for missing scenes. Shared 16px grain and flat-shaded geometry target the retro aesthetic. Companions show worn weapons, shields, armour and accessories; first-person arms use the same item meshes as ground loot, including improved faceted blades, windup/release, blocking, casting and potion-drinking poses. Weapon bob/motion is adjustable under Display. Enemy movement ramps speed and turns smoothly, caches tile path steps, preserves collision sliding and slows when blocked; no new combat rules or protocol-dependent movement prediction. Corpses are non-colliding. Dungeon corner decoration is batched, visual-only; floor/branch stone and torch colours differ. Impact fragments, projectile streaks, damage-direction feedback, mail footsteps, item sounds and subtle effects-bus reverb improve combat presentation. All assets are original project geometry or previously credited audio. This is a first art pass, not polished hand-authored skeletal animation; no Blender source files, physics ragdolls, real dynamic room acoustics or bespoke texture atlases. Visual/native multiplayer performance needs playtesting.

## Multiplayer initialization

Host/solo starts reset view/input/tick state and activate only after a local player exists. The joining client receives the seed, roster and a reliable full initial snapshot before activating its camera and HUD; it acknowledges bootstrap before ordinary snapshots/events are sent. A reliable catch-up snapshot closes the loading gap. Pending handshakes time out; capacity counts each player once. Floors generate deterministic collision/layout immediately, but render meshes only when visited. This reduces the initial rendering workload for larger hosted expeditions. Server and clients must use the same build.

## Expedition polish

Join attempts can be cancelled and time out after 45 seconds; connection failures retain an explanatory menu message. Guests can join again while the existing lobby permits new members, as a new character (no session restoration or mid-expedition reconnect). The server clears held movement/block/sprint/quiet input after 350ms without updates. Network heading interpolation eases toward snapshots without extrapolation; enemy movement slows near destinations and stops on attack initiation. Nearby party members receive journal feedback for their existing shared kill XP. Seeded corner supplies and relics are cosmetic, with subtle head anticipation/idle animation on existing rigs. No new character mesh assets or combat balance changes; native multiplayer and visual playtesting remain necessary.

## Dynamic dungeon combat

Melee enemies start attacks just outside hit reach and advance during the windup at species-specific speeds. Damage still resolves once at the end of the windup using actual reach and line of sight. Ranged enemies can retreat during windup/recovery but retain their initial aim, so dodging remains useful. Nearby enemies can react to goblin, guardian and hunter attack noise. Players retain more movement in melee windup and recovery. Enemy-family poses, weapon-specific first-person thrusts, bow and overhead swings, and differentiated hit particles use the existing assets. Players who reach zero HP are downed, drop the Jewel if carrying it, and can be revived by a living companion within 2m using Interact in a safe area (30% HP). Only a full party wipe ends the run. Seeded chests, breakable crates and inscriptions provide one-time rewards or lore; their consumed state is replicated alongside secrets. Existing secret doors remain interactive; no new physical door system. Floor-specific palettes, prison bars, crypt ornaments, temple reliefs, flooded floor patches, fog and water ambience are cosmetic. New tuning is provisional; no new handcrafted character meshes, swimming, support skill tree or channelled revival. All peers must use the same build.
