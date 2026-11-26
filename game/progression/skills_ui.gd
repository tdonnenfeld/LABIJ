extends PanelContainer

const Skills = preload("res://game/progression/skills.gd")
const TreeCanvas = preload("res://game/progression/tree_canvas.gd")
var tree: Control
var selected_id := ""
var details: Label
var learn: Button
var equip_buttons: Array[Button] = []
signal priority_changed(index: int, value: int)
signal talent_action(action: String, id: String, index: int)
var model := Skills.new()
var domain := 0
var heading: Label
var priority: OptionButton
var nodes: VBoxContainer
var slots_label: Label
var refund: Button
var safe_now := false
var shrine_now := false
var previous: Array = []

func _ready() -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 0)
	add_child(column)
	heading = Label.new()
	column.add_child(heading)
	var domains := OptionButton.new()
	for title in Skills.TITLES:
		domains.add_item(title)
	column.add_child(domains)
	domains.item_selected.connect(select_domain)
	priority = OptionButton.new()
	for title in ["XP allocation: Off", "XP allocation: Normal", "XP allocation: Focus 2x"]:
		priority.add_item(title)
	column.add_child(priority)
	priority.item_selected.connect(func(i): priority_changed.emit(domain, i))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 240)
	column.add_child(scroll)
	tree = TreeCanvas.new()
	scroll.add_child(tree)
	tree.selected.connect(select_talent)
	details = Label.new()
	column.add_child(details)
	learn = Button.new()
	learn.text = "Learn selected talent"
	column.add_child(learn)
	learn.pressed.connect(func(): talent_action.emit("buy", selected_id, 0))
	var equip_row := HBoxContainer.new()
	column.add_child(equip_row)
	for i in range(Skills.SLOT_COUNT):
		var equip := Button.new()
		equip.text = "Assign to %d" % (i + 1)
		equip_row.add_child(equip)
		equip_buttons.append(equip)
		equip.pressed.connect(func(): talent_action.emit("slot", selected_id, i))
	slots_label = Label.new()
	column.add_child(slots_label)
	var clear_row := HBoxContainer.new()
	column.add_child(clear_row)
	for i in range(Skills.SLOT_COUNT):
		var button := Button.new()
		button.text = "Clear %d" % (i + 1)
		clear_row.add_child(button)
		button.pressed.connect(func(): talent_action.emit("slot", "", i))
	refund = Button.new()
	refund.text = "Refund this domain (75% XP)"
	column.add_child(refund)
	refund.pressed.connect(func(): talent_action.emit("refund", "", domain))
	hide()

func select_domain(index: int) -> void:
	domain = index
	selected_id = ""
	rebuild()

func refresh(data: Array, can_train: bool, at_shrine: bool) -> void:
	var structural: Array = data.slice(0, 7)
	model.apply(data)
	if structural != previous or safe_now != can_train or shrine_now != at_shrine:
		previous = structural.duplicate(true)
		safe_now = can_train
		shrine_now = at_shrine
		rebuild()
	var captions: PackedStringArray = []
	for i in range(Skills.SLOT_COUNT):
		var node := Skills.Talents.find(model.slots[i])
		captions.append("%d: %s" % [i + 1, "Empty" if node.is_empty() else node[2]])
	slots_label.text = "  |  ".join(captions)

func rebuild() -> void:
	heading.text = "%s — %.1f XP available / %.1f lifetime [K]%s" % [Skills.TITLES[domain], model.wallet[domain], model.xp[domain], "" if safe_now else " — In combat"]
	priority.select(model.priorities[domain])
	tree.build(model, domain, selected_id)
	var node := Skills.Talents.find(selected_id)
	details.text = "Select a talent to inspect it" if node.is_empty() else "%s — %s" % [node[2], node[7]]
	learn.disabled = not safe_now or not model.can_buy(selected_id)
	for button in equip_buttons:
		button.disabled = not safe_now or node.is_empty() or not model.learned.has(selected_id) or node[5] != "active"
	refund.disabled = not safe_now or not shrine_now

func select_talent(id: String) -> void:
	selected_id = id
	rebuild()
