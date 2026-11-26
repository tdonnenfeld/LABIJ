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

Monsters acquire the first visible player (nearest if several become visible in the same tick). Initial threat is 20. Actual damage and damage-over-time generate threat; a challenger must exceed current threat by 10% within 3m or 30% farther away. Dead/disconnected/off-floor players are removed from threat tables; nearby followers retain their target across stairs. Protector (Shields) increases generated direct damage threat by 50%. Bows use stamina and unlimited prototype arrows; Archery has its own XP tree. Poison blades, enchanted staves, runed mail and monster magic resistances are available. Cross-domain talents remain deferred.

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

The inventory [I] now has a parchment equipment spread, 12 carried slots with illustrated icons, clickable weapon/shield/armour cards, and selected-item stats with contextual actions. All 25 catalog IDs have original 64×64 SVG icons; enchanted variants use their base illustration. Jewel and fallback icons are included. Existing inventory capacity, equipment replacement, scroll conditions and server-authoritative item actions are unchanged. See `docs/UI_ART_DIRECTION.md` for icon conventions and the next grimoire milestone.
