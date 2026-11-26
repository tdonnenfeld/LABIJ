extends PanelContainer

const Skills = preload("res://game/progression/skills.gd")
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
	column.custom_minimum_size = Vector2(560, 0)
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
	nodes = VBoxContainer.new()
	column.add_child(nodes)
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
	for child in nodes.get_children():
		nodes.remove_child(child)
		child.queue_free()
	for node in Skills.Talents.NODES:
		if node[1] != domain or not model.visible(node):
			continue
		var row := HBoxContainer.new()
		nodes.add_child(row)
		var button := Button.new()
		button.text = ("%s%s — %d XP" % ["    ↳ " if node[4] != "" else "", node[2], node[3]]) + (" [learned]" if model.learned.has(node[0]) else "")
		button.tooltip_text = node[7]
		button.disabled = not safe_now or not model.can_buy(node[0])
		row.add_child(button)
		var id: String = node[0]
		button.pressed.connect(func(): talent_action.emit("buy", id, 0))
		var description := Label.new()
		description.text = node[7]
		row.add_child(description)
		if node[5] == "active" and model.learned.has(id):
			for i in range(Skills.SLOT_COUNT):
				var slot := Button.new()
				slot.text = str(i + 1)
				slot.disabled = not safe_now
				row.add_child(slot)
				slot.pressed.connect(func(): talent_action.emit("slot", id, i))
	refund.disabled = not safe_now or not shrine_now
