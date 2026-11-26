extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(42069, false)
	var player := Player.new()
	root.add_child(player)
	player.setup(false, false)
	var ok := world.floors.size() == 4
	ok = ok and not world.transfer(player, 1)
	player.position = world.stair_position(0, true) + Vector3.UP
	var near = world.monsters[0]
	var far = world.monsters[1]
	near.target = 1
	near.node.position = player.position + Vector3(1, 0, 0)
	far.target = 1
	far.node.position = player.position + Vector3(8, 0, 0)
	ok = ok and world.transfer(player, 1)
	ok = ok and player.floor_id == 1 and near.floor == 1 and far.floor == 0
	ok = ok and world.transfer(player, 1)
	ok = ok and player.floor_id == 0 and near.floor == 0
	if not ok:
		push_error("Floor transfer test failed")
	quit(0 if ok else 1)
