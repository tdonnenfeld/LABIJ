extends PanelContainer

const COLORS := {"Combat": Color("#e4b9a0"), "XP": Color("#c5b8ec"), "Loot": Color("#a9db9b"), "Party": Color("#a8cbe2")}
var history: Array = []
var filter := "All"
var feed: RichTextLabel
var last_id := 0

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for category in ["All", "Combat", "XP", "Loot", "Party"]:
		var button := Button.new()
		button.text = category
		button.focus_mode = Control.FOCUS_NONE
		tabs.add_child(button)
		button.pressed.connect(select_filter.bind(category))
	var hint := Label.new()
	hint.text = "Party log [L] — Esc for mouse / scroll"
	hint.add_theme_font_size_override("font_size", 12)
	column.add_child(hint)
	feed = RichTextLabel.new()
	feed.custom_minimum_size = Vector2(350, 112)
	feed.add_theme_font_size_override("normal_font_size", 13)
	feed.scroll_following = true
	feed.selection_enabled = true
	column.add_child(feed)

func select_filter(category: String) -> void:
	filter = category
	rebuild()

func receive(events: Array) -> void:
	var changed := false
	for event in events:
		if event.id <= last_id:
			continue
		last_id = event.id
		history.append(event)
		changed = true
	while history.size() > 200:
		history.pop_front()
	if changed:
		rebuild()

func rebuild() -> void:
	feed.clear()
	for event in history:
		if event.message == "" or (filter != "All" and event.category != filter):
			continue
		feed.push_color(COLORS.get(event.category, Color.WHITE))
		feed.add_text(event.message + "\n")
		feed.pop()

func reset() -> void:
	history.clear()
	last_id = 0
	filter = "All"
	rebuild()
