extends SceneTree

const Player = preload("res://game/player.gd")
const Combat = preload("res://game/combat.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	var ok := player.begin_attack()
	ok = ok and player.stamina == 80.0
	ok = ok and not player.begin_attack()
	ok = ok and not player.advance_combat(0.1)
	ok = ok and player.advance_combat(0.3)
	ok = ok and player.attack_phase == 2
	player.advance_combat(0.7)
	player.wants_block = true
	player.advance_combat(0.01)
	player.take_damage(10.0, Vector3(0, 0, -2))
	ok = ok and is_equal_approx(player.health, 98.0)
	player.take_damage(10.0, Vector3(0, 0, 2))
	ok = ok and is_equal_approx(player.health, 88.0)
	ok = ok and Combat.can_hit(Vector3.ZERO, Vector3(0, 0, -2), 0, Combat.REACH)
	ok = ok and not Combat.can_hit(Vector3.ZERO, Vector3(0, 0, 2), 0, Combat.REACH)
	player.take_damage(1000, Vector3(0, 0, 2))
	ok = ok and player.health == 0 and not player.begin_attack()
	if not ok:
		push_error("Combat test failed")
	quit(0 if ok else 1)
