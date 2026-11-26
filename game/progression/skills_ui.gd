extends PanelContainer

const Skills = preload("res://game/progression/skills.gd")
signal priority_changed(index: int, value: int)
var model := Skills.new()
var heading: Label
var levels: Array[Label] = []
var progress: Array[ProgressBar] = []
var buttons: Array[OptionButton] = []

func _ready() -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	add_child(column)
	heading = Label.new()
	column.add_child(heading)
	var hint := Label.new()
	hint.text = "Train skills using earned XP. Off / Normal / Focus (2x)"
	column.add_child(hint)
	for i in range(Skills.IDS.size()):
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 135
		row.add_child(label)
		levels.append(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.x = 110
		bar.max_value = 1
		bar.show_percentage = false
		row.add_child(bar)
		progress.append(bar)
		var option := OptionButton.new()
		for title in ["Off", "Normal", "Focus"]:
			option.add_item(title)
		row.add_child(option)
		buttons.append(option)
		option.item_selected.connect(func(value): priority_changed.emit(i, value))
	hide()

func refresh(data: Array) -> void:
	model.apply(data)
	heading.text = "Skills [K]   |   Level %d   |   %d XP" % [model.character_level(), model.total_xp]
	for i in range(Skills.IDS.size()):
		var level := model.skill_level(i)
		levels[i].text = "%s  %d" % [Skills.TITLES[i], level]
		buttons[i].select(model.priorities[i])
		var start := Skills.threshold(level)
		var end := Skills.threshold(level + 1)
		progress[i].value = 1.0 if level == Skills.MAX_LEVEL else (model.xp[i] - start) / (end - start)
