extends RefCounted

const Mix = preload("res://game/audio/audio_mix.gd")
const FILE := "user://settings.cfg"
const DEFAULTS := {
	"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
	"sprint": KEY_SHIFT, "quiet": KEY_CTRL, "attack": -MOUSE_BUTTON_LEFT, "block": -MOUSE_BUTTON_RIGHT,
	"interact": KEY_E, "pickup": KEY_F, "inventory": KEY_I, "talents": KEY_K,
	"map": KEY_M, "log": KEY_L, "trade": KEY_J, "rotate": KEY_R,
	"ability1": KEY_1, "ability2": KEY_2, "ability3": KEY_3,
	"belt1": KEY_4, "belt2": KEY_5, "belt3": KEY_6, "belt4": KEY_7,
	"discover": KEY_T, "drop_jewel": KEY_G, "throw_stone": KEY_H, "voice": KEY_V, "mute": KEY_N
}
const TITLES := {
	"forward": "Move forward", "back": "Move back", "left": "Strafe left", "right": "Strafe right",
	"sprint": "Sprint", "quiet": "Quiet walk", "attack": "Attack", "block": "Block",
	"interact": "Interact / stairs", "pickup": "Pick up loot", "inventory": "Inventory", "talents": "Talents",
	"map": "Map", "log": "Expedition log", "trade": "Companion exchange", "rotate": "Rotate item",
	"ability1": "Ability 1", "ability2": "Ability 2", "ability3": "Ability 3",
	"belt1": "Potion belt 1", "belt2": "Potion belt 2", "belt3": "Potion belt 3", "belt4": "Potion belt 4",
	"discover": "Discover tablet", "drop_jewel": "Drop Jewel", "throw_stone": "Throw stone", "voice": "Push to talk", "mute": "Toggle microphone mute"
}
const AUDIO_DEFAULTS := {"Master": 1.0, Mix.EFFECTS: 0.85, Mix.AMBIENCE: 0.65, Mix.VOICE: 1.0}
var bindings: Dictionary = DEFAULTS.duplicate()
var volumes: Dictionary = AUDIO_DEFAULTS.duplicate()
var sensitivity := 1.0
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DISPLAY_MODES := ["Windowed", "Maximized", "Fullscreen"]
var resolution := DEFAULT_RESOLUTION
var display_mode := 0

static func code_for(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		return int(event.physical_keycode)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			return -int(event.button_index)
	return 0

static func allowed(action: String, code: int) -> bool:
	if not DEFAULTS.has(action) or code == 0 or code == KEY_ESCAPE:
		return false
	if code < 0:
		return action in ["attack", "block"] and -code in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
	return code <= KEY_UNKNOWN and not OS.get_keycode_string(code).is_empty()

func rebind(action: String, code: int) -> String:
	if not allowed(action, code):
		return "That input is reserved or unsupported."
	for other in bindings:
		if other != action and bindings[other] == code:
			return "Already assigned to " + TITLES[other] + "."
	bindings[action] = code
	return ""

func label(action: String) -> String:
	var code: int = bindings.get(action, 0)
	match code:
		-MOUSE_BUTTON_LEFT: return "LMB"
		-MOUSE_BUTTON_RIGHT: return "RMB"
		-MOUSE_BUTTON_MIDDLE: return "MMB"
		-MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
		-MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		_: return OS.get_keycode_string(code)

func pressed(action: String) -> bool:
	var code: int = bindings[action]
	return Input.is_mouse_button_pressed(-code) if code < 0 else Input.is_physical_key_pressed(code)

func matches(event: InputEvent, action: String) -> bool:
	return code_for(event) == bindings[action]

func reset_keys() -> void:
	bindings = DEFAULTS.duplicate()

func set_volume(bus: String, value: float) -> void:
	if not AUDIO_DEFAULTS.has(bus) or not is_finite(value):
		return
	volumes[bus] = clampf(value, 0.0, 1.0)
	Mix.set_volume(bus, volumes[bus])

func load_file(path: String = FILE) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var candidate: Dictionary = {}
		var used: Array[int] = []
		var valid := true
		for action in DEFAULTS:
			var code: int = int(cfg.get_value("keys", action, DEFAULTS[action]))
			if not allowed(action, code) or code in used:
				valid = false
				break
			candidate[action] = code
			used.append(code)
		if valid:
			bindings = candidate
		var saved_size: Variant = cfg.get_value("display", "resolution", DEFAULT_RESOLUTION)
		var saved_mode: Variant = cfg.get_value("display", "mode", 0)
		resolution = saved_size if saved_size is Vector2i and saved_size in RESOLUTIONS else DEFAULT_RESOLUTION
		display_mode = saved_mode if saved_mode is int and saved_mode >= 0 and saved_mode < DISPLAY_MODES.size() else 0
		var speed := float(cfg.get_value("controls", "sensitivity", 1.0))
		if is_finite(speed):
			sensitivity = clampf(speed, 0.25, 3.0)
		for bus in AUDIO_DEFAULTS:
			set_volume(bus, float(cfg.get_value("audio", bus, AUDIO_DEFAULTS[bus])))
	for bus in volumes:
		Mix.set_volume(bus, volumes[bus])

func save_file(path: String = FILE) -> Error:
	var cfg := ConfigFile.new()
	for action in bindings:
		cfg.set_value("keys", action, bindings[action])
	for bus in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "mode", display_mode)
	return cfg.save(path)

static func fit_window(requested: Vector2i, usable: Vector2i) -> Vector2i:
	var scale := minf(1.0, minf(float(usable.x) / requested.x, float(usable.y) / requested.y))
	return Vector2i(maxi(1, floori(requested.x * scale)), maxi(1, floori(requested.y * scale)))

func apply_display(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return
	match display_mode:
		1:
			window.mode = Window.MODE_MAXIMIZED
		2:
			window.mode = Window.MODE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			var area := DisplayServer.screen_get_usable_rect(window.current_screen)
			# Leave space for title bar and borders.
			var usable := Vector2i(maxi(1, area.size.x - 24), maxi(1, area.size.y - 64))
			window.size = fit_window(resolution, usable)
			window.position = area.position + Vector2i(Vector2(area.size - window.size) * 0.5)
