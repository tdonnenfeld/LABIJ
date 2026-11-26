extends VBoxContainer

const Settings = preload("res://game/ui/player_settings.gd")
signal changed
var settings: RefCounted
var mode_select: OptionButton
var size_select: OptionButton
var notice: Label

func _ready() -> void:
	var mode_label := Label.new()
	mode_label.text = "Display mode"
	add_child(mode_label)
	mode_select = OptionButton.new()
	for title in Settings.DISPLAY_MODES:
		mode_select.add_item(title)
	add_child(mode_select)
	var size_label := Label.new()
	size_label.text = "Window size"
	add_child(size_label)
	size_select = OptionButton.new()
	for resolution in Settings.RESOLUTIONS:
		size_select.add_item("%d × %d" % [resolution.x, resolution.y])
	add_child(size_select)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 12)
	add_child(notice)
	mode_select.item_selected.connect(func(index):
		settings.display_mode = index
		apply())
	size_select.item_selected.connect(func(index):
		settings.resolution = Settings.RESOLUTIONS[index]
		apply())
	refresh()

func refresh() -> void:
	mode_select.select(settings.display_mode)
	size_select.select(Settings.RESOLUTIONS.find(settings.resolution))
	size_select.disabled = settings.display_mode != 0
	notice.text = "Window fits your monitor. HUD scales with the window." if settings.display_mode == 0 else "Uses your desktop display size."

func apply() -> void:
	settings.apply_display(get_window())
	var result: Error = settings.save_file()
	refresh()
	if result != OK:
		notice.text = "Display settings could not be saved."
	changed.emit()
