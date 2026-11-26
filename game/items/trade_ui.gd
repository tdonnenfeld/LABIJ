extends PanelContainer

const Parchment = preload("res://game/ui/parchment.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Trade = preload("res://game/items/trade.gd")
signal action(operation: String, value: int, session_id: int, version: int, revision: int)
var session: Dictionary = {"id": 0, "notice": ""}
var revision := -1
var targets := PackedStringArray()
var target_ids: Array[int] = []
var offer_entries := PackedStringArray()
var offer_indices: Array[int] = []
var target_select: OptionButton
var offer_select: OptionButton
var status: Label
var offer_label: Label
var invite: Button
var join: Button
var offer: Button
var confirm: Button
var cancel: Button

func _ready() -> void:
	theme = Parchment.build(true)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 410
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var heading := Label.new()
	heading.text = "Companion exchange"
	Parchment.heading(heading, 24)
	column.add_child(heading)
	var hint := Label.new()
	hint.text = "[J] / Esc to close · 3.5 m · outside combat"
	column.add_child(hint)
	column.add_child(HSeparator.new())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	target_select = OptionButton.new()
	column.add_child(target_select)
	invite = button(column, "Invite companion", func(): send("invite", target_ids[target_select.selected]) if target_select.selected >= 0 and target_select.selected < target_ids.size() else send("noop"))
	join = button(column, "Accept invitation", func(): send("join"))
	offer_select = OptionButton.new()
	column.add_child(offer_select)
	offer = button(column, "Set offered stack", func(): send("offer", offer_indices[offer_select.selected]) if offer_select.selected >= 0 and offer_select.selected < offer_indices.size() else send("noop"))
	offer_label = Label.new()
	offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(offer_label)
	confirm = button(column, "Confirm exchange", func(): send("confirm"))
	cancel = button(column, "Cancel exchange", func(): send("cancel"))
	refresh_state({"id": 0, "notice": ""})
	hide()

func button(column: VBoxContainer, caption: String, handler: Callable) -> Button:
	var control := Button.new()
	control.text = caption
	control.pressed.connect(handler)
	column.add_child(control)
	return control

func refresh_inventory(local, local_id: int, actors: Dictionary) -> void:
	revision = local.inventory.revision
	var names := PackedStringArray()
	var ids: Array[int] = []
	for peer in actors:
		if peer != local_id and Trade.nearby(local, actors[peer]):
			ids.append(peer)
			names.append(actors[peer].display_name)
	if names != targets or ids != target_ids:
		targets = names
		target_ids = ids
		target_select.clear()
		for name in names:
			target_select.add_item(name)
		if not ids.is_empty():
			target_select.select(0)
	var entries := PackedStringArray(["Nothing (gift)"])
	var indices: Array[int] = [-1]
	for i in range(local.inventory.items.size()):
		if local.inventory.is_equipped(i):
			continue
		entries.append("%s ×%d" % [Catalog.get_item(local.inventory.items[i]).title, local.inventory.quantity(i)])
		indices.append(i)
	if entries != offer_entries or indices != offer_indices:
		offer_entries = entries
		offer_indices = indices
		offer_select.clear()
		for entry in entries:
			offer_select.add_item(entry)
		offer_select.select(0)
	update_controls()

func refresh_state(data: Dictionary) -> void:
	session = data.duplicate(true)
	update_controls()

func update_controls() -> void:
	if not is_instance_valid(status):
		return
	var engaged: bool = session.get("id", 0) != 0
	var joined: bool = session.get("joined", false)
	var current: bool = revision == session.get("revision", -2)
	target_select.visible = not engaged
	invite.visible = not engaged
	invite.disabled = target_ids.is_empty()
	join.visible = engaged and session.get("incoming", false)
	join.disabled = not current
	offer_select.visible = joined
	offer.visible = joined
	offer.disabled = not current
	offer_label.visible = joined
	confirm.visible = joined
	confirm.disabled = not current or session.get("confirmed", false) or (session.get("own", -1) == -1 and session.get("other", -1) == -1)
	cancel.visible = engaged
	if not engaged:
		var notice: String = session.get("notice", "")
		status.text = notice if not notice.is_empty() else "Choose a nearby companion. Both must confirm the final exchange."
	elif not joined:
		status.text = "%s invites you to trade." % session.name if session.incoming else "Waiting for %s to accept." % session.name
	else:
		status.text = "Exchange with %s" % session.name
		offer_label.text = "You offer: %s\nThey offer: %s\nYou: %s · Companion: %s" % [session.own_text, session.other_text, "Confirmed" if session.confirmed else "Reviewing", "Confirmed" if session.other_confirmed else "Reviewing"]
		confirm.text = "Confirmed" if session.confirmed else "Confirm exchange"

func send(operation: String, value: int = -1) -> void:
	if operation == "noop":
		return
	action.emit(operation, value, session.get("id", 0), session.get("version", 0), revision)
