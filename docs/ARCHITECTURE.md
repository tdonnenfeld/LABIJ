# Architecture

Single Godot 4.7.2 stable project, typed GDScript, Compatibility renderer, ENet UDP. Dedicated and listen servers share authoritative simulation. Clients submit movement intentions and receive state snapshots. Prototype snapshots snap directly to positions; prediction, interpolation, input timeout and reconnect are future work.

World graph -> logical floor -> geometry. Prototype generates four independent floors, each with its own seed and tile map. Floors are spatially isolated in the shared physics world, with only the local floor rendered. All are retained in memory. Stair requests are validated by the server; players and nearby pursuing monsters transfer to paired stair locations. Empty floors have no monster targets and remain static. Later add room templates, branch graph, unloading and disk saves. Keep gameplay definitions as Resources and mutable runtime state separate.

Combat uses authoritative player and monster timers, stamina, frontal block checks and wall occlusion rays. Clients receive health, stamina and attack phases in snapshots. Dead actors cannot move, attack or use stairs. Placeholder monsters have no physical body and do not attack one another. Spectating follows the first living teammate. No audio assets yet.

Items are immutable Godot Resources in content/items; inventory stores item IDs and exact equipped slot indices, adjusted after removal. Server validates item actions and owns floor-specific drops. Snapshots replicate inventory and ground loot. Equipped items cannot be dropped until another item is equipped. Loot generation uses a seeded server RNG.

Progression is server-authoritative. XP is shared at full value with nearby living teammates; weighted training allocates it to six skills with increasing level thresholds. Character level is derived from total XP. Training priorities and skill XP are replicated in player snapshots. Dodging is deterministic damage mitigation for now; species aptitudes and true avoidance are future work.

Next milestones: branch graph; species and backgrounds; Jewel retrieval and escape; saves, resurrection and eight-player tests.
