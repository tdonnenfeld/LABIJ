extends HBoxContainer

const Icons = preload("res://game/items/item_icons.gd")
const Catalog = preload("res://game/items/catalog.gd")
signal selected(index: int)
var cards: Array[Button] = []

func _ready() -> void:
	for i in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(98, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(func(): select_equipment(i))
		add_child(button)
		cards.append(button)
	refresh([], -1)

func refresh(data: Array, chosen: int) -> void:
	for i in range(cards.size()):
		var button := cards[i]
		var slot: String = ["Weapon", "Shield", "Armour"][i]
		var index: int = data[i + 1] if data.size() == 9 else -1
		var occupied: bool = index >= 0 and index < data[0].size()
		button.set_meta("item_index", index if occupied else -1)
		button.disabled = not occupied
		button.text = slot if occupied else slot + " —"
		button.icon = Icons.texture(data[0][index]) if occupied else null
		button.tooltip_text = Catalog.get_item(data[0][index]).title if occupied else "Empty " + slot.to_lower() + " slot"
		button.modulate = Color("#f2d595") if occupied and index == chosen else Color.WHITE

func select_equipment(slot: int) -> void:
	var index: int = cards[slot].get_meta("item_index", -1)
	if index >= 0:
		selected.emit(index)
