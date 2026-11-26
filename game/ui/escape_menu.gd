extends Control

const Parchment = preload("res://game/ui/parchment.gd")
const Settings = preload("res://game/ui/player_settings.gd")
const Mix = preload("res://game/audio/audio_mix.gd")
signal resume
signal voice_changed(mode: int)
signal mute_changed(muted: bool)
signal lobby_lock(locked: bool)
signal kick(peer: int)
signal leave(quit_game: bool)
signal settings_changed
var settings: RefCounted
var tabs: TabContainer
var bind_buttons: Dictionary = {}
var waiting := ""
var key_status: Label
var sliders: Dictionary = {}
var voice_select: OptionButton
var mute_check: CheckButton
var lobby_status: Label
var lobby_rows: VBoxContainer
var lock_button: Button
var lobby_data: Dictionary = {}
var exit_status: Label
var confirm_exit: Button
var cancel_exit: Button
var pending_exit := -1
var pending_kick := 0
var kick_confirm: Button
var kick_cancel: Button
var notice: Label
var header: Label

func _ready() -> void:
	theme = Parchment.build(true)
	mouse_filter = MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("#18130fcc")
	shade.mouse_filter = MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(600, 420)
	center.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	paper.add_child(column)
	header = Label.new()
	header.text = "Expedition journal"
	Parchment.heading(header, 25)
	column.add_child(header)
	var hint := Label.new()
	hint.text = "The expedition continues while this menu is open."
	column.add_child(hint)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(570, 315)
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", Parchment.frame(Color("#c4ab80"), Parchment.BRASS, 8.0))
	for style in ["tab_selected", "tab_hovered", "tab_unselected"]:
		tabs.add_theme_stylebox_override(style, Parchment.frame(Parchment.LEATHER, Parchment.BRASS, 8.0))
	for key in ["font_selected_color", "font_hovered_color", "font_unselected_color"]:
		tabs.add_theme_color_override(key, Parchment.LIGHT)
	column.add_child(tabs)
	build_keys()
	build_sound()
	build_lobby()
	build_exit()
	notice = Label.new()
	notice.add_theme_font_size_override("font_size", 12)
	column.add_child(notice)
	button(column, "Resume expedition [Esc]", func(): resume.emit())
	tabs.tab_changed.connect(func(_tab): cancel_binding(); reset_confirmations())
	hide()

func button(parent: Control, caption: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	return content

func build_keys() -> void:
	var content := page("Keybinds")
	key_status = Label.new()
	key_status.text = "Select a binding, then press a key. Escape cancels. Physical layout."
	key_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(key_status)
	button(content, "Restore default bindings", func(): settings.reset_keys(); changed(); refresh_keys())
	var sensitivity_row := HBoxContainer.new()
	content.add_child(sensitivity_row)
	var label := Label.new()
	label.text = "Mouse sensitivity"
	label.custom_minimum_size.x = 230
	sensitivity_row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.25
	slider.max_value = 3.0
	slider.step = 0.05
	slider.value = settings.sensitivity
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	sensitivity_row.add_child(slider)
	slider.value_changed.connect(func(value): settings.sensitivity = value; changed())
	for action in Settings.DEFAULTS:
		var row := HBoxContainer.new()
		content.add_child(row)
		var name_label := Label.new()
		name_label.text = Settings.TITLES[action]
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(name_label)
		var b := button(row, settings.label(action), func(): begin_binding(action))
		b.custom_minimum_size.x = 154
		bind_buttons[action] = b

func begin_binding(action: String) -> void:
	waiting = action
	key_status.text = "Press a new input for " + Settings.TITLES[action] + "."
	refresh_keys()

func cancel_binding() -> void:
	waiting = ""
	if is_instance_valid(key_status):
		key_status.text = "Select a binding, then press a key. Escape cancels. Physical layout."
		refresh_keys()

func capture(event: InputEvent) -> bool:
	if waiting.is_empty():
		return false
	var code := Settings.code_for(event)
	if code == 0:
		return false
	if code == KEY_ESCAPE:
		cancel_binding()
		return true
	var error: String = settings.rebind(waiting, code)
	if error.is_empty():
		waiting = ""
		changed()
		key_status.text = "Binding updated."
	else:
		key_status.text = error + " Choose another input or press Escape."
	refresh_keys()
	return true

func refresh_keys() -> void:
	for action in bind_buttons:
		bind_buttons[action].text = "Press input…" if waiting == action else settings.label(action)

func changed() -> void:
	var result: Error = settings.save_file()
	if is_instance_valid(notice):
		notice.text = "" if result == OK else "Settings could not be saved."
	settings_changed.emit()

func build_sound() -> void:
	var content := page("Sound")
	for bus in Settings.AUDIO_DEFAULTS:
		var label := Label.new()
		label.text = {"Master": "Master volume", Mix.EFFECTS: "Effects", Mix.AMBIENCE: "Ambience", Mix.VOICE: "Voice playback"}[bus]
		content.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = settings.volumes[bus]
		content.add_child(slider)
		sliders[bus] = slider
		slider.value_changed.connect(func(value): settings.set_volume(bus, value); changed())
	voice_select = OptionButton.new()
	for title in ["Microphone off", "Push to talk", "Open microphone"]:
		voice_select.add_item(title)
	content.add_child(voice_select)
	voice_select.item_selected.connect(func(index): voice_changed.emit(index))
	mute_check = CheckButton.new()
	mute_check.text = "Mute microphone"
	content.add_child(mute_check)
	mute_check.toggled.connect(func(value): mute_changed.emit(value))
	var hint := Label.new()
	hint.text = "Microphone capture stops while menus are open. Voice can alert monsters."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

func sync_sound(mode: int, muted: bool) -> void:
	for bus in sliders:
		sliders[bus].set_value_no_signal(settings.volumes[bus])
	voice_select.select(mode)
	mute_check.set_pressed_no_signal(muted)

func build_lobby() -> void:
	var content := page("Lobby")
	lobby_status = Label.new()
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(lobby_status)
	lock_button = button(content, "Lock new joins", func(): lobby_lock.emit(not lobby_data.get("locked", false)))
	lobby_rows = VBoxContainer.new()
	content.add_child(lobby_rows)
	kick_confirm = button(content, "Confirm removal", func():
		if pending_kick != 0:
			kick.emit(pending_kick)
		reset_confirmations())
	kick_cancel = button(content, "Cancel removal", reset_confirmations)
	kick_confirm.hide()
	kick_cancel.hide()

func update_lobby(data: Dictionary) -> void:
	if data == lobby_data:
		return
	lobby_data = data.duplicate(true)
	var admin: bool = data.get("admin", false)
	var can_manage: bool = data.get("can_manage", false)
	lobby_status.text = "%s · %d / %d players\n%s" % [data.get("mode", "Solo"), data.get("players", []).size(), data.get("capacity", 1), "New joins closed" if data.get("locked", true) else "New joins open"]
	lock_button.visible = admin
	lock_button.disabled = not can_manage
	lock_button.text = "Allow new joins" if data.get("locked", false) else "Lock new joins"
	for child in lobby_rows.get_children():
		lobby_rows.remove_child(child)
		child.queue_free()
	for member in data.get("players", []):
		var row := HBoxContainer.new()
		lobby_rows.add_child(row)
		var label := Label.new()
		label.text = "%s%s · %s" % [member[1], " (you)" if member[0] == data.get("local_id") else (" (host)" if member[0] == 1 else ""), member[2]]
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		if admin and can_manage and member[0] != 1:
			var peer: int = member[0]
			var player_name: String = member[1]
			button(row, "Remove", func():
				pending_kick = peer
				kick_confirm.text = "Remove " + player_name + "?"
				kick_confirm.show()
				kick_cancel.show())
	if not can_manage:
		pending_kick = 0
		kick_confirm.hide()
		kick_cancel.hide()

func build_exit() -> void:
	var content := page("Exit")
	exit_status = Label.new()
	exit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(exit_status)
	button(content, "Return to main menu", func(): ask_exit(false))
	button(content, "Quit LABIJ", func(): ask_exit(true))
	confirm_exit = button(content, "Confirm", func():
		if pending_exit >= 0:
			leave.emit(pending_exit == 1)
		reset_confirmations())
	cancel_exit = button(content, "Cancel", reset_confirmations)
	reset_confirmations()

func ask_exit(quit_game: bool) -> void:
	pending_exit = 1 if quit_game else 0
	var host: bool = lobby_data.get("admin", false)
	exit_status.text = "This will end the hosted expedition for everyone." if host else "You will leave the expedition and lose your current run progress."
	confirm_exit.show()
	cancel_exit.show()

func reset_confirmations() -> void:
	pending_exit = -1
	pending_kick = 0
	if is_instance_valid(confirm_exit):
		exit_status.text = "Leaving is permanent for this run. There is no saved expedition."
		confirm_exit.hide()
		cancel_exit.hide()
	if is_instance_valid(kick_confirm):
		kick_confirm.hide()
		kick_cancel.hide()

func open_menu(mode: int, muted: bool) -> void:
	cancel_binding()
	reset_confirmations()
	sync_sound(mode, muted)
	show()
	move_to_front()

func close_menu() -> void:
	cancel_binding()
	reset_confirmations()
	hide()
