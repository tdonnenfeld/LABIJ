extends PanelContainer

const Numbers = preload("res://game/ui/numbers.gd")

const Skills = preload("res://game/progression/skills.gd")
const Catalog = preload("res://game/items/catalog.gd")
signal action(index: int, drop: bool)
var list: ItemList
var details: Label
var state_data: Array = []
var use_button: Button
var drop_button: Button

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	var heading := Label.new()
	heading.text = "Inventory   [I to close]"
	column.add_child(heading)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(390, 220)
	column.add_child(list)
	details = Label.new()
	column.add_child(details)
	use_button = Button.new()
	use_button.text = "Equip / use"
	column.add_child(use_button)
	drop_button = Button.new()
	drop_button.text = "Drop"
	column.add_child(drop_button)
	list.item_selected.connect(func(_index): update_details())
	use_button.pressed.connect(func(): send(false))
	drop_button.pressed.connect(func(): send(true))
	hide()

func refresh(data: Array) -> void:
	if data == state_data:
		return
	var selected := list.get_selected_items()
	state_data = data.duplicate(true)
	list.clear()
	for index in range(data[0].size()):
		var item = Catalog.get_item(data[0][index])
		var equipped: bool = index == data[1] or index == data[2] or index == data[3]
		list.add_item(item.title + (" [equipped]" if equipped else ""))
	if list.item_count > 0:
		list.select(mini(selected[0] if not selected.is_empty() else 0, list.item_count - 1))
	update_details()

func update_details() -> void:
	var selected := list.get_selected_items()
	use_button.disabled = selected.is_empty()
	drop_button.disabled = selected.is_empty()
	if selected.is_empty() or state_data.is_empty():
		details.text = "No items"
		return
	var index := selected[0]
	drop_button.disabled = index == state_data[1] or index == state_data[2] or index == state_data[3]
	var item = Catalog.get_item(state_data[0][index])
	use_button.text = "Equip / use"
	match item.kind:
		"weapon":
			details.text = "Damage %s | Reach %s m | Stamina %s" % [Numbers.number(item.damage), Numbers.number(item.reach), Numbers.number(item.stamina_cost)]
			if item.projectile_speed > 0:
				details.text += " | Ranged"
			if item.poison > 0:
				details.text += " | Poison %s/s" % Numbers.number(item.poison)
			if item.spell_power > 0:
				details.text += " | Spell power +%s%%" % Numbers.number(item.spell_power * 100)
		"scroll":
			var node := Skills.Talents.find(item.spell_id)
			details.text = "Read to learn permanently | %s mastery %d" % [Skills.TITLES[node[1]], Skills.SCROLL_REQUIREMENTS[item.spell_id]]
			use_button.text = "Read scroll"
		"distraction":
			details.text = "Throw with H or use: distracts enemies, no damage"
			use_button.text = "Throw stone"
		"armor":
			details.text = "Damage reduction: %s%% | Magic resist: %s%%" % [Numbers.number(item.armor * 100), Numbers.number(item.magic_resistance * 100)]
		"shield":
			details.text = "Damage blocked: %s%%" % Numbers.number(item.reduction * 100)
		_:
			details.text = "Restores %s HP" % Numbers.number(item.heal)

	var noise_factor := Catalog.noise_multiplier(state_data[0][index])
	if noise_factor != 1.0:
		details.text += " | Noise x%s" % Numbers.number(noise_factor)

func send(drop: bool) -> void:
	var selected := list.get_selected_items()
	if not selected.is_empty():
		action.emit(selected[0], drop)
