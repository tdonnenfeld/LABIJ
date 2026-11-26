# Architecture

Single Godot 4.7.2 stable project, typed GDScript, Compatibility renderer, ENet UDP. Dedicated and listen servers share authoritative simulation. Clients submit movement intentions and receive state snapshots. Prototype snapshots snap directly to positions; prediction, interpolation, input timeout and reconnect are future work.

World graph -> logical floor -> geometry. Prototype generates one fixed-seed flat floor using overlapping rooms and connected corridors. Later replace with room socket templates, branch graph and per-floor persistent state. Keep gameplay definitions as Resources and mutable runtime state separate.

Next milestones: multi-floor state and stairs; combat and enemies; loot and skills; Jewel retrieval and escape; saves, resurrection and eight-player tests.
