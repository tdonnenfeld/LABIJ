extends SceneTree

const Settings = preload("res://game/ui/player_settings.gd")
const Mix = preload("res://game/audio/audio_mix.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	Mix.ensure()
	var prefs := Settings.new()
	check(not prefs.rebind("forward", KEY_ESCAPE).is_empty(), "Escape reserved")
	check(not prefs.rebind("forward", KEY_S).is_empty(), "Duplicate rejected")
	check(prefs.rebind("forward", KEY_UP).is_empty(), "Movement rebind")
	check(prefs.rebind("attack", KEY_B).is_empty(), "Attack rebind")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_UP
	event.pressed = true
	check(prefs.matches(event, "forward"), "Rebound event")
	prefs.set_volume("Master", 0.45)
	prefs.set_volume(Mix.EFFECTS, 0.0)
	prefs.sensitivity = 1.5
	prefs.resolution = Vector2i(1920, 1080)
	prefs.display_mode = 2
	check(Settings.fit_window(Vector2i(1920, 1080), Vector2i(1280, 720)) == Vector2i(1280, 720), "Fits smaller monitor")
	check(Settings.fit_window(Vector2i(1280, 720), Vector2i(1920, 1080)) == Vector2i(1280, 720), "Keeps requested window size")
	var path := "user://escape_menu_test.cfg"
	check(prefs.save_file(path) == OK, "Settings save")
	var loaded := Settings.new()
	loaded.load_file(path)
	check(loaded.bindings == prefs.bindings and is_equal_approx(loaded.sensitivity, 1.5), "Keys and sensitivity restored")
	check(is_equal_approx(loaded.volumes["Master"], 0.45) and AudioServer.is_bus_mute(AudioServer.get_bus_index(Mix.EFFECTS)), "Volume restored")
	check(loaded.resolution == prefs.resolution and loaded.display_mode == 2, "Display restored")
	var invalid := ConfigFile.new()
	invalid.set_value("display", "resolution", Vector2i(-10, 0))
	invalid.set_value("display", "mode", 999)
	invalid.save(path)
	loaded.load_file(path)
	check(loaded.resolution == Settings.DEFAULT_RESOLUTION and loaded.display_mode == 0, "Invalid display settings reset")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	loaded.reset_keys()
	check(loaded.bindings == Settings.DEFAULTS, "Defaults restored")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.escape_menu != null and not game.escape_menu.visible and game.escape_menu.tabs.get_tab_count() == 5, "Five menu tabs")
	check(game.main_display.size_select.item_count == Settings.RESOLUTIONS.size(), "Main menu resolution selector")
	check(game.escape_menu.display_controls.mode_select.item_count == 3, "In-game display modes")
	game._solo()
	game.open_escape_menu()
	check(game.escape_menu.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and game.active and not paused, "Menu does not pause simulation")
	check(not game.escape_menu.lock_button.visible and not game.lobby_admin(), "Solo cannot administer network")
	game.escape_menu.begin_binding("forward")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	check(game.escape_menu.capture(escape) and game.escape_menu.waiting.is_empty() and game.escape_menu.visible, "Escape cancels binding only")
	game.close_escape_menu()
	check(not game.escape_menu.visible, "Resume")
	game.leave_expedition(false)
	check(not game.active and game.menu.visible, "Exit returns to menu")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
