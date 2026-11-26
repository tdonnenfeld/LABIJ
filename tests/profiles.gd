extends SceneTree

const Player = preload("res://game/player.gd")
const Profiles = preload("res://game/progression/profiles.gd")
const Meter = preload("res://game/ui/noise_meter.gd")
const World = preload("res://game/world.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	check(not actor.configure_profile("Invalid", -1, 0), "Reject invalid species")
	check(actor.configure_profile("  Gimli  ", 1, 1), "Dwarf vanguard")
	check(actor.display_name == "Gimli" and actor.health == 115.0 and actor.max_health() == 115.0, "Name and racial health")
	check(actor.inventory.weapon == "axe" and actor.inventory.shield == "iron_shield", "Starting equipment")
	check(is_equal_approx(actor.skills.xp[4], 30.0), "Starting XP with aptitude")
	actor.skills.credit(4, 10)
	check(is_equal_approx(actor.skills.xp[4], 42.0), "Usage XP aptitude")
	actor.skills.gain(50)
	check(is_equal_approx(actor.skills.xp[4], 66.0), "Allocated XP aptitude")
	check(not actor.configure_profile("Other", 0, 0), "Profile immutable")
	var mage := Player.new()
	root.add_child(mage)
	mage.setup(false, false)
	check(mage.configure_profile("Mage", 2, 3), "Elf arcanist")
	check(mage.health == 90.0 and mage.inventory.weapon == "staff" and mage.skills.mastery(6) == 1, "Mage stats and mastery")
	check(mage.use_item(3) and mage.skills.learned.has("firebolt"), "Starting scroll still requires reading")
	var scout := Player.new()
	root.add_child(scout)
	scout.setup(false, false)
	check(scout.configure_profile("Scout", 3, 2), "Halfling scout")
	check(scout.inventory.items.has("noise_stone") and scout.inventory.weapon == "bow", "Scout equipment")
	var world := World.new()
	root.add_child(world)
	world.build(123, false)
	world.player_noise(scout, 10.0)
	check(is_equal_approx(scout.noise_level, 8.0) and is_equal_approx(scout.noise_peak, 8.0), "Species noise and immediate peak")
	scout.decay_noise(0.5)
	check(is_equal_approx(scout.noise_level, 4.0) and is_equal_approx(scout.noise_peak, 8.0), "Peak hold")
	scout.decay_noise(0.5)
	check(is_equal_approx(scout.noise_level, 0.0) and is_equal_approx(scout.noise_peak, 7.3), "Slow peak decay")
	scout.register_noise(12.0)
	check(scout.noise_peak == 12.0 and scout.noise_level == 12.0, "New peak resets hold")
	var meter := Meter.new()
	root.add_child(meter)
	meter.update_levels(3.0, 8.0)
	check(meter.level == 3.0 and meter.peak == 8.0, "Meter displays current and peak")
	check(Profiles.clean_name("A\nB") == "AB", "Sanitize profile name")
	quit(0 if failures == 0 else 1)
