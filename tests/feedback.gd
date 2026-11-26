extends SceneTree

const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const Journal = preload("res://game/world/journal.gd")
const InventoryUI = preload("res://game/items/inventory_ui.gd")
const Catalog = preload("res://game/items/catalog.gd")
const Numbers = preload("res://game/ui/numbers.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.display_name = "Player 1"
	world.watch_player(actor, 1)
	var partner := Player.new()
	root.add_child(partner)
	partner.setup(false, false)
	world.watch_player(partner, 2)
	actor.blocking = true
	actor.take_damage(20.0, actor.position + Vector3(0, 0, -2), false, "Goblin")
	var event: Dictionary = world.journal.history.back()
	check(event.floating.contains("Blocked") and event.target == 1 and is_equal_approx(actor.health, 96.0), "Blocked hit: %s, HP %s" % [event, actor.health])
	actor.skills.credit(4, 2.5)
	check(world.journal.history.back().message == "Player 1 gains 2.5 Shields XP", "Fractional XP: %s" % world.journal.history.back().message)
	actor.gain_xp(100)
	check(world.journal.history.back().category == "XP", "Kill XP must be logged")
	var mob: Dictionary = world.monsters[0]
	mob.health = 100
	world.hit_monster(actor, mob, {1: actor, 2: partner})
	check(world.journal.history.any(func(e): return e.style == "damage"), "Monster hit must emit damage text")
	actor.blocking = false
	actor.take_damage(999.0, actor.position, false, "Ogre")
	check(world.objective.result == "defeat" and partner.health == 100.0, "One death must end the run with a living partner")
	check(world.journal.history.back().message.contains("Expedition lost"), "Defeat must be logged")
	var j := Journal.new()
	for i in range(220):
		j.add("Party", str(i))
	check(j.history.size() == 200, "Journal history cap")
	check(j.drain().size() == 220 and j.drain().is_empty(), "Journal drain")
	check(Numbers.number(35.0) == "35", "Whole number formatting")
	check(Numbers.number(3.4) == "3.4", "Fractional number formatting")
	check(Numbers.number(0.0) == "0", "Zero formatting")
	var ui := InventoryUI.new()
	root.add_child(ui)
	ui.show()
	for id in Catalog.ITEMS:
		ui.refresh([["sword", "shield", id], 0, 1, -1])
		ui.list.select(2)
		ui.update_details()
		var selected := ui.list.get_selected_items()
		check(selected.size() == 1 and selected[0] == 2, "Selection failed for %s: %s" % [id, selected])
		var item = Catalog.get_item(id)
		var expected := ""
		match item.kind:
			"weapon":
				expected = "Damage "
			"shield":
				expected = "Damage blocked:"
			"armor":
				expected = "Damage reduction:"
			"scroll":
				expected = "Read to learn permanently"
			_:
				expected = "Restores "
		check(ui.details.text.begins_with(expected), "Inventory %s: %s" % [id, ui.details.text])
		if id == "spear":
			check(ui.details.text.contains("3.4 m"), "Spear reach: %s" % ui.details.text)
		if id == "ward_mail":
			check(ui.details.text.contains("15%") and ui.details.text.contains("30%"), "Runed Mail: %s" % ui.details.text)
		if id == "potion":
			check(ui.details.text == "Restores 35 HP", "Potion: %s" % ui.details.text)
	quit(0 if failures == 0 else 1)
