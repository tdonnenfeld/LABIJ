extends PanelContainer

const Parchment = preload("res://game/ui/parchment.gd")
const HOLD := 3.5
const FADE := 0.65
var last_level := 0
var remaining := 0.0
var headline: Label
var subtitle: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	var frame := Parchment.frame(Color("#30271e"), Color("#dbbc69"), 12.0)
	frame.set_border_width_all(2)
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	headline = Label.new()
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_theme_color_override("font_color", Color("#f2d98b"))
	Parchment.heading(headline, 34)
	column.add_child(headline)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_color_override("font_color", Parchment.LIGHT)
	column.add_child(subtitle)
	reset()

func reset(baseline: int = 0) -> void:
	last_level = baseline
	remaining = 0.0
	modulate.a = 1.0
	hide()

func observe(level: int, talent_key: String) -> bool:
	if last_level == 0 or level < last_level:
		reset(level)
		return false
	if level == last_level:
		return false
	var previous := last_level
	last_level = level
	headline.text = "LEVEL UP — %d" % level
	subtitle.text = ("+%d levels · " % (level - previous) if level - previous > 1 else "") + "Review talents [%s]" % talent_key
	remaining = HOLD + FADE
	modulate.a = 1.0
	show()
	return true

func _process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	modulate.a = clampf(remaining / FADE, 0.0, 1.0)
	if remaining == 0.0:
		hide()
