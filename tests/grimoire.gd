extends SceneTree

const Skills = preload("res://game/progression/skills.gd")
const UI = preload("res://game/progression/skills_ui.gd")
const Banner = preload("res://game/ui/level_up.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var ui := UI.new()
	root.add_child(ui)
	ui.size = Vector2(920, 500)
	ui.show()
	var model := Skills.new()
	model.gain(2000)
	for node in Skills.Talents.NODES:
		if node[8]:
			model.discovered.append(node[0])
	ui.refresh(model.state(), true)
	var paper: StyleBoxTexture = ui.get_theme_stylebox("panel")
	check(paper.texture.get_image().get_format() == Image.FORMAT_RGB8, "Opaque grimoire paper")
	for domain in range(Skills.TITLES.size()):
		ui.select_domain(domain)
		await process_frame
		var tree = ui.tree
		var nodes: Array = tree.buttons.values()
		for a in range(nodes.size()):
			var area: Rect2 = nodes[a].get_rect()
			check(Rect2(Vector2.ZERO, tree.custom_minimum_size).encloses(area), "Node contained in scroll canvas")
			for b in range(a + 1, nodes.size()):
				check(not area.intersects(nodes[b].get_rect()), "Talent nodes do not overlap")
		check(ui.size.y <= 500.0, "Grimoire fits logical viewport")
	ui.queue_free()
	var banner := Banner.new()
	root.add_child(banner)
	check(not banner.observe(1, "K") and not banner.visible, "Initial level silent")
	check(banner.observe(2, "K") and banner.visible and "2" in banner.headline.text, "Level-up shown")
	check(not banner.observe(2, "K"), "No duplicate on repeated snapshot")
	check(banner.observe(4, "P") and "+2 levels" in banner.subtitle.text and "[P]" in banner.subtitle.text, "Multiple levels and current keybind")
	banner._process(Banner.HOLD + Banner.FADE + 0.1)
	check(not banner.visible, "Notification expires")
	banner.reset()
	check(not banner.observe(1, "K"), "New run resets baseline")
	banner.queue_free()
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._solo()
	game.actors[1].gain_xp(100)
	await physics_frame
	await physics_frame
	check(game.level_up.visible and game.level_up.last_level == 2, "Local gameplay level-up")
	game.leave_expedition(false)
	check(not game.level_up.visible and game.level_up.last_level == 0, "Exit clears notification")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
