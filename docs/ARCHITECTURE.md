# Architecture

Single Godot 4.7.2 stable project, typed GDScript, Compatibility renderer, ENet UDP. Dedicated and listen servers share authoritative simulation. Clients submit movement intentions and receive state snapshots. Prototype snapshots snap directly to positions; prediction, interpolation, input timeout and reconnect are future work.

World graph -> logical floor -> geometry. Prototype generates four independent floors, each with its own seed and tile map. Floors are spatially isolated in the shared physics world, with only the local floor rendered. All are retained in memory. Stair requests are validated by the server; players and nearby pursuing monsters transfer to paired stair locations. Empty floors have no monster targets and remain static. Later add room templates, branch graph, unloading and disk saves. Keep gameplay definitions as Resources and mutable runtime state separate.

Combat uses authoritative player and monster timers, stamina, frontal block checks and wall occlusion rays. Clients receive health, stamina and attack phases in snapshots. Dead actors cannot move, attack or use stairs. Placeholder monsters have no physical body and do not attack one another. Spectating follows the first living teammate. No audio assets yet.

Items are immutable Godot Resources in content/items; inventory stores item IDs and exact equipped slot indices, adjusted after removal. Server validates item actions and owns floor-specific drops. Snapshots replicate inventory and ground loot. Equipped items cannot be dropped until another item is equipped. Loot generation uses a seeded server RNG.

Progression is server-authoritative. XP is shared at full value with nearby living teammates; weighted training allocates it to six domain wallets; usage XP is credited separately. Talents have costs, prerequisite IDs and explicit gameplay effects. Purchases and loadout changes require no enemy within 12 m and no recent combat (5 seconds). A server-selected secret tablet and one respec shrine are placed in the prototype floors. Three active slots have independent cooldowns. Character level is derived from total XP. Training priorities, wallets, learned talents, discoveries, cooldowns and lifetime domain XP are replicated in player snapshots. Dodging is deterministic damage mitigation for now; species aptitudes and true avoidance are future work.

Next milestones: branch graph; species and backgrounds; Jewel retrieval and escape; saves, resurrection and eight-player tests.

Monster definitions and encounter rosters live in game/monsters/bestiary.gd. Per-monster runtime state includes health, aim, attack timers, bleed and stun. Bleed uses the same kill reward path as direct hits. Talent UI lays out prerequisite nodes by depth; the server remains authoritative for all effects.

Projectile state is authoritative and replicated as visual snapshots; swept segment tests avoid tunneling against targets and wall raycasts stop projectiles. The prototype uses horizontal player aim and spherical target hit volumes. Magic definitions live in game/combat/spells.gd. Mana, cast state and sprint state are replicated alongside player snapshots. New weapon and armour categories remain future work.

Expedition seed and expected party size are server-selected and transmitted reliably before actor spawn. Generation uses seeded RNG and sorted candidate tiles; monster IDs are stable across peers. Population is fixed once generated. Talent purchases are permanent and spells are learned through scrolls gated by lifetime school XP. Inventory tracks armour by exact slot as for weapons and shields.
