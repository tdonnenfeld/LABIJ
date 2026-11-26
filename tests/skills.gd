extends SceneTree

const Skills = preload("res://game/progression/skills.gd")
const Player = preload("res://game/player.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var skills := Skills.new()
	skills.gain(200)
	var ok := skills.wallet[0] == 50 and skills.wallet[1] == 100
	ok = ok and not skills.buy("quick") and skills.buy("sword") and skills.buy("flurry")
	ok = ok and skills.wallet[1] == 35 and skills.xp[1] == 100
	ok = ok and not skills.buy("forgotten")
	skills.credit(1, 20)
	skills.discovered.append("forgotten")
	ok = ok and skills.buy("forgotten") and skills.assign_slot(0, "flurry")
	ok = ok and not skills.assign_slot(3, "flurry") and not skills.assign_slot(1, "sword")
	ok = ok and skills.learned.has("flurry") and skills.slots[0] == "flurry"
	var copy := Skills.new()
	copy.apply(skills.state())
	ok = ok and copy.state() == skills.state()
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	player.gain_xp(200)
	ok = ok and player.buy_talent("vitality") and player.max_health() == 115
	player.skills.credit(0, 50)
	ok = ok and player.buy_talent("wind") and player.skills.assign_slot(0, "wind")
	player.stamina = 40
	ok = ok and player.activate(0) and player.stamina == 75 and not player.activate(0)
	if not ok:
		push_error("Talent tests failed")
	quit(0 if ok else 1)
