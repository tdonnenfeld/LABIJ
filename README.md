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

This first prototype has a fixed-seed procedural floor, collision, first-person movement and basic authoritative network snapshots. No combat, loot, stairs, PS1 shader or save system yet. Remote movement is not predicted/interpolated. Multiplayer and visual testing are still required.

See docs/GAME_DESIGN.md and docs/ARCHITECTURE.md.
