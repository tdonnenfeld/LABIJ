extends HBoxContainer

const Icons = preload("res://game/items/item_icons.gd")
const Parchment = preload("res://game/ui/parchment.gd")
const Inventory = preload("res://game/items/inventory.gd")
var slots: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	for i in range(Inventory.BELT_CAPACITY):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(38, 48)
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_theme_constant_override("icon_max_width", 25)
		slot.add_theme_font_size_override("font_size", 12)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.text = str(i + 4)
		slot.tooltip_text = "Potion belt [%d]" % (i + 4)
		add_child(slot)
		slots.append(slot)
	refresh(0)

func refresh(count: int) -> void:
	for i in range(slots.size()):
		slots[i].icon = Icons.texture("potion") if i < count else null
		slots[i].disabled = i >= count
