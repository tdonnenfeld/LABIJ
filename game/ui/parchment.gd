extends RefCounted

const PAPER := Color("#d5c19a")
const INK := Color("#30271e")
const BRASS := Color("#94784b")
const LEATHER := Color("#49362b")
const LIGHT := Color("#e8d9b6")
const HP := Color("#8c3935")
const STAMINA := Color("#78804a")
const MANA := Color("#526d88")
static var paper_texture: ImageTexture
static var hud_theme: Theme
static var menu_theme: Theme

static func paper() -> ImageTexture:
	if paper_texture:
		return paper_texture
	var image := Image.create(96, 96, false, Image.FORMAT_RGB8)
	for y in range(96):
		for x in range(96):
			var edge := mini(mini(x, y), mini(95 - x, 95 - y))
			var grain := float(posmod(x * 193 + y * 317 + x * y * 17, 101)) / 100.0
			var fleck := float(posmod(floori(x / 5.0) * 73 + floori(y / 5.0) * 151, 19)) / 18.0
			var color := PAPER.darkened(0.04 + grain * 0.06 + fleck * 0.06)
			if edge < 2:
				color = Color("#6a4a30")
			elif edge == 3 or edge == 6:
				color = BRASS
			elif edge < 10:
				color = color.darkened(float(10 - edge) * 0.035)
			image.set_pixel(x, y, color)
	paper_texture = ImageTexture.create_from_image(image)
	return paper_texture

static func parchment(margin: float = 10.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = paper()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 10.0)
		style.set_content_margin(side, margin)
	return style

static func frame(background: Color, border: Color = BRASS, margin: float = 5.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, margin)
	return style

static func hud_plate() -> StyleBoxFlat:
	return frame(Color("#241e19e8"), BRASS, 4.0)

static func resource_fill(color: Color) -> StyleBoxFlat:
	var style := frame(color, color.lightened(0.28), 0.0)
	style.border_width_bottom = 2
	return style

static func decorate_bar(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("background", frame(Color("#1b1713"), BRASS, 2.0))
	bar.add_theme_stylebox_override("fill", resource_fill(color))
	bar.show_percentage = false

static func plate(label: Label, font_size: int = 13) -> void:
	label.add_theme_stylebox_override("normal", hud_plate())
	label.add_theme_color_override("font_color", LIGHT)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func build(light: bool) -> Theme:
	if light and menu_theme:
		return menu_theme
	if not light and hud_theme:
		return hud_theme
	var result := Theme.new()
	result.default_font_size = 14
	var ink := INK if light else LIGHT
	var panel: StyleBox = parchment() if light else hud_plate()
	var field := frame(Color("#c3aa7d") if light else Color("#342820"), BRASS, 4.0)
	var normal := frame(Color("#49362b"), BRASS, 4.0)
	var hover := frame(Color("#67503a"), Color("#dbc285"), 4.0)
	var pressed := frame(Color("#33251d"), Color("#dbc285"), 4.0)
	var disabled := frame(Color("#48413a"), Color("#756650"), 4.0)
	var selected := frame(Color("#766040") if light else Color("#6a5138"), Color("#d8be7a"), 4.0)
	result.set_stylebox("panel", "PanelContainer", panel)
	result.set_stylebox("panel", "PopupPanel", panel)
	result.set_stylebox("panel", "PopupMenu", panel)
	result.set_stylebox("panel", "ItemList", field)
	result.set_stylebox("selected", "ItemList", selected)
	result.set_stylebox("selected_focus", "ItemList", selected)
	result.set_stylebox("normal", "LineEdit", field)
	result.set_stylebox("focus", "LineEdit", frame(Color("#00000000"), Color("#d9b77a"), 4.0))
	result.set_stylebox("panel", "TooltipPanel", hud_plate())
	result.set_stylebox("background", "ProgressBar", frame(Color("#1b1713"), BRASS, 2.0))
	result.set_stylebox("fill", "ProgressBar", resource_fill(STAMINA))
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBox = normal
			match state:
				"hover": style = hover
				"pressed": style = pressed
				"disabled": style = disabled
				"focus": style = frame(Color("#00000000"), Color("#e7cc8b"), 4.0)
			result.set_stylebox(state, type, style)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(key, type, LIGHT)
		result.set_color("font_disabled_color", type, Color("#b2a48d"))
	for type in ["Label", "LineEdit", "ItemList", "PopupMenu"]:
		result.set_color("font_color", type, ink)
	result.set_color("font_placeholder_color", "LineEdit", ink.lerp(Color("#867357"), 0.45))
	result.set_color("font_selected_color", "ItemList", LIGHT)
	result.set_color("font_hover_color", "PopupMenu", LIGHT)
	result.set_stylebox("hover", "PopupMenu", selected)
	result.set_color("default_color", "RichTextLabel", ink)
	result.set_color("font_color", "TooltipLabel", LIGHT)
	result.set_color("font_color", "ProgressBar", LIGHT)
	result.set_constant("separation", "VBoxContainer", 4)
	result.set_constant("separation", "HBoxContainer", 6)
	if light:
		menu_theme = result
	else:
		hud_theme = result
	return result

static func heading(label: Label, font_size: int) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Liberation Serif", "Noto Serif", "DejaVu Serif"])
	font.font_weight = 700
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
