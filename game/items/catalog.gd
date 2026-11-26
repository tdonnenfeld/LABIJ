extends RefCounted

const ITEMS := {
	"sword": preload("res://content/items/sword.tres"),
	"axe": preload("res://content/items/axe.tres"),
	"spear": preload("res://content/items/spear.tres"),
	"shield": preload("res://content/items/shield.tres"),
	"iron_shield": preload("res://content/items/iron_shield.tres"),
	"potion": preload("res://content/items/potion.tres"),
	"scroll_firebolt": preload("res://content/items/scroll_firebolt.tres"),
	"scroll_frostbolt": preload("res://content/items/scroll_frostbolt.tres"),
	"scroll_spark": preload("res://content/items/scroll_spark.tres"),
	"scroll_stonebolt": preload("res://content/items/scroll_stonebolt.tres"),
	"scroll_fireball": preload("res://content/items/scroll_fireball.tres"),
	"scroll_freeze": preload("res://content/items/scroll_freeze.tres"),
	"scroll_thunder": preload("res://content/items/scroll_thunder.tres"),
	"scroll_boulder": preload("res://content/items/scroll_boulder.tres"),
	"staff": preload("res://content/items/staff.tres"),
	"leather": preload("res://content/items/leather.tres"),
	"mail": preload("res://content/items/mail.tres"),
	"bow": preload("res://content/items/bow.tres"),
	"longbow": preload("res://content/items/longbow.tres"),
	"venom_dagger": preload("res://content/items/venom_dagger.tres"),
	"ember_staff": preload("res://content/items/ember_staff.tres"),
	"ward_mail": preload("res://content/items/ward_mail.tres"),
	"warden_shield": preload("res://content/items/warden_shield.tres"),
	"oracle_staff": preload("res://content/items/oracle_staff.tres"),
	"noise_stone": preload("res://content/items/noise_stone.tres")
}

const AFFIXES := ["keen", "swift", "venom"]
static var variants: Dictionary = {}

static func get_item(id: String) -> Resource:
	if ITEMS.has(id):
		return ITEMS[id]
	if variants.has(id):
		return variants[id]
	var parts := id.split(":")
	if parts.size() != 2 or not ITEMS.has(parts[0]) or not parts[1] in AFFIXES:
		return null
	var base = ITEMS[parts[0]]
	if base.kind != "weapon":
		return null
	var item = base.duplicate()
	match parts[1]:
		"keen":
			item.title += " of Precision"
			item.damage *= 1.2
		"swift":
			item.title += " of Haste"
			item.windup *= 0.85
			item.recovery *= 0.85
		"venom":
			item.title += " of Venom"
			item.poison += 2.0
	variants[id] = item
	return item

static func enchant(id: String, rng: RandomNumberGenerator) -> String:
	var item = ITEMS.get(id)
	if item == null or item.kind != "weapon":
		return id
	var choices := ["keen", "swift"] if item.projectile_speed > 0 else AFFIXES
	return id + ":" + choices[rng.randi_range(0, choices.size() - 1)]

static func noise_multiplier(id: String) -> float:
	match id.get_slice(":", 0):
		"leather": return 1.1
		"mail": return 1.5
		"ward_mail": return 1.3
		"axe": return 1.25
		"venom_dagger": return 0.7
		_: return 1.0
