extends PanelContainer

const Skills = preload("res://game/progression/skills.gd")
const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const TreeCanvas = preload("res://game/progression/tree_canvas.gd")
const Parchment = preload("res://game/ui/parchment.gd")
signal priority_changed(index: int, value: int)
signal talent_action(action: String, id: String, index: int)
signal closed
signal equip_item(index: int, revision: int)
var tree: Control
var selected_id := ""
var details: Label
var learn: Button
var equip_buttons: Array[Button] = []
var clear_buttons: Array[Button] = []
var slot_names: Array[Label] = []
var model := Skills.new()
var domain := 0
var heading: Label
var priority: OptionButton
var safe_now := false
var previous: Array = []
var scroll: ScrollContainer
var status_label: Label
var domains: OptionButton
var pages: TabContainer
var training_rows: VBoxContainer
var known_rows: VBoxContainer
var equipment_rows: VBoxContainer
var known_filter: OptionButton
var bag := Inventory.new()
var bag_state: Array = []
var trained_count: Label
var key_labels: Array[String] = ["1", "2", "3"]

func _ready() -> void:
	theme = Parchment.build(true)
	add_theme_stylebox_override("panel", Parchment.parchment(12.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport := Control.new()
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport)
	var column := VBoxContainer.new()
	column.name = "GrimoireContent"
	column.add_theme_constant_override("separation", 7)
	viewport.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = "Grimoire of talents"
	Parchment.heading(title, 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	pages = TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	var tree_tab := VBoxContainer.new()
	tree_tab.name = "Talent tree"
	pages.add_child(tree_tab)
	var controls := HBoxContainer.new()
	tree_tab.add_child(controls)
	domains = OptionButton.new()
	for title_text in Skills.TITLES:
		domains.add_item(title_text)
	domains.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(domains)
	domains.item_selected.connect(select_domain)
	priority = OptionButton.new()
	for title_text in ["XP allocation: Off", "XP allocation: Normal", "XP allocation: Focus 2x"]:
		priority.add_item(title_text)
	controls.add_child(priority)
	priority.item_selected.connect(func(i): priority_changed.emit(domain, i))
	heading = Label.new()
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tree_tab.add_child(heading)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 12)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_tab.add_child(spread)
	var tree_page := PanelContainer.new()
	tree_page.add_theme_stylebox_override("panel", Parchment.frame(Color("#c4ad83"), Parchment.BRASS, 4.0))
	tree_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_page.custom_minimum_size = Vector2(420, 200)
	spread.add_child(tree_page)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tree_page.add_child(scroll)
	tree = TreeCanvas.new()
	scroll.add_child(tree)
	tree.selected.connect(select_talent)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 245
	right.add_theme_constant_override("separation", 6)
	spread.add_child(right)
	var selected_title := Label.new()
	selected_title.text = "Selected talent"
	Parchment.heading(selected_title, 16)
	right.add_child(selected_title)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size.y = 80
	right.add_child(detail_scroll)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(details)
	learn = Button.new()
	learn.text = "Learn selected talent"
	right.add_child(learn)
	learn.pressed.connect(func(): talent_action.emit("buy", selected_id, 0))
	right.add_child(HSeparator.new())
	var slot_title := Label.new()
	slot_title.text = "Active abilities"
	Parchment.heading(slot_title, 16)
	right.add_child(slot_title)
	for i in range(Skills.SLOT_COUNT):
		var slot_row := HBoxContainer.new()
		right.add_child(slot_row)
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_row.add_child(name_label)
		slot_names.append(name_label)
		var equip := Button.new()
		equip.text = "Assign"
		slot_row.add_child(equip)
		equip_buttons.append(equip)
		equip.pressed.connect(func(): talent_action.emit("slot", selected_id, i))
		var clear := Button.new()
		clear.text = "Clear"
		slot_row.add_child(clear)
		clear_buttons.append(clear)
		clear.pressed.connect(func(): talent_action.emit("slot", "", i))
	build_training()
	build_known()
	build_equipment()
	pages.current_tab = 1
	status_label = Label.new()
	status_label.text = "Training and ability changes require a safe area · Equipment uses your inventory"
	status_label.add_theme_font_size_override("font_size", 12)
	column.add_child(status_label)
	rebuild()
	hide()

func select_domain(index: int) -> void:
	domain = index
	selected_id = ""
	rebuild()
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0

func refresh(data: Array, can_train: bool, inventory_data: Array = []) -> void:
	if not inventory_data.is_empty() and inventory_data != bag_state:
		bag_state = inventory_data.duplicate(true)
		bag.apply(inventory_data)
		rebuild_equipment()
	var structural: Array = data.slice(0, 7)
	model.apply(data)
	if structural != previous or safe_now != can_train:
		previous = structural.duplicate(true)
		safe_now = can_train
		rebuild()

func set_slot_keys(labels: Array[String]) -> void:
	key_labels.assign(labels)
	refresh_slots()
	rebuild_known()

func refresh_slots() -> void:
	for i in range(slot_names.size()):
		var node := Skills.Talents.find(model.slots[i])
		var caption := "%s: %s" % [key_labels[i], "Empty" if node.is_empty() else node[2]]
		slot_names[i].text = caption
		slot_names[i].tooltip_text = caption
		clear_buttons[i].disabled = not safe_now or model.slots[i] == ""

func rebuild() -> void:
	for i in range(Skills.TITLES.size()):
		domains.set_item_text(i, "%s · M%d · %.0f XP" % [Skills.TITLES[i], model.mastery(i), model.xp[i]])
	rebuild_training()
	rebuild_known()
	heading.text = "%s · Mastery %d · %.1f available / %.1f lifetime XP%s" % [Skills.TITLES[domain], model.mastery(domain), model.wallet[domain], model.xp[domain], "" if safe_now else " · In combat"]
	priority.select(model.priorities[domain])
	tree.build(model, domain, selected_id)
	var node := Skills.Talents.find(selected_id)
	details.text = "Select a talent to inspect it." if node.is_empty() else "%s\n\n%s\n\n%s" % [node[2], node[7], "Learned" if model.learned.has(selected_id) else "%d XP required" % node[3]]
	if Skills.SCROLL_REQUIREMENTS.has(selected_id):
		details.text += "\nScroll required · Mastery %d" % Skills.SCROLL_REQUIREMENTS[selected_id]
	learn.disabled = not safe_now or not model.can_buy(selected_id)
	for button in equip_buttons:
		button.disabled = not safe_now or node.is_empty() or not model.learned.has(selected_id) or node[5] != "active"
	refresh_slots()

func select_talent(id: String) -> void:
	selected_id = id
	rebuild()

func clear_rows(rows: VBoxContainer) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

func tab_rows(title: String) -> VBoxContainer:
	var scroll_page := ScrollContainer.new()
	scroll_page.name = title
	scroll_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(scroll_page)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll_page.add_child(rows)
	return rows

func build_training() -> void:
	training_rows = tab_rows("Training")

func build_known() -> void:
	var page := VBoxContainer.new()
	page.name = "Known abilities"
	pages.add_child(page)
	known_filter = OptionButton.new()
	for caption in ["All learned", "Assignable abilities", "Passive talents"]:
		known_filter.add_item(caption)
	page.add_child(known_filter)
	known_filter.item_selected.connect(func(_index): rebuild_known())
	var list := ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(list)
	known_rows = VBoxContainer.new()
	known_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(known_rows)

func build_equipment() -> void:
	equipment_rows = tab_rows("Equipment")

func caption(parent: Control, value: String, expand: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func action(parent: Control, value: String, callback: Callable, disabled_now: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.disabled = disabled_now
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func rebuild_training() -> void:
	if not training_rows:
		return
	clear_rows(training_rows)
	caption(training_rows, "Ranked by lifetime XP · bars compare training across all schools")
	var order := range(Skills.TITLES.size())
	order.sort_custom(func(a, b): return model.xp[a] > model.xp[b] if model.xp[a] != model.xp[b] else a < b)
	var maximum := maxf(1.0, model.xp[order[0]])
	for i in order:
		var row := HBoxContainer.new()
		training_rows.add_child(row)
		var school := action(row, Skills.TITLES[i], func(): select_domain(i); domains.select(i); pages.current_tab = 0)
		school.custom_minimum_size.x = 130
		var progress := ProgressBar.new()
		progress.max_value = maximum
		progress.value = model.xp[i]
		progress.custom_minimum_size = Vector2(60, 20)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Parchment.decorate_bar(progress, Color("#71844e") if model.xp[i] > 0 else Color("#70665a"))
		row.add_child(progress)
		var learned := 0
		var available := 0
		for node in Skills.Talents.NODES:
			if node[1] == i and model.visible(node):
				available += 1
				if model.learned.has(node[0]):
					learned += 1
		caption(row, "M%d · %.0f XP · %d/%d learned" % [model.mastery(i), model.xp[i], learned, available]).custom_minimum_size.x = 195
		var allocation := OptionButton.new()
		for label in ["Off", "Normal", "Focus 2x"]:
			allocation.add_item(label)
		allocation.select(model.priorities[i])
		allocation.item_selected.connect(func(value): priority_changed.emit(i, value))
		row.add_child(allocation)

func rebuild_known() -> void:
	if not known_rows:
		return
	clear_rows(known_rows)
	var active_count := 0
	for id in model.learned:
		var node := Skills.Talents.find(id)
		if not node.is_empty() and node[5] == "active":
			active_count += 1
	caption(known_rows, "%d learned · %d assignable · %d/%d slots filled" % [model.learned.size(), active_count, Skills.SLOT_COUNT - model.slots.count(""), Skills.SLOT_COUNT])
	var slots_row := HBoxContainer.new()
	known_rows.add_child(slots_row)
	for i in range(Skills.SLOT_COUNT):
		var node := Skills.Talents.find(model.slots[i])
		caption(slots_row, "%s: %s" % [key_labels[i], "Empty" if node.is_empty() else node[2]], true)
		action(slots_row, "Clear", func(): talent_action.emit("slot", "", i), not safe_now or model.slots[i] == "")
	var count := 0
	for node in Skills.Talents.NODES:
		var id: String = node[0]
		if not model.learned.has(id):
			continue
		var active: bool = node[5] == "active"
		if known_filter.selected == 1 and not active or known_filter.selected == 2 and active:
			continue
		count += 1
		var row := HBoxContainer.new()
		known_rows.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var assigned := model.slots.find(id)
		caption(info, "%s · %s%s" % [node[2], Skills.TITLES[node[1]], " · Slot " + key_labels[assigned] if assigned >= 0 else (" · Passive" if not active else "")])
		caption(info, node[7]).add_theme_font_size_override("font_size", 12)
		if active:
			for i in range(Skills.SLOT_COUNT):
				action(row, "Assign " + key_labels[i], func(): talent_action.emit("slot", id, i), not safe_now or assigned == i)
		known_rows.add_child(HSeparator.new())
	if count == 0:
		caption(known_rows, "No learned talents in this category yet.")

func rebuild_equipment() -> void:
	if not equipment_rows:
		return
	clear_rows(equipment_rows)
	if bag_state.is_empty():
		caption(equipment_rows, "Inventory not available yet.")
		return
	caption(equipment_rows, "Currently equipped")
	for slot in range(Inventory.SLOT_KINDS.size()):
		var index := bag.slot_index(slot)
		var name := Inventory.SLOT_KINDS[slot].capitalize()
		if slot >= 7:
			name += " %d" % (slot - 6)
		caption(equipment_rows, "%s: %s" % [name, "Empty" if index < 0 else Catalog.get_item(bag.items[index]).title])
	equipment_rows.add_child(HSeparator.new())
	caption(equipment_rows, "Available equipment in your bag")
	var count := 0
	for i in range(bag.items.size()):
		var item = Catalog.get_item(bag.items[i])
		if bag.is_equipped(i) or not item.kind in Inventory.SLOT_KINDS:
			continue
		count += 1
		var row := HBoxContainer.new()
		equipment_rows.add_child(row)
		caption(row, "%s · %s" % [item.title, item.kind.capitalize()], true)
		var revision := bag.revision
		action(row, "Equip", func(): equip_item.emit(i, revision))
	if count == 0:
		caption(equipment_rows, "No unequipped gear in your bag.")
