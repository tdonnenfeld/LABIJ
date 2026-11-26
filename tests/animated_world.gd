extends SceneTree

const Motion = preload("res://game/visuals/motion_curves.gd")
const Assets = preload("res://game/visuals/asset_registry.gd")
const Rig = preload("res://game/visuals/actor_rig.gd")
const Player = preload("res://game/player.gd")
const World = preload("res://game/world.gd")
const Dungeon = preload("res://game/dungeon.gd")
const FX = preload("res://game/visuals/combat_fx.gd")
const Direction = preload("res://game/ui/damage_direction.gd")
const Settings = preload("res://game/ui/player_settings.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	check(is_equal_approx(Motion.blend(0.2, 10.0), 1.0 - pow(1.0 - Motion.blend(0.1, 10.0), 2.0)), "Frame-rate independent smoothing")
	check(Motion.strike(0.0) == 0.0 and Motion.strike(0.22) == 1.0 and Motion.settle(1.0) == 1.0, "Strike and recovery curve endpoints")
	check(Motion.swing("axe") != Motion.swing("spear"), "Distinct weapon trajectories")
	var parent := Node3D.new()
	root.add_child(parent)
	for kind in Assets.CHARACTERS:
		var rig := Rig.new()
		parent.add_child(rig)
		rig.setup(kind, 1.7)
		check(Assets.scenes.has(kind) and rig.body != null and rig.arm_r != null and rig.leg_l != null, "Imported articulated model: " + kind)
		if kind != "rat":
			check(rig.grip_r != null and rig.grip_l != null, "Equipment sockets: " + kind)
		rig.animate(0.1, true, 0, false, false)
		parent.position.x += 0.2
		rig.animate(0.1, true, 1, false, true)
		check(rig.ever_alive and rig.speed > 0.0, "Motion sampling")
		rig.animate(1.0, false, 0, false, false)
		check(absf(rig.pose + PI * 0.5) < 0.001, "Corpse pose")
		rig.free()
	check(Assets.grain().get_width() == 16, "Shared low-res texture")
	parent.free()
	var local := Player.new()
	root.add_child(local)
	local.setup(true, true)
	local.update_hands(0.1)
	check(local.hands.weapon != null and local.hands.shield != null, "First-person weapon and shield")
	local.inventory.unequip(0)
	local.update_hands(0.1)
	check(local.hands.weapon == null, "Unarmed hands")
	local.free()
	var companion := Player.new()
	root.add_child(companion)
	companion.setup(false, true)
	companion.inventory.add("iron_helm")
	companion.inventory.equip(companion.inventory.items.size() - 1)
	companion.update_hands(0.1)
	check(companion.character_rig.right_item != null and companion.character_rig.worn.size() == 1, "Companion gear visible")
	companion.free()
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 1)
	var mob: Dictionary = world.monsters[0]
	mob.node.rotation.y = 0.0
	var at: Vector3 = mob.node.position + Vector3.RIGHT
	world.face_toward(mob, at, 0.03)
	check(mob.node.rotation.y < 0.0 and mob.node.rotation.y > -PI / 2.0, "Smooth turning")
	var before: Vector3 = mob.node.position
	world.move_monster(mob, at, 0.016, 2.8)
	check(mob.move_speed > 0.0 and mob.move_speed < 2.8 and before.distance_to(mob.node.position) <= 2.8 * 0.016, "Acceleration bounded")
	world.free()
	var fx := FX.new()
	root.add_child(fx)
	for i in range(30):
		fx.burst(Vector3.ZERO, 0, "damage", i)
	check(fx.bursts.size() == FX.LIMIT, "Bounded particles")
	fx._process(1.0)
	check(fx.bursts.is_empty(), "Particles expire")
	fx.free()
	var indicator := Direction.new()
	root.add_child(indicator)
	indicator.hit(Vector3.RIGHT, false)
	indicator.update_direction(Vector3.ZERO, 0.0, 0.1)
	check(indicator.visible and is_equal_approx(indicator.bearing, PI / 2.0), "Directional impact")
	indicator.update_direction(Vector3.ZERO, 0.0, 1.0)
	check(not indicator.visible, "Impact indicator fades")
	indicator.free()
	var settings := Settings.new()
	settings.view_motion = 0.25
	var path := "user://animated_world_test.cfg"
	check(settings.save_file(path) == OK, "Motion preference saved")
	var loaded := Settings.new()
	loaded.load_file(path)
	check(is_equal_approx(loaded.view_motion, 0.25), "Motion preference restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	settings = null
	loaded = null
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)
