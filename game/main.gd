extends Node3D

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const InventoryUI = preload("res://game/items/inventory_ui.gd")
const SkillsUI = preload("res://game/progression/skills_ui.gd")
var skills_ui: PanelContainer
var talent_requests: Dictionary = {}
var xp_label: Label
var mana_bar: ProgressBar
const Catalog = preload("res://game/items/catalog.gd")
var inventory_ui: PanelContainer
var item_requests: Dictionary = {}
const PORT := 7777
var expedition_seed := 0
var party_size := 1
var party_selector: SpinBox

var actors: Dictionary = {}
var world: Node3D
var hud: Label
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var crosshair: Label
var damage_flash: ColorRect
var attack_requests: Dictionary = {}
var spectating := false
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
	multiplayer.peer_connected.connect(_peer_joined)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_failed)
	if dedicated:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--party-size="):
				party_size = clampi(int(arg.get_slice("=", 1)), 1, 8)
		_host()
	else:
		_build_menu()
		var layer := CanvasLayer.new()
		add_child(layer)
		hud = Label.new()
		hud.position = Vector2(16, 16)
		layer.add_child(hud)
		hud.hide()
		hp_bar = make_bar(layer, Vector2(16, 78), Color("#a64e48"))
		stamina_bar = make_bar(layer, Vector2(16, 106), Color("#6a9d65"))
		mana_bar = make_bar(layer, Vector2(16, 134), Color("#668cc4"))
		damage_flash = ColorRect.new()
		damage_flash.color = Color(0.8, 0.05, 0.05, 0)
		damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(damage_flash)
		damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crosshair = Label.new()
		crosshair.text = "+"
		crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(crosshair)
		crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		crosshair.hide()
		inventory_ui = InventoryUI.new()
		layer.add_child(inventory_ui)
		inventory_ui.position = Vector2(250, 120)
		inventory_ui.action.connect(_inventory_action)
		skills_ui = SkillsUI.new()
		layer.add_child(skills_ui)
		skills_ui.position = Vector2(160, 24)
		skills_ui.priority_changed.connect(_skill_action)
		skills_ui.talent_action.connect(_talent_action)
		xp_label = Label.new()
		xp_label.position = Vector2(16, 160)
		layer.add_child(xp_label)
		xp_label.hide()

func make_bar(layer: CanvasLayer, at: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(200, 20)
	bar.max_value = 100
	bar.value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(bar)
	bar.hide()
	return bar

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
	var party_label := Label.new()
	party_label.text = "Expected party size (Host)"
	panel.add_child(party_label)
	party_selector = SpinBox.new()
	party_selector.min_value = 1
	party_selector.max_value = 8
	party_selector.value = 2
	panel.add_child(party_selector)
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
			hp_bar.show()
			stamina_bar.show()
			mana_bar.show()
			crosshair.show()
			xp_label.show()

func _solo() -> void:
	party_size = 1
	new_expedition()
	_spawn(1)
	_start()

func _host() -> void:
	if not dedicated:
		party_size = int(party_selector.value)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, maxi(1, party_size if dedicated else party_size - 1))
	if err != OK:
		if status:
			status.text = "Cannot host: " + str(err)
		else:
			push_error("Cannot bind server")
			get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	new_expedition()
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
	status.text = "Generating expedition..."

func _failed() -> void:
	multiplayer.multiplayer_peer = null
	active = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
		world = null
	received_tick = -1
	if hud:
		hud.hide()
		hp_bar.hide()
		stamina_bar.hide()
		mana_bar.hide()
		crosshair.hide()
		inventory_ui.hide()
		skills_ui.hide()
		xp_label.hide()
		damage_flash.color.a = 0.0
	spectating = false
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
	item_requests.erase(id)
	talent_requests.erase(id)
	attack_requests.erase(id)
	stair_requests.erase(id)
	stair_cooldowns.erase(id)

func _peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	if actors.size() >= party_size:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	initialize_expedition.rpc_id(id, expedition_seed, party_size)
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		if inventory_ui:
			skills_ui.hide()
			inventory_ui.visible = not inventory_ui.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		if skills_ui:
			inventory_ui.hide()
			skills_ui.visible = not skills_ui.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if skills_ui.visible else Input.MOUSE_MODE_CAPTURED
		return
	if skills_ui and skills_ui.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			skills_ui.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if inventory_ui and inventory_ui.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			inventory_ui.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if multiplayer.is_server():
			stair_requests[multiplayer.get_unique_id()] = true
		else:
			request_stairs.rpc_id(1)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if multiplayer.is_server():
			item_requests[multiplayer.get_unique_id()] = [-1, false]
		else:
			request_item.rpc_id(1, -1, false)
	elif event is InputEventKey and event.pressed and not event.echo and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_T]:
		if event.physical_keycode == KEY_T:
			_talent_action("discover", "", 0)
		else:
			_talent_action("activate", "", event.physical_keycode - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if multiplayer.is_server():
				attack_requests[multiplayer.get_unique_id()] = true
			else:
				request_attack.rpc_id(1)
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
		var block := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		var sprint := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_SHIFT)
		if multiplayer.is_server():
			actor.wants_block = block
			actor.wants_sprint = sprint
			actor.direction = move.limit_length()
			actor.heading = yaw
		else:
			submit_input.rpc_id(1, move, yaw, block, sprint)
	if multiplayer.is_server():
		for id in attack_requests.keys():
			if actors.has(id):
				actors[id].begin_attack()
		attack_requests.clear()
		for id in item_requests:
			if actors.has(id):
				apply_item_action(actors[id], item_requests[id][0], item_requests[id][1])
		item_requests.clear()
		for actor in actors.values():
			actor.simulate(delta)
			if actor.advance_combat(delta):
				actor.swing_hit = world.strike(actor, actors)
		for id in actors:
			var spell_id: String = actors[id].advance_cast(delta)
			if spell_id != "":
				world.cast(actors[id], id, spell_id)
		world.simulate(actors, delta)
		world.projectiles.step(world, actors, delta)
		for id in talent_requests:
			if actors.has(id):
				apply_talent(actors[id], talent_requests[id])
		talent_requests.clear()
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
				states[id] = [actors[id].position, actors[id].heading, actors[id].floor_id, actors[id].health, actors[id].stamina, actors[id].blocking, actors[id].attack_phase, actors[id].hurt_timer, actors[id].swing_hit, actors[id].inventory.state(), actors[id].skills.state(), actors[id].combat_timer, actors[id].mana, actors[id].sprinting, actors[id].cast_id]
			snapshot.rpc(tick, states, world.monster_snapshot(), world.loot.state(), world.projectiles.state())
	if not dedicated and actors.has(local_id):
		var local = actors[local_id]
		var viewed_floor: int = local.floor_id
		if local.health <= 0 and local.camera:
			var watched = null
			for id in actors:
				if actors[id].health > 0:
					watched = actors[id]
					break
			if watched != null:
				spectating = true
				viewed_floor = watched.floor_id
				local.camera.global_position = watched.position + Vector3(0, 0.55, 0)
				local.camera.global_rotation = Vector3(pitch, yaw, 0)
			else:
				spectating = false
		world.visible_floor(viewed_floor)
		for id in actors:
			actors[id].visible = id == local_id or (actors[id].floor_id == viewed_floor and actors[id].health > 0)
		local.update_hands(delta)
		if inventory_ui:
			inventory_ui.refresh(local.inventory.state())
		if damage_flash:
			damage_flash.color.a = minf(0.3, local.hurt_timer)
		if hp_bar:
			hp_bar.max_value = local.max_health()
			hp_bar.value = local.health
			xp_label.text = "Level %d | %d XP | K: Talents | 1–3: Abilities" % [local.skills.character_level(), local.skills.total_xp]
			for i in range(3):
				var ability: String = local.skills.slots[i]
				if ability != "":
					xp_label.text += "\n%d: %s %.1fs" % [i + 1, ability, local.skills.cooldowns.get(ability, 0.0)]
			if skills_ui and skills_ui.visible:
				skills_ui.refresh(local.skills.state(), world.safe(local))
			stamina_bar.value = local.stamina
			mana_bar.value = local.mana
			if local.camera:
				local.camera.fov = lerpf(local.camera.fov, 85.0 if local.sprinting else 75.0, minf(1.0, delta * 8.0))
			crosshair.modulate = Color("#90df87") if local.swing_hit and local.attack_phase == 2 else Color.WHITE
		if hud:
			var step: int = world.stair_at(local.floor_id, local.position)
			hud.text = "Dungeon %d / %d" % [local.floor_id + 1, World.COUNT]
			if step != 0 and local.health > 0:
				hud.text += "  |  E: " + ("Descend" if step > 0 else "Ascend")
			if local.health <= 0:
				hud.text += "\n" + ("Dead — spectating" if spectating else "Party defeated — restart to try again")
			else:
				hud.text += "\nLMB: Attack | RMB: Block | Shift: Sprint | I: Inventory"
				var drop_id: int = world.loot.nearest(local)
				if drop_id != 0:
					hud.text += "\nF: Pick up " + Catalog.get_item(world.loot.drops[drop_id].item).title

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, angle: float, block: bool, sprint: bool) -> void:
	if not multiplayer.is_server() or not move.is_finite() or not is_finite(angle):
		return
	var id := multiplayer.get_remote_sender_id()
	if actors.has(id):
		actors[id].direction = move.limit_length()
		actors[id].heading = angle
		actors[id].wants_block = block
		actors[id].wants_sprint = sprint

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary) -> void:
	if not is_instance_valid(world) or sequence < received_tick:
		return
	received_tick = sequence
	world.apply_monsters(mobs)
	world.loot.apply(drops)
	world.projectiles.apply(shots)
	for id in states:
		if actors.has(id):
			actors[id].position = states[id][0]
			actors[id].floor_id = states[id][2]
			actors[id].health = states[id][3]
			actors[id].stamina = states[id][4]
			actors[id].blocking = states[id][5]
			actors[id].attack_phase = states[id][6]
			actors[id].hurt_timer = states[id][7]
			actors[id].swing_hit = states[id][8]
			actors[id].inventory.apply(states[id][9])
			actors[id].skills.apply(states[id][10])
			actors[id].combat_timer = states[id][11]
			actors[id].mana = states[id][12]
			actors[id].sprinting = states[id][13]
			actors[id].cast_id = states[id][14]
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

@rpc("any_peer", "call_remote", "reliable")
func request_attack() -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id):
			attack_requests[id] = true

func _inventory_action(index: int, drop: bool) -> void:
	if multiplayer.is_server():
		item_requests[multiplayer.get_unique_id()] = [index, drop]
	else:
		request_item.rpc_id(1, index, drop)

@rpc("any_peer", "call_remote", "reliable")
func request_item(index: int, drop: bool) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id) and index >= -1 and index < 12:
			item_requests[id] = [index, drop]

func apply_item_action(actor, index: int, drop: bool) -> void:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return
	if index == -1:
		world.loot.pickup(actor)
	elif drop:
		var item: String = actor.inventory.remove(index)
		if not item.is_empty():
			var at: Vector3 = actor.position
			at.y = world.floors[actor.floor_id].position.y + 0.3
			world.loot.spawn(item, actor.floor_id, at)
	else:
		if index >= 0 and index < actor.inventory.items.size() and Catalog.get_item(actor.inventory.items[index]).kind == "scroll" and not world.safe(actor):
			return
		actor.use_item(index)

func _skill_action(index: int, value: int) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_unique_id()
		if actors.has(id) and actors[id].health > 0:
			actors[id].skills.set_priority(index, value)
	else:
		request_skill.rpc_id(1, index, value)

@rpc("any_peer", "call_remote", "reliable")
func request_skill(index: int, value: int) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id) and actors[id].health > 0:
			actors[id].skills.set_priority(index, value)

func _talent_action(action: String, id: String, index: int) -> void:
	if multiplayer.is_server():
		talent_requests[multiplayer.get_unique_id()] = [action, id, index]
	else:
		request_talent.rpc_id(1, action, id, index)

@rpc("any_peer", "call_remote", "reliable")
func request_talent(action: String, id: String, index: int) -> void:
	if multiplayer.is_server():
		var peer := multiplayer.get_remote_sender_id()
		if actors.has(peer) and id.length() <= 64 and action in ["buy", "slot", "activate", "discover"]:
			talent_requests[peer] = [action, id, index]

func apply_talent(actor, request: Array) -> void:
	if actor.health <= 0:
		return
	if request[0] == "activate":
		actor.activate(request[2])
		return
	if request[0] == "discover":
		world.discover(actor)
		return
	if not world.safe(actor):
		return
	match request[0]:
		"buy": actor.buy_talent(request[1])
		"slot": actor.skills.assign_slot(request[2], request[1])

func new_expedition() -> void:
	expedition_seed = randi()
	build_expedition(expedition_seed, party_size)

func build_expedition(seed_value: int, size: int) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	expedition_seed = seed_value
	party_size = size
	world = World.new()
	add_child(world)
	world.build(seed_value, not dedicated and DisplayServer.get_name() != "headless", size)

@rpc("authority", "call_remote", "reliable")
func initialize_expedition(seed_value: int, size: int) -> void:
	build_expedition(seed_value, size)
	_start()
