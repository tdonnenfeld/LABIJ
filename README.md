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
