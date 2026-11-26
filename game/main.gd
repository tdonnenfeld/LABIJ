extends Node3D

const NetMotion = preload("res://game/network/net_motion.gd")
const PlayerSettings = preload("res://game/ui/player_settings.gd")
const EscapeMenu = preload("res://game/ui/escape_menu.gd")
const DisplayControls = preload("res://game/ui/display_controls.gd")
var main_display: VBoxContainer
var settings := PlayerSettings.new()
var escape_menu: Control
var lobby_locked := false
var audio_sliders: Dictionary = {}
const Numbers = preload("res://game/ui/numbers.gd")
const Parchment = preload("res://game/ui/parchment.gd")

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const InventoryUI = preload("res://game/items/inventory_ui.gd")
const SkillsUI = preload("res://game/progression/skills_ui.gd")
const LevelUp = preload("res://game/ui/level_up.gd")
var level_up: PanelContainer
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
const CombatFX = preload("res://game/visuals/combat_fx.gd")
const DamageDirection = preload("res://game/ui/damage_direction.gd")
var combat_fx: Node3D
var damage_direction: Control
var log_panel: PanelContainer
var party_panel: PanelContainer
var feedback: Node3D
var party_names: Dictionary = {}
var next_party_number := 1
var action_bar: HBoxContainer
var action_slots: Array[Label] = []
const Minimap = preload("res://game/ui/minimap.gd")
var minimap: Control
var map_timer := 0.0
const Profiles = preload("res://game/progression/profiles.gd")
const NoiseMeter = preload("res://game/ui/noise_meter.gd")
var noise_meter: Control
const DungeonAudio = preload("res://game/audio/dungeon_audio.gd")
var dungeon_audio: Node3D
const EnvironmentalAudio = preload("res://game/audio/environmental_audio.gd")
const AudioMix = preload("res://game/audio/audio_mix.gd")
var environmental_audio: Node3D
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
var ready_peers: Dictionary = {}
var bootstrapping := false
var connecting := false
var connection_timeout := 0.0
var dungeon_environment: Environment
var atmosphere_floor := -1
var cancel_join_button: Button
var input_age: Dictionary = {}
var local_trigger := false
var selected_profile: Array = ["", 0, 0]
var noise_label: Label
var target_label: Label
const Catalog = preload("res://game/items/catalog.gd")
var inventory_ui: PanelContainer
const PotionBelt = preload("res://game/ui/potion_belt.gd")
var potion_belt: HBoxContainer
const Trade = preload("res://game/items/trade.gd")
const TradeUI = preload("res://game/items/trade_ui.gd")
var trade_book := Trade.new()
var trade_views: Dictionary = {}
var trade_panel: PanelContainer
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
		dungeon_environment = settings
		add_child(environment)
	multiplayer.peer_connected.connect(_peer_joined)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _failed("Connection failed. Check the address and try Join again."))
	multiplayer.server_disconnected.connect(func(): _failed("Disconnected from host. Join again if the expedition is open."))
	if dedicated:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--party-size="):
				party_size = clampi(int(arg.get_slice("=", 1)), 1, 8)
		_host()
	else:
		AudioMix.ensure()
		settings.load_file()
		settings.apply_display(get_window())
		_build_menu()
		var canvas := CanvasLayer.new()
		add_child(canvas)
		var layer := Control.new()
		canvas.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.theme = Parchment.build(false)
		hud = Label.new()
		hud.position = Vector2(16, 12)
		Parchment.plate(hud, 12)
		layer.add_child(hud)
		hud.hide()
		hp_bar = make_bar(layer, Vector2(16, 78), Parchment.HP, "HP")
		stamina_bar = make_bar(layer, Vector2(16, 106), Parchment.STAMINA, "Stamina")
		mana_bar = make_bar(layer, Vector2(16, 134), Parchment.MANA, "Mana")
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
		inventory_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		inventory_ui.offset_left = -450
		inventory_ui.offset_right = 450
		inventory_ui.offset_top = -245
		inventory_ui.offset_bottom = 245
		inventory_ui.action.connect(_inventory_action)
		inventory_ui.moved.connect(_inventory_move)
		inventory_ui.organize.connect(_inventory_organize)
		inventory_ui.equip_slot.connect(_inventory_equip_slot)
		skills_ui = SkillsUI.new()
		layer.add_child(skills_ui)
		skills_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		skills_ui.offset_left = 20
		skills_ui.offset_top = 20
		skills_ui.offset_right = -20
		skills_ui.offset_bottom = -20
		skills_ui.closed.connect(close_skills)
		skills_ui.priority_changed.connect(_skill_action)
		skills_ui.talent_action.connect(_talent_action)
		xp_label = Label.new()
		xp_label.position = Vector2(16, 160)
		Parchment.plate(xp_label, 12)
		layer.add_child(xp_label)
		xp_label.hide()
		objective_label = Label.new()
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Parchment.plate(objective_label, 12)
		layer.add_child(objective_label)
		objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		objective_label.offset_left = -330
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
		party_panel.offset_left = -330
		party_panel.offset_right = -16
		party_panel.offset_top = 92
		party_panel.hide()
		action_bar = HBoxContainer.new()
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(action_bar)
		action_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		action_bar.offset_left = -80
		action_bar.offset_right = 262
		action_bar.offset_top = -64
		action_bar.offset_bottom = -12
		for i in range(3):
			var slot := Label.new()
			slot.custom_minimum_size = Vector2(108, 48)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			Parchment.plate(slot, 12)
			slot.text = "%d · Empty" % (i + 1)
			action_bar.add_child(slot)
			action_slots.append(slot)
		action_bar.hide()
		potion_belt = PotionBelt.new()
		layer.add_child(potion_belt)
		potion_belt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		potion_belt.offset_left = -80
		potion_belt.offset_right = 85
		potion_belt.offset_top = -118
		potion_belt.offset_bottom = -70
		potion_belt.hide()
		noise_label = Label.new()
		noise_label.position = Vector2(16, 184)
		Parchment.plate(noise_label, 12)
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
		Parchment.plate(target_label, 12)
		target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(target_label)
		target_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		target_label.offset_left = -130
		target_label.offset_right = 130
		target_label.offset_top = 12
		target_label.hide()
		minimap = Minimap.new()
		layer.add_child(minimap)
		minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		minimap.offset_left = -202
		minimap.offset_right = -16
		minimap.offset_top = -202
		minimap.offset_bottom = -16
		minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap.hide()
		var popup_layer := Control.new()
		layer.add_child(popup_layer)
		popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dungeon_audio = DungeonAudio.new()
		add_child(dungeon_audio)
		environmental_audio = EnvironmentalAudio.new()
		add_child(environmental_audio)
		voice_chat = ProximityVoice.new()
		add_child(voice_chat)
		feedback = Feedback.new()
		add_child(feedback)
		feedback.local_layer = popup_layer
		combat_fx = CombatFX.new()
		add_child(combat_fx)
		damage_direction = DamageDirection.new()
		layer.add_child(damage_direction)
		damage_direction.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		trade_panel = TradeUI.new()
		layer.add_child(trade_panel)
		trade_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		trade_panel.offset_left = -225
		trade_panel.offset_right = 225
		trade_panel.offset_top = -195
		trade_panel.offset_bottom = 195
		trade_panel.action.connect(_trade_action)
		result_screen = CenterContainer.new()
		layer.add_child(result_screen)
		result_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var panel := PanelContainer.new()
		result_screen.add_child(panel)
		panel.theme = Parchment.build(true)
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 320
		panel.add_child(column)
		result_label = Label.new()
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Parchment.heading(result_label, 23)
		column.add_child(result_label)
		var back := Button.new()
		back.text = "Return to menu"
		column.add_child(back)
		back.pressed.connect(_failed)
		result_screen.hide()
		escape_menu = EscapeMenu.new()
		escape_menu.settings = settings
		layer.add_child(escape_menu)
		escape_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		escape_menu.resume.connect(close_escape_menu)
		escape_menu.voice_changed.connect(set_voice_mode)
		escape_menu.mute_changed.connect(set_voice_muted)
		escape_menu.lobby_lock.connect(set_lobby_locked)
		escape_menu.kick.connect(kick_companion)
		escape_menu.leave.connect(leave_expedition)
		escape_menu.settings_changed.connect(refresh_binding_hints)
		level_up = LevelUp.new()
		layer.add_child(level_up)
		level_up.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		level_up.offset_left = -200
		level_up.offset_right = 200
		level_up.offset_top = 96
		level_up.offset_bottom = 192
		refresh_binding_hints()

func make_bar(layer: Control, at: Vector2, color: Color, caption: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(200, 20)
	bar.max_value = 100
	bar.value = 100
	Parchment.decorate_bar(bar, color)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar)
	var label := Label.new()
	label.text = caption + " 100 / 100"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color("#201813"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.hide()
	return bar

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var page := Control.new()
	menu.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = Parchment.build(true)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1e211d")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	page.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var spread := HBoxContainer.new()
	spread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 16)
	scroll.add_child(spread)
	var left_page := PanelContainer.new()
	left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(left_page)
	var panel := VBoxContainer.new()
	left_page.add_child(panel)
	var title := Label.new()
	title.text = "LABIJ"
	Parchment.heading(title, 32)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE EXPEDITION JOURNAL · FIRST DESCENT"
	subtitle.add_theme_font_size_override("font_size", 12)
	panel.add_child(subtitle)
	panel.add_child(HSeparator.new())
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
	var choices := HBoxContainer.new()
	panel.add_child(choices)
	for entry in [["Solo", _solo], ["Host", _host], ["Join", _join]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(button)
	cancel_join_button = Button.new()
	cancel_join_button.text = "Cancel connection"
	cancel_join_button.pressed.connect(func(): _failed("Connection cancelled."))
	panel.add_child(cancel_join_button)
	cancel_join_button.hide()
	status = Label.new()
	status.text = "Physical movement keys · mouse · Esc opens expedition menu"
	panel.add_child(status)
	var right_page := PanelContainer.new()
	right_page.custom_minimum_size.x = 260
	spread.add_child(right_page)
	var audio_panel := VBoxContainer.new()
	right_page.add_child(audio_panel)
	var audio_title := Label.new()
	audio_title.text = "Field instruments"
	Parchment.heading(audio_title, 21)
	audio_panel.add_child(audio_title)
	for entry in [["Master", "Master", 1.0], ["Effects", AudioMix.EFFECTS, 0.85], ["Ambience", AudioMix.AMBIENCE, 0.65], ["Voice playback", AudioMix.VOICE, 1.0]]:
		add_audio_slider(audio_panel, entry[0], entry[1], entry[2])
	audio_panel.add_child(HSeparator.new())
	main_display = DisplayControls.new()
	main_display.settings = settings
	audio_panel.add_child(main_display)
	var credit := Label.new()
	credit.text = "Fire Loop — Iwan \"qubodup\" Gabovitch\nCC BY 3.0 · see art/audio/CREDITS.md"
	credit.add_theme_font_size_override("font_size", 11)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	audio_panel.add_child(credit)

func add_audio_slider(panel: VBoxContainer, title: String, bus: String, default_value: float) -> void:
	var label := Label.new()
	label.text = title
	panel.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size.x = 210
	slider.value = settings.volumes.get(bus, default_value)
	panel.add_child(slider)
	audio_sliders[bus] = slider
	slider.value_changed.connect(func(value: float): settings.set_volume(bus, value); settings.save_file())

func _start() -> void:
	local_trigger = false
	if not dedicated and not actors.has(multiplayer.get_unique_id()):
		return
	connecting = false
	bootstrapping = false
	connection_timeout = 0.0
	if cancel_join_button:
		cancel_join_button.hide()
	if not dedicated:
		var actor = actors[multiplayer.get_unique_id()]
		actor.direction = Vector2.ZERO
		actor.wants_block = false
		actor.wants_sprint = false
		actor.wants_quiet = false
		yaw = actor.heading
		pitch = actor.look_pitch
		actor.rotation.y = yaw
		if actor.camera:
			actor.camera.make_current()
			actor.camera.rotation.x = pitch
		world.visible_floor(actor.floor_id)
		for id in actors:
			actors[id].visible = id == multiplayer.get_unique_id() or actors[id].floor_id == actor.floor_id
	active = true
	if menu:
		menu.hide()
	if not dedicated:
		if is_instance_valid(escape_menu):
			escape_menu.close_menu()
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
			potion_belt.show()
			noise_label.show()
			noise_meter.show()
			voice_label.show()
			target_label.show()
			minimap.show()

func _solo() -> void:
	if active or connecting:
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	selected_profile = menu_profile()
	party_size = 1
	new_expedition()
	_spawn(1, selected_profile)
	_start()

func _host() -> void:
	if active or connecting:
		return
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
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	new_expedition()
	if not dedicated:
		_spawn(1, selected_profile)
	_start()

func _join() -> void:
	if active or connecting:
		return
	selected_profile = menu_profile()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.text.strip_edges(), PORT)
	if err != OK:
		status.text = "Cannot connect: " + str(err)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	connecting = true
	connection_timeout = 45.0
	cancel_join_button.show()
	multiplayer.multiplayer_peer = peer
	status.text = "Connecting..."

func _connected() -> void:
	status.text = "Generating expedition..."

func _failed(message: String = "Choose Solo, Host or Join") -> void:
	local_trigger = false
	active = false
	connecting = false
	bootstrapping = false
	ready_peers.clear()
	if is_instance_valid(escape_menu):
		escape_menu.close_menu()
	var old_peer := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	if old_peer is ENetMultiplayerPeer:
		old_peer.close()
	input_age.clear()
	connection_timeout = 0.0
	if cancel_join_button:
		cancel_join_button.hide()
	lobby_locked = false
	pending_profiles.clear()
	trade_book.reset()
	trade_views.clear()
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
		level_up.reset()
		objective_label.hide()
		log_panel.hide()
		log_panel.reset()
		party_panel.hide()
		action_bar.hide()
		potion_belt.hide()
		potion_belt.refresh(0)
		trade_panel.hide()
		trade_panel.refresh_state({"id": 0, "notice": ""})
		noise_label.hide()
		noise_meter.hide()
		noise_meter.update_levels(0.0, 0.0)
		voice_label.hide()
		voice_chat.reset()
		target_label.hide()
		minimap.hide()
		minimap.reset()
		feedback.reset()
		combat_fx.reset()
		damage_direction.reset()
		dungeon_audio.reset()
		environmental_audio.reset()
		result_screen.hide()
		damage_flash.color.a = 0.0
	for id in actors.keys():
		_remove(id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu:
		main_display.refresh()
		menu.show()
		status.text = message

func _spawn(id: int, profile: Array = ["", 0, 0]) -> void:
	if actors.has(id):
		return
	var actor := Player.new()
	actor.name = str(id)
	add_child(actor)
	var landing: Vector3 = world.arrival_position(0, world.stair_position(0, false), actors)
	actor.position = landing if landing != Vector3.INF else Vector3.UP
	actor.setup(not dedicated and id == multiplayer.get_unique_id(), not dedicated and DisplayServer.get_name() != "headless")
	actors[id] = actor
	var player_name := Profiles.clean_name(str(profile[0]))
	if multiplayer.is_server() and player_name.is_empty():
		player_name = "Player %d" % next_party_number
	actor.configure_profile(player_name, int(profile[1]), int(profile[2]))
	if not dedicated and id == multiplayer.get_unique_id():
		level_up.reset(actor.skills.character_level())
	if multiplayer.is_server():
		party_names[id] = actor.display_name
		next_party_number += 1
		world.watch_player(actor, id)
		world.journal.add("Party", "%s enters the dungeon" % actor.display_name)

func _remove(id: int) -> void:
	trade_book.cancel(id, "Companion left.")
	trade_views.erase(id)
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)
	input_age.erase(id)
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
	if not active or not is_instance_valid(world):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if lobby_locked or world.objective.started or world.objective.result != "" or reserved_slots() >= party_size:
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
	if not pending_profiles.has(id) or actors.has(id):
		return
	pending_profiles.erase(id)
	if lobby_locked or not Profiles.valid(species, background) or chosen_name.length() > 64 or world.objective.started or world.objective.result != "" or actors.size() >= party_size:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	initialize_expedition.rpc_id(id, expedition_seed, party_size)
	for existing in actors.keys():
		var member = actors[existing]
		spawn_remote.rpc_id(id, existing, member.floor_id, member.position, member.display_name, member.species_id, member.background_id)
	_spawn(id, [chosen_name, species, background])
	for other in actors:
		if other != 1:
			spawn_remote.rpc_id(other, id, 0, actors[id].position, actors[id].display_name, species, background)
	log_history.rpc_id(id, world.journal.history)
	lobby_state.rpc_id(id, lobby_locked)
	initial_state.rpc_id(id, tick, player_states(), world.monster_snapshot(), world.loot.state(), world.projectiles.state(), world.hazards.state(), world.objective.state(), world.secret_state())
	pending_profiles[id] = 30.0

func _peer_left(id: int) -> void:
	if multiplayer.is_server():
		pending_profiles.erase(id)
		ready_peers.erase(id)
		if not actors.has(id):
			return
		if is_instance_valid(world) and actors.has(id):
			world.release_jewel(actors[id], id)
			world.journal.add("Party", "%s disconnects" % actors[id].display_name)
		_remove(id)
		if is_instance_valid(world) and actors.is_empty() and world.objective.started and world.objective.result == "":
			world.objective.result = "defeat"
		for other in actors:
			if other != 1:
				remove_remote.rpc_id(other, id)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int, floor_id: int, at: Vector3, player_name: String, species: int, background: int) -> void:
	_spawn(id, [player_name, species, background])
	actors[id].floor_id = floor_id
	actors[id].position = at
	NetMotion.reset(actors[id])
	actors[id].display_name = player_name

@rpc("authority", "call_remote", "reliable")
func remove_remote(id: int) -> void:
	_remove(id)

func _input(event: InputEvent) -> void:
	if not active or dedicated or not is_instance_valid(escape_menu) or world.objective.result != "":
		return
	if escape_menu.visible and escape_menu.capture(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if escape_menu.visible:
			close_escape_menu()
		else:
			open_escape_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not active or dedicated or world.objective.result != "" or escape_menu.visible:
		return
	if settings.matches(event, "mute"):
		set_voice_muted(not voice_muted)
		return
	if settings.matches(event, "map"):
		minimap.visible = not minimap.visible
		return
	if settings.matches(event, "log"):
		log_panel.visible = not log_panel.visible
		return
	if settings.matches(event, "trade"):
		if trade_panel.visible:
			close_trade()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			inventory_ui.hide()
			skills_ui.hide()
			trade_panel.show()
			trade_panel.move_to_front()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if settings.matches(event, "inventory"):
		close_trade()
		skills_ui.hide()
		inventory_ui.visible = not inventory_ui.visible
		if inventory_ui.visible:
			inventory_ui.move_to_front()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_ui.visible else Input.MOUSE_MODE_CAPTURED
		return
	if settings.matches(event, "talents"):
		close_trade()
		inventory_ui.hide()
		skills_ui.visible = not skills_ui.visible
		if skills_ui.visible:
			skills_ui.move_to_front()
			var id := multiplayer.get_unique_id()
			if actors.has(id):
				skills_ui.refresh(actors[id].skills.state(), world.safe(actors[id]))
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if skills_ui.visible else Input.MOUSE_MODE_CAPTURED
		return
	if trade_panel.visible or skills_ui.visible:
		return
	if inventory_ui.visible:
		if settings.matches(event, "rotate"):
			inventory_ui.organize_selected("rotate")
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if settings.matches(event, "interact"):
		if multiplayer.is_server():
			stair_requests[multiplayer.get_unique_id()] = true
		else:
			request_stairs.rpc_id(1)
	elif settings.matches(event, "pickup"):
		if multiplayer.is_server():
			item_requests[multiplayer.get_unique_id()] = [-1, false]
		else:
			request_item.rpc_id(1, -1, false)
	elif settings.matches(event, "throw_stone"):
		_talent_action("throw_stone", "", 0)
	elif settings.matches(event, "drop_jewel"):
		_talent_action("drop_jewel", "", 0)
	elif settings.matches(event, "discover"):
		_talent_action("discover", "", 0)
	elif settings.matches(event, "attack"):
		set_local_trigger(true, false)
		return
	elif event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.002 * settings.sensitivity
		pitch = clampf(pitch - event.relative.y * 0.002 * settings.sensitivity, -1.4, 1.4)
	else:
		for i in range(4):
			if settings.matches(event, "belt%d" % (i + 1)):
				if multiplayer.is_server():
					use_belt(multiplayer.get_unique_id(), i)
				else:
					request_belt.rpc_id(1, i)
				return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_0:
			_talent_action("select_spell", "", -1)
			return
		for i in range(3):
			if settings.matches(event, "ability%d" % (i + 1)):
				var actor = actors.get(multiplayer.get_unique_id())
				if actor != null and not actor.Spells.get_spell(actor.skills.slots[i]).is_empty() and not Input.is_physical_key_pressed(KEY_ALT):
					_talent_action("select_spell", "", i)
				else:
					_talent_action("activate", "", i)
				return

func set_local_trigger(held: bool, cancel: bool) -> void:
	if local_trigger == held:
		return
	local_trigger = held
	if multiplayer.is_server():
		var actor = actors.get(multiplayer.get_unique_id())
		if actor != null:
			actor.set_trigger(held, cancel)
	else:
		request_trigger.rpc_id(1, held, cancel)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if world.objective.result != "":
		show_result()
		return
	var local_id := multiplayer.get_unique_id()
	if not dedicated and actors.has(local_id):
		var move := Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not escape_menu.visible and get_window().has_focus():
			move.x = float(settings.pressed("right")) - float(settings.pressed("left"))
			move.y = float(settings.pressed("back")) - float(settings.pressed("forward"))
		var actor = actors[local_id]
		update_voice(actor, delta)
		if actor.camera:
			actor.camera.rotation.x = pitch
		actor.rotation.y = yaw
		var enabled := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not escape_menu.visible and get_window().has_focus()
		var block := enabled and settings.pressed("block")
		var held := enabled and settings.pressed("attack")
		if held != local_trigger:
			set_local_trigger(held, not enabled)
		var sprint := enabled and settings.pressed("sprint")
		var quiet := enabled and settings.pressed("quiet")
		if multiplayer.is_server():
			actor.aiming = block and actor.ranged_mode()
			actor.wants_block = block and not actor.ranged_mode()
			actor.wants_sprint = sprint
			actor.wants_quiet = quiet
			actor.direction = move.limit_length()
			actor.heading = yaw
			actor.look_pitch = pitch
		else:
			submit_input.rpc_id(1, move, yaw, block, sprint, quiet, pitch)
	if multiplayer.is_server():
		advance_voice(delta)
		for peer in ready_peers:
			if not actors.has(peer):
				continue
			input_age[peer] = float(input_age.get(peer, 0.0)) + delta
			if input_age[peer] > 0.35:
				actors[peer].direction = Vector2.ZERO
				actors[peer].wants_block = false
				actors[peer].wants_sprint = false
				actors[peer].wants_quiet = false
				actors[peer].aiming = false
				actors[peer].set_trigger(false, true)
		for id in pending_profiles.keys():
			pending_profiles[id] -= delta
			if pending_profiles[id] <= 0:
				pending_profiles.erase(id)
				if actors.has(id):
					_peer_left(id)
				multiplayer.multiplayer_peer.disconnect_peer(id)
		for id in attack_requests.keys():
			if actors.has(id):
				actors[id].begin_attack()
		attack_requests.clear()
		for id in item_requests:
			if actors.has(id):
				var request: Array = item_requests[id]
				if request[0] == -1 or (request.size() == 3 and request[2] == actors[id].inventory.revision):
					apply_item_action(actors[id], request[0], request[1])
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
				world.cast(actors[id], id, spell_id, actors)
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
			if world.objective.result == "" and actors.has(id) and stair_cooldowns.get(id, 0.0) <= 0.0 and world.transfer(actors[id], id, actors):
				stair_cooldowns[id] = 0.75
				for peer in ready_peers:
					transition.rpc_id(peer, tick, id, actors[id].floor_id, actors[id].position, world.monster_snapshot(), world.secret_state())
		stair_requests.clear()
		trade_book.sweep(actors, delta)
		if world.objective.result == "":
			publish_trade_views()
		else:
			trade_book.reset()
		if tick % 6 == 0 or world.objective.result != "":
			flush_events()
			flush_sounds()
		tick += 1
		if (tick % 3 == 0 or world.objective.result != "") and not ready_peers.is_empty():
			var states := player_states()
			var mobs: Dictionary = world.monster_snapshot()
			var drops: Dictionary = world.loot.state()
			var shots: Dictionary = world.projectiles.state()
			var traps: Dictionary = world.hazards.state()
			var objective_data: Dictionary = world.objective.state()
			var secrets: Array = world.secret_state()
			for peer in ready_peers:
				snapshot.rpc_id(peer, tick, states, mobs, drops, shots, traps, objective_data, secrets)
				if world.objective.result != "":
					finish_remote.rpc_id(peer, objective_data)

	if not dedicated and actors.has(local_id):
		var local = actors[local_id]
		var viewed_floor: int = local.floor_id
		feedback.viewed_floor = viewed_floor
		combat_fx.viewed_floor = viewed_floor
		world.visible_floor(viewed_floor)
		if dungeon_environment and atmosphere_floor != viewed_floor:
			atmosphere_floor = viewed_floor
			dungeon_environment.fog_light_color = [Color("#252a25"), Color("#292625"), Color("#213a42"), Color("#393126"), Color("#282c3a"), Color("#422923"), Color("#393323")][viewed_floor]
			dungeon_environment.fog_density = 0.045 if viewed_floor == 2 else 0.027
		environmental_audio.update_environment(world.floors[viewed_floor], local, delta)
		var builder = world.floors[viewed_floor].visual_builder
		if builder:
			builder.update_lighting(local.position - world.floors[viewed_floor].position, delta)
		party_panel.refresh(actors, local_id, world)
		if escape_menu.visible:
			refresh_lobby_menu()
		update_awareness_hud(local, local_id)
		map_timer -= delta
		if map_timer <= 0:
			minimap.refresh(world, local, actors, yaw)
			map_timer = 0.15
		for id in actors:
			actors[id].visible = id == local_id or (actors[id].floor_id == viewed_floor)
		if inventory_ui:
			inventory_ui.refresh(local.inventory.state())
		potion_belt.refresh(local.inventory.belt)
		if trade_panel.visible:
			trade_panel.refresh_inventory(local, local_id, actors)
		if damage_flash:
			damage_flash.color.a = minf(0.3, local.hurt_timer)
		if hp_bar:
			hp_bar.max_value = local.max_health()
			hp_bar.value = local.health
			var character_level: int = local.skills.character_level()
			xp_label.text = "Level %d · %d XP" % [character_level, local.skills.total_xp]
			level_up.observe(character_level, settings.label("talents"))
			for i in range(3):
				var ability: String = local.skills.slots[i]
				var node: Array = local.Skills.Talents.find(ability)
				var cooldown: float = local.skills.cooldowns.get(ability, 0.0)
				var slot := action_slots[i]
				slot.text = "%s · %s\n%s" % [settings.label("ability%d" % (i + 1)), "Empty" if node.is_empty() else node[2], "%.1fs" % cooldown if cooldown > 0 else ("—" if node.is_empty() else "Ready")]
				slot.modulate = Color("#b8a88b") if cooldown > 0 else Color.WHITE
			if skills_ui and skills_ui.visible:
				skills_ui.refresh(local.skills.state(), world.safe(local))
			stamina_bar.value = local.stamina
			mana_bar.value = local.mana
			hp_bar.get_child(0).text = "HP  %d / %d" % [ceili(local.health), ceili(local.max_health())]
			stamina_bar.get_child(0).text = "Stamina  %d / %d" % [ceili(local.stamina), int(stamina_bar.max_value)]
			mana_bar.get_child(0).text = "Mana  %d / %d" % [ceili(local.mana), int(mana_bar.max_value)]
			if local.camera:
				local.camera.fov = lerpf(local.camera.fov, 52.0 if local.aiming else (85.0 if local.sprinting else 75.0), minf(1.0, delta * 8.0))
			crosshair.modulate = Color("#90df87") if local.swing_hit and local.attack_phase == 2 else Color.WHITE
		if hud:
			var route: Dictionary = world.route_at(local.floor_id, local.position)
			hud.text = World.Routes.NAMES[local.floor_id]
			if not route.is_empty() and local.health > 0:
				hud.text += "  |  " + ("" if route.get("locked", false) else settings.label("interact") + ": ") + route.label
			if world.secret_near(local):
				hud.text += "  |  %s: Inspect loose masonry" % settings.label("interact")
			var hint: String = world.objective_hint(local, local_id)
			if local.selected_spell != "":
				hint += "\nSpell: %s · LMB cast · 0 weapon" % local.selected_spell.capitalize()
			elif local.bow_drawing:
				hint += "\nDraw: %d%%" % roundi(local.bow_charge * 100.0)
			if hint != "":
				hud.text += "  |  " + hint.replace("E:", settings.label("interact") + ":").replace("G:", settings.label("drop_jewel") + ":")
			update_objective_hud(local_id)
			if local.health <= 0:
				hud.text += "\nParty defeated"
			else:
				hud.text += "\n%s: Inventory · %s: Talents · %s: Trade" % [settings.label("inventory"), settings.label("talents"), settings.label("trade")]
				if trade_panel.session.get("incoming", false):
					hud.text += "  ·  Trade invitation!"
				if Catalog.get_item(local.inventory.weapon).projectile_speed > 0:
					hud.text += "  ·  Arrows: %d" % local.inventory.count("arrows")
				var aggro := 0
				for mob in world.monsters.values():
					if mob.health > 0 and mob.floor == local.floor_id and mob.target == local_id:
						aggro += 1
				if aggro > 0:
					hud.text += " | Aggro: %d" % aggro
				var drop_id: int = world.loot.nearest(local)
				if drop_id != 0:
					hud.text += "\n%s: Pick up " % settings.label("pickup") + Catalog.get_item(world.loot.drops[drop_id].item).title
					if world.loot.drops[drop_id].amount > 1:
						hud.text += " ×%d" % world.loot.drops[drop_id].amount

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, angle: float, block: bool, sprint: bool, quiet: bool, vertical: float = 0.0) -> void:
	if not multiplayer.is_server() or not move.is_finite() or not is_finite(angle) or not is_finite(vertical):
		return
	var id := multiplayer.get_remote_sender_id()
	if remote_gameplay_ready(id):
		input_age[id] = 0.0
		actors[id].direction = move.limit_length()
		actors[id].heading = wrapf(angle, -PI, PI)
		actors[id].look_pitch = clampf(vertical, -1.4, 1.4)
		actors[id].aiming = block and actors[id].ranged_mode()
		actors[id].wants_block = block and not actors[id].ranged_mode()
		actors[id].wants_sprint = sprint
		actors[id].wants_quiet = quiet

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary, traps: Dictionary, objective_data: Dictionary, secrets: Array = []) -> void:
	if not active or not is_instance_valid(world) or sequence < received_tick:
		return
	apply_snapshot(sequence, states, mobs, drops, shots, traps, objective_data, secrets, true)

func apply_snapshot(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary, traps: Dictionary, objective_data: Dictionary, secrets: Array, smooth: bool) -> void:
	received_tick = sequence
	world.apply_monsters(mobs, smooth)
	world.loot.apply(drops)
	world.projectiles.apply(shots, smooth)
	world.hazards.apply(traps)
	world.objective.apply(objective_data)
	world.apply_secrets(secrets)
	for id in states:
		if actors.has(id):
			var actor = actors[id]
			var snap: bool = actor.floor_id != states[id][2] or actor.health <= 0 or states[id][3] <= 0
			NetMotion.receive(actor, states[id][0], states[id][1], snap or not smooth, id != multiplayer.get_unique_id() or not smooth)
			actor.heading = states[id][1]
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
			if states[id].size() > 18:
				actor.look_pitch = states[id][18]
			if states[id].size() > 22:
				actor.selected_spell = states[id][19]
				actor.aiming = states[id][20]
				actor.bow_charge = states[id][21]
				actor.bow_drawing = states[id][22]
			actors[id].collision_layer = 2 if actors[id].health > 0 else 0
			actors[id].collision_mask = 7 if actors[id].health > 0 else 0

@rpc("any_peer", "call_remote", "reliable")
func request_stairs() -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id):
			stair_requests[id] = true

@rpc("authority", "call_remote", "reliable")
func transition(sequence: int, id: int, floor_id: int, at: Vector3, mobs: Dictionary, secrets: Array = []) -> void:
	if sequence < received_tick:
		return
	received_tick = sequence
	if actors.has(id):
		actors[id].floor_id = floor_id
		actors[id].position = at
		NetMotion.reset(actors[id])
	world.apply_monsters(mobs)
	world.apply_secrets(secrets)

@rpc("any_peer", "call_remote", "reliable")
func request_trigger(held: bool, cancel: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if remote_gameplay_ready(id):
		actors[id].set_trigger(held, cancel)

@rpc("any_peer", "call_remote", "reliable")
func request_attack() -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id) and not actors[id].ranged_mode():
			attack_requests[id] = true

func _inventory_action(index: int, drop: bool) -> void:
	var revision: int = inventory_ui.state_data[6]
	if multiplayer.is_server():
		item_requests[multiplayer.get_unique_id()] = [index, drop, revision]
	else:
		request_item.rpc_id(1, index, drop, revision)

func _inventory_move(index: int, at: Vector2i, split: bool, revision: int) -> void:
	if multiplayer.is_server():
		apply_inventory_move(multiplayer.get_unique_id(), index, at, split, revision)
	else:
		request_inventory_move.rpc_id(1, index, at, split, revision)

@rpc("any_peer", "call_remote", "reliable")
func request_inventory_move(index: int, at: Vector2i, split: bool, revision: int) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		apply_inventory_move(multiplayer.get_remote_sender_id(), index, at, split, revision)

func apply_inventory_move(id: int, index: int, at: Vector2i, split: bool, revision: int) -> void:
	if not active or world.objective.result != "" or not actors.has(id):
		return
	var actor = actors[id]
	if actor.health > 0 and actor.attack_phase == 0 and actor.cast_id == "" and actor.inventory.revision == revision:
		var worn: bool = actor.inventory.is_equipped(index)
		if actor.inventory.move_item(index, at, split) and worn:
			actor.empowered = ""
			if actor.inventory.shield_index < 0:
				actor.blocking = false

@rpc("any_peer", "call_remote", "reliable")
func request_item(index: int, drop: bool, revision: int = -1) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		var id := multiplayer.get_remote_sender_id()
		if actors.has(id) and index >= -1 and index < actors[id].inventory.items.size():
			item_requests[id] = [index, drop, revision]

func apply_item_action(actor, index: int, drop: bool) -> void:
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "":
		return
	if index == -1:
		var drop_id: int = world.loot.nearest(actor)
		if drop_id != 0:
			var title: String = Catalog.get_item(world.loot.drops[drop_id].item).title
			var amount: int = world.loot.drops[drop_id].amount
			if amount > 1:
				title += " ×%d" % amount
			if world.loot.pickup(actor):
				world.sound(actor.floor_id, actor.position, 4.0, "pickup")
				world.journal.add("Loot", "%s picks up %s" % [actor.display_name, title])
	elif drop:
		var amount: int = actor.inventory.quantity(index)
		var item: String = actor.inventory.remove_stack(index)
		if not item.is_empty():
			var at: Vector3 = actor.position
			at.y = world.floors[actor.floor_id].position.y + 0.3
			world.loot.spawn(item, actor.floor_id, at, amount)
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
			world.sound(actor.floor_id, actor.position, 4.0, "scroll" if item.kind == "scroll" else ("potion" if item.kind == "consumable" else "equip"))
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
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
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
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		var peer := multiplayer.get_remote_sender_id()
		if actors.has(peer) and id.length() <= 64 and action in ["buy", "slot", "activate", "select_spell", "discover", "drop_jewel", "throw_stone"]:
			talent_requests[peer] = [action, id, index]

func apply_talent(actor, request: Array) -> void:
	if actor.health <= 0:
		return
	if request[0] == "select_spell":
		actor.set_trigger(false, true)
		actor.select_spell(request[2])
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
	active = false
	ready_peers.clear()
	input_age.clear()
	for id in actors.keys():
		_remove(id)
	tick = 0
	received_tick = -1
	map_timer = 0.0
	yaw = 0.0
	pitch = 0.0
	result_shown = false
	attack_requests.clear()
	item_requests.clear()
	talent_requests.clear()
	stair_requests.clear()
	stair_cooldowns.clear()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	expedition_seed = seed_value
	party_size = size
	lobby_locked = false
	party_names.clear()
	trade_book.reset()
	trade_views.clear()
	voice_tokens.clear()
	voice_peaks.clear()
	voice_timer = 0.0
	pending_profiles.clear()
	next_party_number = 1
	if log_panel:
		log_panel.reset()
		feedback.reset()
		combat_fx.reset()
		damage_direction.reset()
	world = World.new()
	add_child(world)
	world.build(seed_value, not dedicated and DisplayServer.get_name() != "headless", size)

@rpc("authority", "call_remote", "reliable")
func initialize_expedition(seed_value: int, size: int) -> void:
	bootstrapping = true
	build_expedition(seed_value, size)
	if status:
		status.text = "Synchronizing expedition..."

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
		message += "\nReturn to Dungeon 1 exit [%s]" % settings.label("interact")
	if actors.has(local_id):
		if actors[local_id].health <= 0:
			message += "\nDOWNED — wait for a companion"
		else:
			for companion in actors.values():
				if companion.health <= 0 and companion.floor_id == actors[local_id].floor_id:
					message += "\nRevive nearby companion [%s] when safe" % settings.label("interact")
					break
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
	level_up.reset()
	if is_instance_valid(escape_menu):
		escape_menu.close_menu()
	voice_chat.reset()
	environmental_audio.reset()
	inventory_ui.hide()
	skills_ui.hide()
	potion_belt.hide()
	trade_panel.hide()
	trade_panel.refresh_state({"id": 0, "notice": ""})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = "JEWEL RECOVERED\nExpedition victory!" if world.objective.result == "victory" else "EXPEDITION LOST\nThe party has fallen."
	result_screen.show()

func flush_events() -> void:
	var events: Array = world.journal.drain()
	if events.is_empty():
		return
	if not dedicated:
		display_events(events)
	for peer in ready_peers:
		combat_events.rpc_id(peer, events)

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
			if event.target == local_id and event.style in ["incoming", "blocked"]:
				damage_direction.hit(event.get("source", Vector3.INF), event.style == "blocked")
			if DisplayServer.get_name() != "headless" and event.style == "lightning":
				combat_fx.lightning(event.source, event.position, event.floor, event.id)
			elif DisplayServer.get_name() != "headless" and event.target != local_id:
				combat_fx.burst(event.position - Vector3.UP * 0.35, event.floor, event.style, event.id)

func update_awareness_hud(local, local_id: int) -> void:
	var level: float = local.noise_level
	var mode := "Quiet walk" if local.quiet_walking else ("Sprint" if local.sprinting else "Walk")
	noise_label.text = "%s | Noise %s" % [mode, Numbers.number(level)]
	noise_meter.update_levels(level, local.noise_peak)
	var mob: Dictionary = world.focused_enemy(local, yaw)
	if mob.is_empty():
		target_label.text = ""
		target_label.hide()
		return
	target_label.show()
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
		elif ready_peers.has(id):
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
	var speaking: bool = enabled and (voice_mode == 2 or settings.pressed("voice"))
	for packet in voice_chat.poll(speaking):
		if multiplayer.is_server():
			accept_voice(multiplayer.get_unique_id(), packet)
		else:
			submit_voice.rpc_id(1, packet)
	voice_chat.advance(delta, actor.floor_id, actors)
	if voice_mode == 0:
		voice_label.text = "MIC OFF"
	elif voice_muted:
		voice_label.text = "MIC MUTED [%s]" % settings.label("mute")
	elif speaking:
		voice_label.text = "MIC LIVE | Noise %s [%s]" % [Numbers.number(voice_chat.level), settings.label("mute")]
	else:
		voice_label.text = "MIC READY [%s]" % settings.label("voice")

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
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
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
		elif ready_peers.has(listener_id):
			receive_voice.rpc_id(listener_id, id, speaker.position, speaker.floor_id, radius, data)

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func receive_voice(peer: int, at: Vector3, floor_id: int, radius: float, data: PackedByteArray) -> void:
	if not active or not voice_chat or world.objective.result != "":
		return
	var id := multiplayer.get_unique_id()
	if actors.has(id) and actors.has(peer) and actors[id].floor_id == floor_id and actors[peer].floor_id == floor_id:
		voice_chat.receive(peer, at, floor_id, radius, data)

func _inventory_organize(operation: String, index: int, revision: int) -> void:
	if multiplayer.is_server():
		apply_inventory_organize(multiplayer.get_unique_id(), operation, index, revision)
	else:
		request_inventory_organize.rpc_id(1, operation, index, revision)

@rpc("any_peer", "call_remote", "reliable")
func request_inventory_organize(operation: String, index: int, revision: int) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		apply_inventory_organize(multiplayer.get_remote_sender_id(), operation, index, revision)

func apply_inventory_organize(id: int, operation: String, index: int, revision: int) -> void:
	if not active or world.objective.result != "" or not actors.has(id):
		return
	var actor = actors[id]
	if actor.health <= 0 or actor.attack_phase != 0 or actor.cast_id != "" or actor.inventory.revision != revision:
		return
	match operation:
		"rotate": actor.inventory.rotate_item(index)
		"sort": actor.inventory.sort_items()
		"load": actor.inventory.load_belt(index)
		"unload": actor.inventory.unload_belt()
		"equip":
			if actor.inventory.equip(index):
				world.sound(actor.floor_id, actor.position, 4.0, "equip")
				actor.empowered = ""
		"unequip":
			if actor.inventory.unequip(index):
				actor.empowered = ""
				if actor.inventory.shield_index < 0:
					actor.blocking = false

@rpc("any_peer", "call_remote", "reliable")
func request_belt(slot: int) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		use_belt(multiplayer.get_remote_sender_id(), slot)

func use_belt(id: int, slot: int) -> void:
	if not active or world.objective.result != "" or not actors.has(id):
		return
	var actor = actors[id]
	var before: float = actor.health
	if actor.drink_belt(slot):
		world.sound(actor.floor_id, actor.position, 4.0, "potion")
		world.journal.add("Loot", "%s drinks a belt potion" % actor.display_name)
		world.journal.add("Combat", "%s restores %s HP" % [actor.display_name, Numbers.number(actor.health - before)], actor.floor_id, actor.position + Vector3.UP, "+%d" % roundi(actor.health - before), "heal", id)

func close_trade() -> void:
	if trade_panel and trade_panel.visible:
		if trade_panel.session.get("id", 0) != 0:
			trade_panel.send("cancel")
		trade_panel.hide()

func _trade_action(operation: String, value: int, session_id: int, version: int, revision: int) -> void:
	if multiplayer.is_server():
		apply_trade(multiplayer.get_unique_id(), operation, value, session_id, version, revision)
	else:
		request_trade.rpc_id(1, operation, value, session_id, version, revision)

@rpc("any_peer", "call_remote", "reliable")
func request_trade(operation: String, value: int, session_id: int, version: int, revision: int) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		apply_trade(multiplayer.get_remote_sender_id(), operation, value, session_id, version, revision)

func apply_trade(id: int, operation: String, value: int, session_id: int, version: int, revision: int) -> void:
	if not active or world.objective.result != "" or not actors.has(id):
		return
	var previous: Dictionary = trade_book.view(id, actors)
	var ok := trade_book.operate(id, operation, value, session_id, version, revision, actors)
	if ok and operation == "confirm" and previous.get("other_confirmed", false):
		world.journal.add("Party", "%s exchanges items with %s" % [actors[id].display_name, previous.get("name", "a companion")])
	publish_trade_views()

func publish_trade_views() -> void:
	for peer in actors:
		var data := trade_book.view(peer, actors)
		if peer != 1 and not ready_peers.has(peer):
			continue
		if trade_views.get(peer, {}) == data:
			continue
		trade_views[peer] = data
		if not dedicated and peer == multiplayer.get_unique_id():
			receive_trade_view(data)
		elif ready_peers.has(peer):
			receive_trade_view.rpc_id(peer, data)

@rpc("authority", "call_remote", "reliable")
func receive_trade_view(data: Dictionary) -> void:
	if not dedicated and active and is_instance_valid(trade_panel):
		trade_panel.refresh_state(data)

func _inventory_equip_slot(index: int, slot: int, revision: int) -> void:
	if multiplayer.is_server():
		apply_inventory_equip_slot(multiplayer.get_unique_id(), index, slot, revision)
	else:
		request_inventory_equip_slot.rpc_id(1, index, slot, revision)

@rpc("any_peer", "call_remote", "reliable")
func request_inventory_equip_slot(index: int, slot: int, revision: int) -> void:
	if remote_gameplay_ready(multiplayer.get_remote_sender_id()):
		apply_inventory_equip_slot(multiplayer.get_remote_sender_id(), index, slot, revision)

func apply_inventory_equip_slot(id: int, index: int, slot: int, revision: int) -> void:
	if not active or world.objective.result != "" or not actors.has(id):
		return
	var actor = actors[id]
	if actor.health > 0 and actor.attack_phase == 0 and actor.cast_id == "" and actor.inventory.revision == revision and slot >= 0:
		if actor.inventory.equip(index, slot):
			world.sound(actor.floor_id, actor.position, 4.0, "equip")
			actor.empowered = ""

func _process(delta: float) -> void:
	if connecting:
		connection_timeout -= delta
		if connection_timeout <= 0.0:
			_failed("Connection timed out. Check the host and try again.")
	if not active or dedicated or not is_instance_valid(world) or world.objective.result != "":
		return
	var local_id := multiplayer.get_unique_id()
	if not multiplayer.is_server():
		for actor in actors.values():
			NetMotion.advance(actor, delta)
		world.advance_network_motion(delta)
	world.animate_monsters(delta)
	for actor in actors.values():
		if actor.visible:
			actor.update_hands(delta, settings.view_motion)
	if actors.has(local_id):
		var local = actors[local_id]
		if local.camera:
			local.rotation.y = yaw
			local.camera.rotation.x = pitch
		damage_direction.update_direction(local.position, yaw, delta)

func open_escape_menu() -> void:
	inventory_ui.hide()
	skills_ui.hide()
	close_trade()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	voice_chat.stop_capture()
	var id := multiplayer.get_unique_id()
	if actors.has(id):
		if multiplayer.is_server():
			actors[id].direction = Vector2.ZERO
			actors[id].wants_block = false
			actors[id].wants_sprint = false
			actors[id].wants_quiet = false
			attack_requests.erase(id)
		else:
			submit_input.rpc_id(1, Vector2.ZERO, yaw, false, false, false, pitch)
	refresh_lobby_menu()
	escape_menu.open_menu(voice_mode, voice_muted)

func close_escape_menu() -> void:
	escape_menu.close_menu()
	if active and world.objective.result == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_voice_mode(mode: int) -> void:
	voice_mode = clampi(mode, 0, 2)
	voice_selector.select(voice_mode)
	voice_chat.stop_capture()

func set_voice_muted(muted: bool) -> void:
	voice_muted = muted
	if muted:
		voice_chat.stop_capture()

func refresh_binding_hints() -> void:
	for bus in audio_sliders:
		audio_sliders[bus].set_value_no_signal(settings.volumes[bus])
	for i in range(potion_belt.slots.size()):
		potion_belt.slots[i].text = settings.label("belt%d" % (i + 1))
		potion_belt.slots[i].tooltip_text = "Potion belt [%s]" % potion_belt.slots[i].text
	inventory_ui.rotate_button.text = "Rotate [%s]" % settings.label("rotate")
	var labels: Array[String] = []
	for i in range(3):
		labels.append(settings.label("ability%d" % (i + 1)))
	skills_ui.set_slot_keys(labels)

func lobby_admin() -> bool:
	return active and not dedicated and multiplayer.is_server() and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer is ENetMultiplayerPeer

func refresh_lobby_menu() -> void:
	if not is_instance_valid(escape_menu):
		return
	var admin := lobby_admin()
	var mode := "Host" if admin else ("Solo" if multiplayer.is_server() else "Guest")
	var players: Array = []
	for id in actors:
		var actor = actors[id]
		players.append([id, actor.display_name, World.Routes.NAMES[actor.floor_id]])
	var sealed: bool = world.objective.started or world.objective.result != ""
	escape_menu.update_lobby({"mode": mode, "admin": admin, "can_manage": admin and not sealed, "locked": mode == "Solo" or lobby_locked or sealed, "players": players, "capacity": party_size, "local_id": multiplayer.get_unique_id()})

func set_lobby_locked(locked: bool) -> void:
	if not lobby_admin() or world.objective.started or world.objective.result != "":
		return
	lobby_locked = locked
	if locked:
		for id in pending_profiles.keys():
			if not actors.has(id):
				pending_profiles.erase(id)
				multiplayer.multiplayer_peer.disconnect_peer(id)
	lobby_state.rpc(lobby_locked)
	refresh_lobby_menu()

@rpc("authority", "call_remote", "reliable")
func lobby_state(locked: bool) -> void:
	lobby_locked = locked

func kick_companion(peer: int) -> void:
	if not lobby_admin() or world.objective.started or world.objective.result != "" or peer == 1 or not actors.has(peer):
		return
	_peer_left(peer)
	multiplayer.multiplayer_peer.disconnect_peer(peer)
	refresh_lobby_menu()

func leave_expedition(quit_game: bool) -> void:
	if not active:
		return
	_failed()
	if quit_game:
		get_tree().quit()

func close_skills() -> void:
	skills_ui.hide()
	if active and world.objective.result == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func remote_gameplay_ready(id: int) -> bool:
	return active and multiplayer.is_server() and ready_peers.has(id) and actors.has(id) and is_instance_valid(world) and world.objective.result == ""

func reserved_slots() -> int:
	var count := actors.size()
	for peer in pending_profiles:
		if not actors.has(peer):
			count += 1
	return count

func player_states() -> Dictionary:
	var states := {}
	for id in actors:
		states[id] = [actors[id].position, actors[id].heading, actors[id].floor_id, actors[id].health, actors[id].stamina, actors[id].blocking, actors[id].attack_phase, actors[id].hurt_timer, actors[id].swing_hit, actors[id].inventory.state(), actors[id].skills.state(), actors[id].combat_timer, actors[id].mana, actors[id].sprinting, actors[id].cast_id, actors[id].noise_level, actors[id].quiet_walking, actors[id].noise_peak, actors[id].look_pitch, actors[id].selected_spell, actors[id].aiming, actors[id].bow_charge, actors[id].bow_drawing]

	return states

@rpc("authority", "call_remote", "reliable")
func initial_state(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary, traps: Dictionary, objective_data: Dictionary, secrets: Array) -> void:
	if not bootstrapping or not is_instance_valid(world) or not actors.has(multiplayer.get_unique_id()) or not states.has(multiplayer.get_unique_id()):
		return
	apply_snapshot(sequence, states, mobs, drops, shots, traps, objective_data, secrets, false)
	_start()
	bootstrap_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func bootstrap_ready() -> void:
	if not multiplayer.is_server() or not active:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not actors.has(peer) or not pending_profiles.has(peer):
		return
	pending_profiles.erase(peer)
	ready_peers[peer] = true
	# A stair transfer or terminal result may have occurred during loading.
	initial_state_update.rpc_id(peer, tick, player_states(), world.monster_snapshot(), world.loot.state(), world.projectiles.state(), world.hazards.state(), world.objective.state(), world.secret_state())

@rpc("authority", "call_remote", "reliable")
func initial_state_update(sequence: int, states: Dictionary, mobs: Dictionary, drops: Dictionary, shots: Dictionary, traps: Dictionary, objective_data: Dictionary, secrets: Array) -> void:
	if active and is_instance_valid(world) and sequence >= received_tick:
		apply_snapshot(sequence, states, mobs, drops, shots, traps, objective_data, secrets, false)
