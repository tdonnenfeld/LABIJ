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

Four independent fixed-seed floors are connected by explicit stair interactions. Approach a gold DOWN or blue UP marker and press E. Players travel independently; pursuing monsters within 3 m of both the player and stairs follow. Floors and monster positions persist for the session. Red capsules pursue and attack; orange indicates a wind-up. Left click swings the sword, hold right click to block frontal attacks. Health and stamina appear in the HUD; green crosshair indicates a successful hit. Dead players spectate a surviving teammate, or see defeat when no one survives. Restart the game for a new run. Monsters drop shared physical loot. Press F near an item to pick it up, I to open the 12-slot inventory, and select Equip / use or Drop. Each player starts with a sword, shield and healing potion. The game does not pause while inventory or skills is open. Press K to allocate XP and purchase talents outside combat. Six domains have independent XP wallets; successful hits, blocks, near-miss dodges and kills award usage XP. Assign learned active abilities to slots 1–3. Discover a random secret at the tablet on Dungeon 2 (T); refund a domain at the shrine on Dungeon 3 for 75% of spent XP. Kills grant XP to the killer and living teammates within 15 m on the same floor. Purchased talents grant passive effects and active abilities; earning XP alone does not improve stats. Identical inventory items retain separate equipped slots. No resurrection, branches, PS1 shader or disk saves yet. Remote movement is not predicted/interpolated. Multiplayer and visual testing are still required.

See docs/GAME_DESIGN.md and docs/ARCHITECTURE.md.

## Monster and talent expansion

Each floor has a different roster: fast cave rats, goblins, slow heavy ogres, skeleton archers with telegraphed aimed ranged hits, and armored iron guardians. All can follow stairs when close. K opens connected talent nodes with a details panel; scroll to see deeper tiers. New effects include bleed, stagger, armor penetration, perfect guard, cleave, riposte and temporary defensive abilities. Monsters still use placeholder geometry; archer attacks are resolved by range, line of sight and movement from the aimed point, not physical projectiles.
