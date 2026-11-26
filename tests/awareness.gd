extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Noise = preload("res://game/world/noise.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var tiles := {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true, Vector2i(2, 1): true, Vector2i(2, 2): true, Vector2i(1, 2): true, Vector2i(0, 2): true}
	var distances := Noise.reach(tiles, Vector3.ZERO, 7.0)
	check(not Noise.audible(distances, Vector3.ZERO, Vector3(0, 0, 6), 7.0), "Sound must not cross intervening walls")
	distances = Noise.reach(tiles, Vector3.ZERO, 18.0)
	check(Noise.audible(distances, Vector3.ZERO, Vector3(0, 0, 6), 18.0), "Loud sound can travel around corridor")
	var world := World.new()
	root.add_child(world)
	world.build(123, false)
	var count := world.monsters.size()
	var mob: Dictionary = world.monsters[0]
	mob.asleep = true
	var at: Vector3 = mob.node.position
	world.simulate({}, 0.1)
	check(mob.asleep and mob.node.position == at, "Sleeping enemy stays still")
	world.emit_noise(1, at, 18.0)
	check(mob.asleep, "Sound does not cross floors")
	world.emit_noise(0, at, 9.0)
	check(not mob.asleep and mob.investigate > 0 and mob.threat.is_empty(), "Noise wakes and investigates without granting threat")
	var snap := world.monster_snapshot()
	mob.asleep = true
	world.apply_monsters(snap)
	check(not mob.asleep and mob.investigate > 0, "Awareness state replicates")
	mob.investigate = 0.0
	mob.roam_wait = 0.0
	world.idle_move(mob, 0.1)
	world.idle_move(mob, 0.2)
	check(mob.node.position != at, "Awake enemy walks to a valid adjacent tile")
	check(world.floors[0].tiles.has(Noise.cell(mob.node.position)), "Roaming remains on dungeon tiles")
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.position = at
	actor.quiet_walking = true
	world.footsteps(actor, at + Vector3(1.5, 0, 0), 0.1)
	check(is_equal_approx(actor.noise_level, Noise.QUIET), "Quiet footsteps")
	actor.quiet_walking = false
	actor.sprinting = true
	world.footsteps(actor, at + Vector3(1.5, 0, 0), 0.1)
	check(is_equal_approx(actor.noise_level, Noise.SPRINT), "Sprint footsteps louder")
	mob.asleep = true
	mob.health = 100
	world.hit_monster(actor, mob, {1: actor})
	check(not mob.asleep and mob.threat.has(1), "Direct damage wakes and generates threat")
	check(world.monsters.size() == count, "No respawns or population change")
	quit(0 if failures == 0 else 1)
