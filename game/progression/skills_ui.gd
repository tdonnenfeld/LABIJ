extends PanelContainer

const Skills = preload("res://game/progression/skills.gd")
const TreeCanvas = preload("res://game/progression/tree_canvas.gd")
const Parchment = preload("res://game/ui/parchment.gd")
signal priority_changed(index: int, value: int)
signal talent_action(action: String, id: String, index: int)
signal closed
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
var key_labels: Array[String] = ["1", "2", "3"]

func _ready() -> void:
	theme = Parchment.build(true)
	add_theme_stylebox_override("panel", Parchment.parchment(12.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
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
	var controls := HBoxContainer.new()
	column.add_child(controls)
	var domains := OptionButton.new()
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
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 12)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spread)
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
	status_label = Label.new()
	status_label.text = "Scroll the tree to explore · Learned / XP cost shown on each talent"
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

func refresh(data: Array, can_train: bool) -> void:
	var structural: Array = data.slice(0, 7)
	model.apply(data)
	if structural != previous or safe_now != can_train:
		previous = structural.duplicate(true)
		safe_now = can_train
		rebuild()

func set_slot_keys(labels: Array[String]) -> void:
	key_labels.assign(labels)
	refresh_slots()

func refresh_slots() -> void:
	for i in range(slot_names.size()):
		var node := Skills.Talents.find(model.slots[i])
		var caption := "%s: %s" % [key_labels[i], "Empty" if node.is_empty() else node[2]]
		slot_names[i].text = caption
		slot_names[i].tooltip_text = caption
		clear_buttons[i].disabled = not safe_now or model.slots[i] == ""

func rebuild() -> void:
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
