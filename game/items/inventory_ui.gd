extends PanelContainer

const Numbers = preload("res://game/ui/numbers.gd")
const Skills = preload("res://game/progression/skills.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Inventory = preload("res://game/items/inventory.gd")
const Icons = preload("res://game/items/item_icons.gd")
const Equipment = preload("res://game/items/equipment_panel.gd")
const Parchment = preload("res://game/ui/parchment.gd")
signal action(index: int, drop: bool)
var slots: Array[Button] = []
var selection := -1
var equipment: HBoxContainer
var details: Label
var item_title: Label
var item_kind: Label
var item_picture: TextureRect
var capacity_label: Label
var state_data: Array = []
var use_button: Button
var drop_button: Button

func _ready() -> void:
	theme = Parchment.build(true)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var heading := Label.new()
	heading.text = "The adventurer's satchel"
	Parchment.heading(heading, 23)
	column.add_child(heading)
	var sub := Label.new()
	sub.text = "EXPEDITION EQUIPMENT  ·  [I] / Esc to close"
	sub.add_theme_font_size_override("font_size", 12)
	column.add_child(sub)
	column.add_child(HSeparator.new())
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 14)
	column.add_child(spread)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 320
	spread.add_child(left)
	var equipped_title := Label.new()
	equipped_title.text = "Worn equipment"
	Parchment.heading(equipped_title, 15)
	left.add_child(equipped_title)
	equipment = Equipment.new()
	left.add_child(equipment)
	equipment.selected.connect(select_item)
	capacity_label = Label.new()
	capacity_label.text = "Carried items · 0 / %d" % Inventory.CAPACITY
	left.add_child(capacity_label)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	var group := ButtonGroup.new()
	for i in range(Inventory.CAPACITY):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(76, 70)
		slot.toggle_mode = true
		slot.button_group = group
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_theme_constant_override("icon_max_width", 42)
		slot.add_theme_font_size_override("font_size", 12)
		slot.pressed.connect(func(): select_item(i))
		grid.add_child(slot)
		slots.append(slot)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 328
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(right)
	var illustration := PanelContainer.new()
	illustration.add_theme_stylebox_override("panel", Parchment.frame(Color("#bba27a"), Parchment.BRASS, 3.0))
	right.add_child(illustration)
	item_picture = TextureRect.new()
	item_picture.custom_minimum_size = Vector2(96, 86)
	item_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.add_child(item_picture)
	item_title = Label.new()
	item_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Parchment.heading(item_title, 19)
	right.add_child(item_title)
	item_kind = Label.new()
	item_kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_kind.add_theme_font_size_override("font_size", 12)
	right.add_child(item_kind)
	right.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 145
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	details = Label.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 13)
	scroll.add_child(details)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	use_button = Button.new()
	use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(use_button)
	drop_button = Button.new()
	drop_button.text = "Drop"
	drop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(drop_button)
	use_button.pressed.connect(func(): send(false))
	drop_button.pressed.connect(func(): send(true))
	update_slots()
	update_details()
	hide()

func equipped(index: int) -> bool:
	return state_data.size() == 4 and index >= 0 and index in state_data.slice(1, 4)

func item_count() -> int:
	return state_data[0].size() if state_data.size() == 4 else 0

func refresh(data: Array) -> void:
	if data == state_data:
		return
	var previous_id: String = state_data[0][selection] if selection >= 0 and selection < item_count() else ""
	state_data = data.duplicate(true)
	if item_count() == 0:
		selection = -1
	elif selection < 0:
		selection = 0
	elif selection >= item_count() or state_data[0][selection] != previous_id:
		var replacement: int = state_data[0].find(previous_id)
		selection = replacement if replacement >= 0 else mini(selection, item_count() - 1)
	update_slots()
	update_details()

func select_item(index: int) -> void:
	if index < 0 or index >= item_count():
		return
	selection = index
	update_slots()
	update_details()

func update_slots() -> void:
	capacity_label.text = "Carried items · %d / %d" % [item_count(), Inventory.CAPACITY]
	for i in range(slots.size()):
		var slot := slots[i]
		var occupied := i < item_count()
		slot.disabled = not occupied
		slot.set_pressed_no_signal(occupied and i == selection)
		slot.icon = Icons.texture(state_data[0][i]) if occupied else null
		var mark := ""
		if occupied and equipped(i):
			mark = " · W" if i == state_data[1] else (" · S" if i == state_data[2] else " · A")
		slot.text = "%02d%s" % [i + 1, mark] if occupied else "—"
		slot.tooltip_text = Catalog.get_item(state_data[0][i]).title + (" · Equipped" if equipped(i) else "") if occupied else "Empty slot"
	equipment.refresh(state_data, selection)

func update_details() -> void:
	var valid := selection >= 0 and selection < item_count()
	use_button.disabled = not valid
	drop_button.disabled = not valid or equipped(selection)
	if not valid:
		item_picture.texture = null
		item_title.text = "No item selected"
		item_kind.text = ""
		details.text = "Select an item to inspect its properties."
		use_button.text = "Use"
		return
	var id: String = state_data[0][selection]
	var item = Catalog.get_item(id)
	item_picture.texture = Icons.texture(id)
	item_title.text = item.title
	var category: String = {"weapon": "WEAPON", "shield": "SHIELD", "armor": "ARMOUR", "scroll": "SPELL SCROLL", "consumable": "CONSUMABLE", "distraction": "UTILITY"}.get(item.kind, "ITEM")
	item_kind.text = category + (" · EQUIPPED" if equipped(selection) else "")
	if id.contains(":"):
		item_kind.text += " · ENCHANTED"
	elif id in ["warden_shield", "oracle_staff"]:
		item_kind.text += " · UNIQUE"
	var lines: PackedStringArray = []
	use_button.text = "Equipped" if equipped(selection) else "Equip"
	use_button.disabled = equipped(selection)
	match item.kind:
		"weapon":
			lines.append("Damage      %s" % Numbers.number(item.damage))
			lines.append("Reach          %s m" % Numbers.number(item.reach))
			lines.append("Stamina      %s" % Numbers.number(item.stamina_cost))
			lines.append("Windup / recovery   %s / %s s" % [Numbers.number(item.windup), Numbers.number(item.recovery)])
			if item.projectile_speed > 0:
				lines.append("Ranged weapon")
			if item.poison > 0:
				lines.append("Poison        %s / s" % Numbers.number(item.poison))
			if item.spell_power > 0:
				lines.append("Spell power   +%s%%" % Numbers.number(item.spell_power * 100))
			if item.mana_bonus > 0:
				lines.append("Mana recovery   +%s%%" % Numbers.number(item.mana_bonus * 100))
		"scroll":
			var node := Skills.Talents.find(item.spell_id)
			lines.append("Learn a spell permanently.")
			lines.append("%s mastery %d required." % [Skills.TITLES[node[1]], Skills.SCROLL_REQUIREMENTS[item.spell_id]])
			lines.append("Read outside combat. Consumed on success.")
			use_button.text = "Read scroll"
		"distraction":
			lines.append("Throw to draw enemies toward the landing point.")
			lines.append("Deals no damage. Also usable with [H].")
			use_button.text = "Throw stone"
		"armor":
			lines.append("Damage reduction   %s%%" % Numbers.number(item.armor * 100))
			lines.append("Magic resistance    %s%%" % Numbers.number(item.magic_resistance * 100))
		"shield":
			lines.append("Damage blocked   %s%%" % Numbers.number(item.reduction * 100))
		"consumable":
			lines.append("Restores %s HP, up to maximum health." % Numbers.number(item.heal))
			use_button.text = "Drink potion"
		_:
			lines.append("An expedition item.")
	lines.append("Noise multiplier   x%s" % Numbers.number(Catalog.noise_multiplier(id)))
	if equipped(selection):
		lines.append("Equip a replacement before dropping.")
	details.text = "\n".join(lines)

func send(drop: bool) -> void:
	if selection < 0 or selection >= item_count() or equipped(selection):
		return
	action.emit(selection, drop)
