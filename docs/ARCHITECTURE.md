# Architecture

Single Godot 4.7.2 stable project, typed GDScript, Compatibility renderer, ENet UDP. Dedicated and listen servers share authoritative simulation. Clients submit movement intentions and receive state snapshots. Prototype snapshots snap directly to positions; prediction, interpolation, input timeout and reconnect are future work.

World graph -> logical floor -> geometry. Prototype generates four independent floors, each with its own seed and tile map. Floors are spatially isolated in the shared physics world, with only the local floor rendered. All are retained in memory. Stair requests are validated by the server; players and nearby pursuing monsters transfer to paired stair locations. Empty floors have no monster targets and remain static. Later add room templates, branch graph, unloading and disk saves. Keep gameplay definitions as Resources and mutable runtime state separate.

Next milestones: combat and enemies; branch graph; loot and skills; Jewel retrieval and escape; saves, resurrection and eight-player tests.
