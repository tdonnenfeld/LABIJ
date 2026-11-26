extends Node3D

const Numbers = preload("res://game/ui/numbers.gd")

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const InventoryUI = preload("res://game/items/inventory_ui.gd")
const SkillsUI = preload("res://game/progression/skills_ui.gd")
var skills_ui: PanelContainer
var talent_requests: Dictionary = {}
var xp_label: Label
var mana_bar: ProgressBar
var objective_label: Label
var result_screen: CenterContainer
var result_label: Label
var result_shown := false
const LogPanel = preload("res://game/ui/log_panel.gd")
const PartyPanel = preload("res://game/ui/party_panel.gd")
const Feedback = preload("res://game/ui/combat_feedback.gd")
var log_panel: PanelContainer
var party_panel: PanelContainer
var feedback: Node3D
var party_names: Dictionary = {}
var next_party_number := 1
var action_bar: Label
const Minimap = preload("res://game/ui/minimap.gd")
var minimap: Control
var map_timer := 0.0
const Profiles = preload("res://game/progression/profiles.gd")
const NoiseMeter = preload("res://game/ui/noise_meter.gd")
var noise_meter: Control
const DungeonAudio = preload("res://game/audio/dungeon_audio.gd")
var dungeon_audio: Node3D
const ProximityVoice = preload("res://game/audio/proximity_voice.gd")
const VoiceCodec = preload("res://game/audio/voice_codec.gd")
var voice_chat: Node3D
var voice_selector: OptionButton
var voice_label: Label
var voice_mode := 0
var voice_muted := false
var voice_tokens: Dictionary = {}
var voice_peaks: Dictionary = {}
var voice_timer := 0.0
var character_name: LineEdit
var species_selector: OptionButton
var background_selector: OptionButton
var profile_details: Label
var pending_profiles: Dictionary = {}
var selected_profile: Array = ["", 0, 0]
var noise_label: Label
var target_label: Label
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
		settings.background_color = Color("#141611")
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color("#a3ae9e")
		settings.ambient_light_energy = 0.32
		if not "--debug-geometry" in OS.get_cmdline_user_args():
			settings.fog_enabled = true
			settings.fog_light_color = Color("#252a25")
			settings.fog_density = 0.027
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
		objective_label = Label.new()
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		layer.add_child(objective_label)
		objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		objective_label.offset_left = -340
		objective_label.offset_right = -16
		objective_label.offset_top = 16
		objective_label.hide()
		log_panel = LogPanel.new()
		layer.add_child(log_panel)
		log_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		log_panel.offset_left = 16
		log_panel.offset_top = -180
		log_panel.offset_bottom = -16
		log_panel.offset_right = 396
		log_panel.hide()
		party_panel = PartyPanel.new()
		layer.add_child(party_panel)
		party_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		party_panel.offset_left = -360
		party_panel.offset_right = -16
		party_panel.offset_top = 92
		party_panel.hide()
		action_bar = Label.new()
		action_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(action_bar)
		action_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		action_bar.offset_left = -240
		action_bar.offset_right = 240
		action_bar.offset_top = -58
		action_bar.offset_bottom = -16
		action_bar.hide()
		noise_label = Label.new()
		noise_label.position = Vector2(16, 184)
		layer.add_child(noise_label)
		noise_label.hide()
		noise_meter = NoiseMeter.new()
		layer.add_child(noise_meter)
		noise_meter.position = Vector2(16, 207)
		noise_meter.size = Vector2(200, 12)
		noise_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		noise_meter.hide()
		voice_label = Label.new()
		voice_label.position = Vector2(16, 221)
		voice_label.add_theme_font_size_override("font_size", 12)
		layer.add_child(voice_label)
		voice_label.hide()
		target_label = Label.new()
		target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(target_label)
		target_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		target_label.offset_left = -155
		target_label.offset_right = 155
		target_label.offset_top = 12
		target_label.hide()
		minimap = Minimap.new()
		layer.add_child(minimap)
		minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		minimap.offset_left = -222
		minimap.offset_right = -16
		minimap.offset_top = -278
		minimap.offset_bottom = -72
		minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap.hide()
		var popup_layer := Control.new()
		layer.add_child(popup_layer)
		popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dungeon_audio = DungeonAudio.new()
		add_child(dungeon_audio)
		voice_chat = ProximityVoice.new()
		add_child(voice_chat)
		feedback = Feedback.new()
		add_child(feedback)
		feedback.local_layer = popup_layer
		result_screen = CenterContainer.new()
		layer.add_child(result_screen)
		result_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var panel := PanelContainer.new()
		result_screen.add_child(panel)
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 320
		panel.add_child(column)
		result_label = Label.new()
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(result_label)
		var back := Button.new()
		back.text = "Return to menu"
		column.add_child(back)
		back.pressed.connect(_failed)
		result_screen.hide()

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
	character_name = LineEdit.new()
	character_name.placeholder_text = "Character name (optional)"
	character_name.max_length = 24
	panel.add_child(character_name)
	species_selector = OptionButton.new()
	for entry in Profiles.SPECIES:
		species_selector.add_item(entry[0])
	panel.add_child(species_selector)
	background_selector = OptionButton.new()
	for entry in Profiles.BACKGROUNDS:
		background_selector.add_item(entry[0])
	panel.add_child(background_selector)
	profile_details = Label.new()
	profile_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_details.custom_minimum_size.x = 420
	panel.add_child(profile_details)
	species_selector.item_selected.connect(func(_index): refresh_profile_details())
	background_selector.item_selected.connect(func(_index): refresh_profile_details())
	refresh_profile_details()
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
	voice_selector = OptionButton.new()
	for mode in ["Microphone off", "Push to talk [V]", "Open mic — sound affects monsters"]:
		voice_selector.add_item(mode)
	panel.add_child(voice_selector)
	var voice_hint := Label.new()
	voice_hint.text = "Voice reaches nearby teammates and enemies. N mutes."
	panel.add_child(voice_hint)
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
		voice_mode = voice_selector.selected
		voice_muted = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if hud:
			hud.show()
			hp_bar.show()
			stamina_bar.show()
			mana_bar.show()
			crosshair.show()
			xp_label.show()
			objective_label.show()
			log_panel.show()
			party_panel.show()
			action_bar.show()
			noise_label.show()
			noise_meter.show()
			voice_label.show()
			target_label.show()
			minimap.show()

func _solo() -> void:
	selected_profile = menu_profile()
	party_size = 1
	new_expedition()
	_spawn(1, selected_profile)
	_start()

func _host() -> void:
	if not dedicated:
		selected_profile = menu_profile()
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
		_spawn(1, selected_profile)
	_start()

func _join() -> void:
	selected_profile = menu_profile()
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
	pending_profiles.clear()
	active = false
	result_shown = false
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
		objective_label.hide()
		log_panel.hide()
		log_panel.reset()
		party_panel.hide()
		action_bar.hide()
		noise_label.hide()
		noise_meter.hide()
		noise_meter.update_levels(0.0, 0.0)
		voice_label.hide()
		voice_chat.reset()
		target_label.hide()
		minimap.hide()
		minimap.reset()
		feedback.reset()
		dungeon_audio.reset()
		result_screen.hide()
		damage_flash.color.a = 0.0
	for id in actors.keys():
		_remove(id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu:
		menu.show()
		status.text = "Choose Solo, Host or Join"

func _spawn(id: int, profile: Array = ["", 0, 0]) -> void:
	if actors.has(id):
		return
	var actor := Player.new()
	actor.name = str(id)
	add_child(actor)
	actor.position = Vector3(float(actors.size() % 4) * 0.85, 1.0, float(floori(float(actors.size()) / 4.0)) * 0.85)
	actor.setup(not dedicated and id == multiplayer.get_unique_id(), not dedicated and DisplayServer.get_name() != "headless")
	actors[id] = actor
	var player_name := Profiles.clean_name(str(profile[0]))
	if multiplayer.is_server() and player_name.is_empty():
		player_name = "Player %d" % next_party_number
	actor.configure_profile(player_name, int(profile[1]), int(profile[2]))
	if multiplayer.is_server():
		party_names[id] = actor.display_name
		next_party_number += 1
		world.watch_player(actor, id)
		world.journal.add("Party", "%s enters the dungeon" % actor.display_name)

func _remove(id: int) -> void:
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)
	voice_tokens.erase(id)
	voice_peaks.erase(id)
	party_names.erase(id)
	item_requests.erase(id)
	talent_requests.erase(id)
	attack_requests.erase(id)
	stair_requests.erase(id)
	stair_cooldowns.erase(id)

func _peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	if world.objective.started or world.objective.result != "" or actors.size() + pending_profiles.size() >= party_size:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	pending_profiles[id] = 10.0
	request_profile.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func request_profile() -> void:
	submit_profile.rpc_id(1, str(selected_profile[0]), int(selected_profile[1]), int(selected_profile[2]))

@rpc("any_peer", "call_remote", "reliable")
func submit_profile(chosen_name: String, species: int, background: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not pending_profiles.has(id):
		return
	pending_profiles.erase(id)
	if not Profiles.valid(species, background) or chosen_name.length() > 64 or world.objective.started or world.objective.result != "" or actors.size() >= party_size:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	initialize_expedition.rpc_id(id, expedition_seed, party_size)
	for existing in actors.keys():
		var member = actors[existing]
		spawn_remote.rpc_id(id, existing, member.floor_id, member.position, member.display_name, member.species_id, member.background_id)
	_spawn(id, [chosen_name, species, background])
	spawn_remote.rpc(id, 0, actors[id].position, actors[id].display_name, species, background)
	log_history.rpc_id(id, world.journal.history)

func _peer_left(id: int) -> void:
	if multiplayer.is_server():
		if pending_profiles.erase(id) or not actors.has(id):
			return
		if is_instance_valid(world) and actors.has(id):
			world.release_jewel(actors[id], id)
			world.journal.add("Party", "%s disconnects" % actors[id].display_name)
		_remove(id)
		if is_instance_valid(world) and actors.is_empty() and world.objective.started and world.objective.result == "":
			world.objective.result = "defeat"
		remove_remote.rpc(id)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int, floor_id: int, at: Vector3, player_name: String, species: int, background: int) -> void:
	_spawn(id, [player_name, species, background])
	actors[id].floor_id = floor_id
	actors[id].position = at
	actors[id].display_name = player_name

@rpc("authority", "call_remote", "reliable")
func remove_remote(id: int) -> void:
	_remove(id)

func _unhandled_input(event: InputEvent) -> void:
	if not active or dedicated or world.objective.result != "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		voice_muted = not voice_muted
		if voice_muted:
			voice_chat.stop_capture()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		minimap.visible = not minimap.visible
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		log_panel.visible = not log_panel.visible
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
	elif event is InputEventKey and event.pressed and not event.echo and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_T, KEY_G, KEY_H]:
		if event.physical_keycode == KEY_H:
			_talent_action("throw_stone", "", 0)
		elif event.physical_keycode == KEY_G:
			_talent_action("drop_jewel", "", 0)
		elif event.physical_keycode == KEY_T:
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
	if world.objective.result != "":
		show_result()
		return
	var local_id := multiplayer.get_unique_id()
	if not dedicated and actors.has(local_id):
		var move := Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			move.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
			move.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		var actor = actors[local_id]
		update_voice(actor, delta)
		if actor.camera:
			actor.camera.rotation.x = pitch
		actor.rotation.y = yaw
		var block := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		var sprint := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_SHIFT)
		var quiet := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_CTRL)
		if multiplayer.is_server():
			actor.wants_block = block
			actor.wants_sprint = sprint
			actor.wants_quiet = quiet
			actor.direction = move.limit_length()
			actor.heading = yaw
		else:
			submit_input.rpc_id(1, move, yaw, block, sprint, quiet)
	if multiplayer.is_server():
		advance_voice(delta)
		for id in pending_profiles.keys():
			pending_profiles[id] -= delta
			if pending_profiles[id] <= 0:
				pending_profiles.erase(id)
				multiplayer.multiplayer_peer.disconnect_peer(id)
		for id in attack_requests.keys():
			if actors.has(id):
				actors[id].begin_attack()
		attack_requests.clear()
		for id in item_requests:
			if actors.has(id):
				apply_item_action(actors[id], item_requests[id][0], item_requests[id][1])
		item_requests.clear()
		for actor in actors.values():
			var before: Vector3 = actor.position
			actor.simulate(delta)
			world.footsteps(actor, before, delta)
			if actor.advance_combat(delta):
				actor.swing_hit = world.strike(actor, actors)
		for id in actors:
			var spell_id: String = actors[id].advance_cast(delta)
			if spell_id != "":
				world.cast(actors[id], id, spell_id)
		world.simulate(actors, delta)
		if world.objective.result == "":
			world.projectiles.step(world, actors, delta)
		world.update_objective(actors, delta)
		for id in talent_requests:
			if world.objective.result == "" and actors.has(id):
				apply_talent(actors[id], talent_requests[id])
		talent_requests.clear()
		for id in stair_cooldowns.keys():
			stair_cooldowns[id] = maxf(0.0, stair_cooldowns[id] - delta)
		for id in stair_requests.keys():
			if world.objective.result == "" and actors.has(id) and stair_cooldowns.get(id, 0.0) <= 0.0 and world.transfer(actors[id], id):
				stair_cooldowns[id] = 0.75
				if multiplayer.has_multiplayer_peer():
					transition.rpc(tick, id, actors[id].floor_id, actors[id].position, world.monster_snapshot())
		stair_requests.clear()
		if tick % 6 == 0 or world.objective.result != "":
			flush_events()
			flush_sounds()
		tick += 1
		if (tick % 3 == 0 or world.objective.result != "") and multiplayer.has_multiplayer_peer():
			var states := {}
			for id in actors:
				states[id] = [actors[id].position, actors[id].heading, actors[id].floor_id, actors[id].health, actors[id].stamina, actors[id].blocking, actors[id].attack_phase, actors[id].hurt_timer, actors[id].swing_hit, actors[id].inventory.state(), actors[id].skills.state(), actors[id].combat_timer, actors[id].mana, actors[id].sprinting, actors[id].cast_id, actors[id].noise_level, actors[id].quiet_walking, actors[id].noise_peak]
			snapshot.rpc(tick, states, world.monster_snapshot(), world.loot.state(), world.projectiles.state(), world.hazards.state(), world.objective.state())
			if world.objective.result != "":
				finish_remote.rpc(world.objective.state())
	if not dedicated and actors.has(local_id):
		var local = actors[local_id]
		var viewed_floor: int = local.floor_id
		feedback.viewed_floor = viewed_floor
		world.visible_floor(viewed_floor)
		var builder = world.floors[viewed_floor].visual_builder
		if builder:
			builder.update_lighting(local.position - world.floors[viewed_floor].position, delta)
		party_panel.refresh(actors, local_id, world)
		update_awareness_hud(local, local_id)
		map_timer -= delta
		if map_timer <= 0:
			minimap.refresh(world, local, actors, yaw)
			map_timer = 0.15
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
			var ability_text: PackedStringArray = []
			for i in range(3):
				var ability: String = local.skills.slots[i]
				var node: Array = local.Skills.Talents.find(ability)
				var cooldown: float = local.skills.cooldowns.get(ability, 0.0)
				ability_text.append("[%d] %s%s" % [i + 1, "Empty" if node.is_empty() else node[2], " %.1fs" % cooldown if cooldown > 0 else ""])
			action_bar.text = "    |    ".join(ability_text)
			if skills_ui and skills_ui.visible:
				skills_ui.refresh(local.skills.state(), world.safe(local))
			stamina_bar.value = local.stamina
			mana_bar.value = local.mana
			if local.camera:
				local.camera.fov = lerpf(local.camera.fov, 85.0 if local.sprinting else 75.0, minf(1.0, delta * 8.0))
			crosshair.modulate = Color("#90df87") if local.swing_hit and local.attack_phase == 2 else Color.WHITE
		if hud:
			var route: Dictionary = world.route_at(local.floor_id, local.position)
			hud.text = World.Routes.NAMES[local.floor_id]
			if not route.is_empty() and local.health > 0:
				hud.text += "  |  " + ("" if route.get("locked", false) else "E: ") + route.label
			var hint: String = world.objective_hint(local, local_id)
			if hint != "":
				hud.text += "  |  " + hint
			update_objective_hud(local_id)
			if local.health <= 0:
				hud.text += "\nParty defeated"
			else:
				hud.text += "\nLMB: Attack | RMB: Block | Shift: Sprint | Ctrl: Quiet | I: Inventory"
				var aggro := 0
				for mob in world.monsters.values():
					if mob.health > 0 and mob.floor == local.floor_id and mob.target == local_id:
						aggro += 1
				if aggro > 0:
					hud.text += " | Aggro: %d" % aggro
				var drop_id: int = world.loot.nearest(local)
				if drop_id != 0:
					hud.text += "\nF: Pick up " + Catalog.get_item(world.loot.drops[drop_id].item).title

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, angle: float, block: bool, sprint: bool, quiet: bool) -> void:
	if not multiplayer.is_server() or not move.is_finite() or not is_finite(angle):
		return
	var id := multiplayer.get_remote_sender_id()
	if actors.has(id):
		actors[id].direction = move.limit_length()
		actors[id].heading = angle
		actors[id].wants_block = block
		actors[id].wants_sprint = sprint
		actors[id].wants_quiet = quiet

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary, traps: Dictionary, objective_data: Dictionary) -> void:
	if not is_instance_valid(world) or sequence < received_tick:
		return
	received_tick = sequence
	world.apply_monsters(mobs)
	world.loot.apply(drops)
	world.projectiles.apply(shots)
	world.hazards.apply(traps)
	world.objective.apply(objective_data)
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
			actors[id].noise_level = states[id][15]
			actors[id].quiet_walking = states[id][16]
			actors[id].noise_peak = states[id][17]
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
		var drop_id: int = world.loot.nearest(actor)
		if drop_id != 0:
			var title: String = Catalog.get_item(world.loot.drops[drop_id].item).title
			if world.loot.pickup(actor):
				world.journal.add("Loot", "%s picks up %s" % [actor.display_name, title])
	elif drop:
		var item: String = actor.inventory.remove(index)
		if not item.is_empty():
			var at: Vector3 = actor.position
			at.y = world.floors[actor.floor_id].position.y + 0.3
			world.loot.spawn(item, actor.floor_id, at)
			world.journal.add("Loot", "%s drops %s" % [actor.display_name, Catalog.get_item(item).title])
	else:
		if index >= 0 and index < actor.inventory.items.size() and Catalog.get_item(actor.inventory.items[index]).kind == "scroll" and not world.safe(actor):
			return
		if index < 0 or index >= actor.inventory.items.size():
			return
		var item = Catalog.get_item(actor.inventory.items[index])
		if item.kind == "distraction":
			var peer = actors.find_key(actor)
			if peer != null:
				world.throw_distraction(actor, index, peer)
			return
		var before: float = actor.health
		if actor.use_item(index):
			world.journal.add("Loot", "%s %s %s" % [actor.display_name, "reads" if item.kind == "scroll" else ("uses" if item.kind == "consumable" else "equips"), item.title])
			if actor.health > before:
				world.journal.add("Combat", "%s restores %s HP" % [actor.display_name, Numbers.number(actor.health - before)], actor.floor_id, actor.position + Vector3.UP, "+%d" % roundi(actor.health - before), "heal", int(actor.name))

func _skill_action(index: int, value: int) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_unique_id()
		if is_instance_valid(world) and world.objective.result == "" and actors.has(id) and actors[id].health > 0:
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
		if actors.has(peer) and id.length() <= 64 and action in ["buy", "slot", "activate", "discover", "drop_jewel", "throw_stone"]:
			talent_requests[peer] = [action, id, index]

func apply_talent(actor, request: Array) -> void:
	if actor.health <= 0:
		return
	if request[0] == "activate":
		var slot: int = request[2]
		if slot < 0 or slot >= actor.skills.SLOT_COUNT:
			return
		var ability: String = actor.skills.slots[slot]
		if ability in ["taunt", "fade"]:
			var peer = actors.find_key(actor)
			if peer != null:
				world.threat_ability(actor, peer, ability)
		else:
			actor.activate(slot)
		return
	if request[0] == "throw_stone":
		var peer = actors.find_key(actor)
		if peer != null:
			world.throw_distraction(actor, actor.inventory.items.find("noise_stone"), peer)
		return
	if request[0] == "drop_jewel":
		var peer = actors.find_key(actor)
		if peer != null:
			world.release_jewel(actor, peer)
		return
	if request[0] == "discover":
		world.discover(actor)
		return
	if not world.safe(actor):
		return
	match request[0]:
		"buy":
			if actor.buy_talent(request[1]):
				world.journal.add("XP", "%s learns %s" % [actor.display_name, actor.Skills.Talents.find(request[1])[2]])
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
	party_names.clear()
	voice_tokens.clear()
	voice_peaks.clear()
	voice_timer = 0.0
	pending_profiles.clear()
	next_party_number = 1
	if log_panel:
		log_panel.reset()
		feedback.reset()
	world = World.new()
	add_child(world)
	world.build(seed_value, not dedicated and DisplayServer.get_name() != "headless", size)

@rpc("authority", "call_remote", "reliable")
func initialize_expedition(seed_value: int, size: int) -> void:
	build_expedition(seed_value, size)
	_start()

func update_objective_hud(local_id: int) -> void:
	var goal = world.objective
	var message := "Runes: %d/2" % goal.runes.size()
	if not goal.gate_open():
		message += "\nDefeat the branch bosses"
	elif not goal.guardian_defeated:
		message += "\nEnter the Jewel Sanctuary"
	elif not goal.started:
		message += "\nClaim the Jewel"
	else:
		message = "ESCAPE — Pursuit %d/3" % goal.pressure()
		message += "\n" + ("You carry the Jewel" if goal.carrier == local_id else ("Jewel carried by a teammate" if goal.carrier != 0 else "Jewel dropped: " + World.Routes.NAMES[goal.jewel_floor]))
		message += "\nReturn to Dungeon 1 exit [E]"
	objective_label.text = message

@rpc("authority", "call_remote", "reliable")
func finish_remote(data: Dictionary) -> void:
	if is_instance_valid(world):
		world.objective.apply(data)
		show_result()

func show_result() -> void:
	if dedicated or result_shown:
		return
	result_shown = true
	voice_chat.reset()
	inventory_ui.hide()
	skills_ui.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = "JEWEL RECOVERED\nExpedition victory!" if world.objective.result == "victory" else "EXPEDITION LOST\nA party member has fallen."
	result_screen.show()

func flush_events() -> void:
	var events: Array = world.journal.drain()
	if events.is_empty():
		return
	if not dedicated:
		display_events(events)
	if multiplayer.has_multiplayer_peer():
		combat_events.rpc(events)

@rpc("authority", "call_remote", "reliable")
func combat_events(events: Array) -> void:
	if is_instance_valid(world):
		display_events(events)

@rpc("authority", "call_remote", "reliable")
func log_history(events: Array) -> void:
	if log_panel:
		log_panel.receive(events)

func display_events(events: Array) -> void:
	if not log_panel or not feedback:
		return
	var last: int = log_panel.last_id
	log_panel.receive(events)
	var local_id := multiplayer.get_unique_id()
	if actors.has(local_id):
		feedback.viewed_floor = actors[local_id].floor_id
	for event in events:
		if event.id > last:
			feedback.show_event(event, local_id)

func update_awareness_hud(local, local_id: int) -> void:
	var level: float = local.noise_level
	var mode := "Quiet walk" if local.quiet_walking else ("Sprint" if local.sprinting else "Walk")
	noise_label.text = "%s | Noise %s" % [mode, Numbers.number(level)]
	noise_meter.update_levels(level, local.noise_peak)
	var mob: Dictionary = world.focused_enemy(local, yaw)
	if mob.is_empty():
		target_label.text = ""
		return
	var target_name := "None"
	if actors.has(mob.target):
		target_name = actors[mob.target].display_name
	var mine: float = mob.threat.get(local_id, 0.0)
	var current: float = mob.threat.get(mob.target, 0.0)
	target_label.text = "%s | %s\n%d/%d HP%s\nTarget: %s | Threat %s / %s" % [World.Bestiary.stats(mob.kind)[0], world.awareness_name(mob), ceili(mob.health), ceili(mob.max_health), world.status_summary(mob), target_name, Numbers.number(mine), Numbers.number(current)]

func menu_profile() -> Array:
	return [Profiles.clean_name(character_name.text), species_selector.selected, background_selector.selected]

func refresh_profile_details() -> void:
	profile_details.text = "%s\n%s" % [Profiles.SPECIES[species_selector.selected][1], Profiles.BACKGROUNDS[background_selector.selected][1]]

func flush_sounds() -> void:
	var events: Array = world.drain_sounds()
	if events.is_empty():
		return
	for id in actors:
		var actor = actors[id]
		var nearby: Array = []
		for event in events:
			if event[0] == actor.floor_id and world.horizontal_distance(event[1], actor.position) <= float(event[2]):
				nearby.append(event)
		if nearby.is_empty():
			continue
		if not dedicated and id == multiplayer.get_unique_id():
			receive_sounds(nearby)
		elif multiplayer.has_multiplayer_peer():
			receive_sounds.rpc_id(id, nearby)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_sounds(events: Array) -> void:
	if not dungeon_audio or not is_instance_valid(world):
		return
	var id := multiplayer.get_unique_id()
	if actors.has(id):
		dungeon_audio.hear(events, world, actors[id])

func update_voice(actor, delta: float) -> void:
	var enabled: bool = voice_mode != 0 and not voice_muted and get_window().has_focus() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and actor.health > 0
	var speaking: bool = enabled and (voice_mode == 2 or Input.is_physical_key_pressed(KEY_V))
	for packet in voice_chat.poll(speaking):
		if multiplayer.is_server():
			accept_voice(multiplayer.get_unique_id(), packet)
		else:
			submit_voice.rpc_id(1, packet)
	voice_chat.advance(delta, actor.floor_id, actors)
	if voice_mode == 0:
		voice_label.text = "MIC OFF"
	elif voice_muted:
		voice_label.text = "MIC MUTED [N]"
	elif speaking:
		voice_label.text = "MIC LIVE | Noise %s [N]" % Numbers.number(voice_chat.level)
	else:
		voice_label.text = "MIC READY [V]"

func advance_voice(delta: float) -> void:
	for id in voice_tokens:
		voice_tokens[id] = minf(8.0, voice_tokens[id] + delta * 60.0)
	voice_timer += delta
	if voice_timer < 0.1:
		return
	voice_timer = 0.0
	for id in voice_peaks:
		if actors.has(id):
			world.voice_noise(actors[id], id, voice_peaks[id])
	voice_peaks.clear()

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func submit_voice(data: PackedByteArray) -> void:
	if multiplayer.is_server():
		accept_voice(multiplayer.get_remote_sender_id(), data)

func accept_voice(id: int, data: PackedByteArray) -> void:
	if not active or world.objective.result != "" or not actors.has(id) or actors[id].health <= 0 or data.size() != VoiceCodec.BYTES:
		return
	var tokens: float = voice_tokens.get(id, 8.0)
	if tokens < 1.0:
		return
	voice_tokens[id] = tokens - 1.0
	var radius := VoiceCodec.radius(data)
	if radius <= 0.0:
		return
	voice_peaks[id] = maxf(radius, voice_peaks.get(id, 0.0))
	var speaker = actors[id]
	for listener_id in actors:
		if listener_id == id or not world.voice_audible(speaker, actors[listener_id], radius):
			continue
		if not dedicated and listener_id == multiplayer.get_unique_id():
			receive_voice(id, speaker.position, speaker.floor_id, radius, data)
		elif multiplayer.has_multiplayer_peer():
			receive_voice.rpc_id(listener_id, id, speaker.position, speaker.floor_id, radius, data)

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func receive_voice(peer: int, at: Vector3, floor_id: int, radius: float, data: PackedByteArray) -> void:
	if not active or not voice_chat or world.objective.result != "":
		return
	var id := multiplayer.get_unique_id()
	if actors.has(id) and actors.has(peer) and actors[id].floor_id == floor_id and actors[peer].floor_id == floor_id:
		voice_chat.receive(peer, at, floor_id, radius, data)
