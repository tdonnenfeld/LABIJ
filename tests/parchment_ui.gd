extends SceneTree

const Parchment = preload("res://game/ui/parchment.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	check(Parchment.paper().get_width() == 96 and Parchment.paper() == Parchment.paper(), "Cached original paper")
	check(Parchment.build(true) != Parchment.build(false), "Distinct paper and HUD themes")
	check(Parchment.build(true).get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "Paper panel")
	check(Parchment.build(false).get_stylebox("panel", "PanelContainer") is StyleBoxFlat, "Dark HUD plate")
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.action_slots.size() == 3, "Three ability slots")
	check(not main.hp_bar.show_percentage and main.hp_bar.get_child_count() == 1, "Exact resource label")
	check(main.inventory_ui.get_theme_stylebox("panel") is StyleBoxTexture, "Parchment inventory theme")
	check(main.menu.visible and not main.hp_bar.visible, "Menu visible before expedition")
	check(main.minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Map does not capture mouse")
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
