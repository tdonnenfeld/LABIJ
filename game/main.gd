extends Node3D

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const PORT := 7777
const SEED := 42069

var actors: Dictionary = {}
var world: Node3D
var hud: Label
var stair_requests: Dictionary = {}
var stair_cooldowns: Dictionary = {}
var yaw := 0.0
var pitch := 0.0
var tick := 0
var received_tick := -1
var active := false
var dedicated := false
var menu: CanvasLayer
var address: LineEdit
var status: Label

func _ready() -> void:
	dedicated = "--server" in OS.get_cmdline_user_args()
	if not dedicated and DisplayServer.get_name() != "headless":
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color("#141311")
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color("#a7a08d")
		settings.ambient_light_energy = 0.35
		environment.environment = settings
		add_child(environment)
	world = World.new()
	add_child(world)
	world.build(SEED, not dedicated and DisplayServer.get_name() != "headless")
	multiplayer.peer_connected.connect(_peer_joined)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_failed)
	if dedicated:
		_host()
	else:
		_build_menu()
		var layer := CanvasLayer.new()
		add_child(layer)
		hud = Label.new()
		hud.position = Vector2(16, 16)
		layer.add_child(hud)
		hud.hide()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var panel := VBoxContainer.new()
	panel.position = Vector2(30, 30)
	menu.add_child(panel)
	var title := Label.new()
	title.text = "LABIJ — First Descent"
	panel.add_child(title)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	panel.add_child(address)
	for entry in [["Solo", _solo], ["Host", _host], ["Join", _join]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		panel.add_child(button)
	status = Label.new()
	status.text = "WASD / ZQSD physical keys • mouse • Esc releases mouse"
	panel.add_child(status)

func _start() -> void:
	active = true
	if menu:
		menu.hide()
	if not dedicated:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if hud:
			hud.show()

func _solo() -> void:
	_spawn(1)
	_start()

func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 8 if dedicated else 7)
	if err != OK:
		if status:
			status.text = "Cannot host: " + str(err)
		else:
			push_error("Cannot bind server")
			get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	if not dedicated:
		_spawn(1)
	_start()

func _join() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.text.strip_edges(), PORT)
	if err != OK:
		status.text = "Cannot connect: " + str(err)
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Connecting..."

func _connected() -> void:
	_start()

func _failed() -> void:
	multiplayer.multiplayer_peer = null
	active = false
	received_tick = -1
	if hud:
		hud.hide()
	for id in actors.keys():
		_remove(id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu:
		menu.show()
		status.text = "Disconnected"

func _spawn(id: int) -> void:
	if actors.has(id):
		return
	var actor := Player.new()
	actor.name = str(id)
	add_child(actor)
	actor.position = Vector3(float(actors.size() % 4) * 0.85, 1.0, float(actors.size() / 4) * 0.85)
	actor.setup(not dedicated and id == multiplayer.get_unique_id(), not dedicated and DisplayServer.get_name() != "headless")
	actors[id] = actor

func _remove(id: int) -> void:
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)
	stair_requests.erase(id)
	stair_cooldowns.erase(id)

func _peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	for existing in actors.keys():
		spawn_remote.rpc_id(id, existing, actors[existing].floor_id, actors[existing].position)
	_spawn(id)
	spawn_remote.rpc(id, 0, actors[id].position)

func _peer_left(id: int) -> void:
	if multiplayer.is_server():
		_remove(id)
		remove_remote.rpc(id)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int, floor_id: int, at: Vector3) -> void:
	_spawn(id)
	actors[id].floor_id = floor_id
	actors[id].position = at

@rpc("authority", "call_remote", "reliable")
func remove_remote(id: int) -> void:
	_remove(id)

func _unhandled_input(event: InputEvent) -> void:
	if not active or dedicated:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if multiplayer.is_server():
			stair_requests[multiplayer.get_unique_id()] = true
		else:
			request_stairs.rpc_id(1)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.002
		pitch = clampf(pitch - event.relative.y * 0.002, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	if not active:
		return
	var local_id := multiplayer.get_unique_id()
	if not dedicated and actors.has(local_id):
		var move := Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			move.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
			move.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		var actor = actors[local_id]
		if actor.camera:
			actor.camera.rotation.x = pitch
		actor.rotation.y = yaw
		if multiplayer.is_server():
			actor.direction = move.limit_length()
			actor.heading = yaw
		else:
			submit_input.rpc_id(1, move, yaw)
	if multiplayer.is_server():
		for actor in actors.values():
			actor.simulate(delta)
		world.simulate(actors, delta)
		for id in stair_cooldowns.keys():
			stair_cooldowns[id] = maxf(0.0, stair_cooldowns[id] - delta)
		for id in stair_requests.keys():
			if actors.has(id) and stair_cooldowns.get(id, 0.0) <= 0.0 and world.transfer(actors[id], id):
				stair_cooldowns[id] = 0.75
				if multiplayer.has_multiplayer_peer():
					transition.rpc(tick, id, actors[id].floor_id, actors[id].position, world.monster_snapshot())
		stair_requests.clear()
		tick += 1
		if tick % 3 == 0 and multiplayer.has_multiplayer_peer():
			var states := {}
			for id in actors:
				states[id] = [actors[id].position, actors[id].heading, actors[id].floor_id]
			snapshot.rpc(tick, states, world.monster_snapshot())
	if not dedicated and actors.has(local_id):
		var local = actors[local_id]
		world.visible_floor(local.floor_id)
		for id in actors:
			actors[id].visible = actors[id].floor_id == local.floor_id
		if hud:
			var step: int = world.stair_at(local.floor_id, local.position)
			hud.text = "Dungeon %d / %d" % [local.floor_id + 1, World.COUNT]
			if step != 0:
				hud.text += "  |  E: " + ("Descend" if step > 0 else "Ascend")

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, angle: float) -> void:
	if not multiplayer.is_server() or not move.is_finite() or not is_finite(angle):
		return
	var id := multiplayer.get_remote_sender_id()
	if actors.has(id):
		actors[id].direction = move.limit_length()
		actors[id].heading = angle

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(sequence: int, states: Dictionary, mobs: Dictionary) -> void:
	if sequence < received_tick:
		return
	received_tick = sequence
	world.apply_monsters(mobs)
	for id in states:
		if actors.has(id):
			actors[id].position = states[id][0]
			actors[id].floor_id = states[id][2]
			if id != multiplayer.get_unique_id():
				actors[id].rotation.y = states[id][1]

@rpc("any_peer", "call_remote", "reliable")
func request_stairs() -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id):
			stair_requests[id] = true

@rpc("authority", "call_remote", "reliable")
func transition(sequence: int, id: int, floor_id: int, at: Vector3, mobs: Dictionary) -> void:
	if sequence < received_tick:
		return
	received_tick = sequence
	if actors.has(id):
		actors[id].floor_id = floor_id
		actors[id].position = at
	world.apply_monsters(mobs)
