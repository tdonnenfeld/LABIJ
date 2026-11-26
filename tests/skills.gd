extends SceneTree

const Skills = preload("res://game/progression/skills.gd")
const Player = preload("res://game/player.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var skills := Skills.new()
	skills.gain(200)
	var ok := skills.total_xp == 200 and skills.xp[0] == 50 and skills.xp[1] == 100 and skills.xp[4] == 50
	ok = ok and skills.skill_level(0) == 1 and skills.skill_level(2) == 0
	ok = ok and not skills.set_priority(-1, 2) and not skills.set_priority(0, 3)
	for i in range(Skills.IDS.size()):
		skills.set_priority(i, 0)
	skills.set_priority(2, 2)
	skills.gain(150)
	ok = ok and skills.skill_level(2) == 2 and skills.weapon_level("axe") == 2
	var copy := Skills.new()
	copy.apply(skills.state())
	ok = ok and copy.state() == skills.state()
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	player.gain_xp(200)
	ok = ok and player.max_health() == 104 and player.health == 104
	ok = ok and player.attack_damage() > 25 and player.attack_cost() < 20
	if not ok:
		push_error("Skills test failed")
	quit(0 if ok else 1)
