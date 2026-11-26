extends RefCounted

const UNARMED = preload("res://content/items/unarmed.tres")
const EMPTY_SHIELD = preload("res://content/items/empty_shield.tres")
const ITEMS := {
	"iron_helm": preload("res://content/items/iron_helm.tres"),
	"leather_gloves": preload("res://content/items/leather_gloves.tres"),
	"iron_boots": preload("res://content/items/iron_boots.tres"),
	"ward_amulet": preload("res://content/items/ward_amulet.tres"),
	"ward_ring": preload("res://content/items/ward_ring.tres"),
	"arrows": preload("res://content/items/arrows.tres"),
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

const AFFIXES := ["keen", "swift", "venom", "cursed", "runic", "warded", "vital"]
static var variants: Dictionary = {}
const RELICS := {"sword":"Dawncleaver", "mail":"Warden's Carapace", "iron_helm":"Warden's Crown", "iron_boots":"Warden's March", "staff":"Echo of the Abyss", "ward_amulet":"Oracle's Eye", "ward_ring":"Oracle's Promise"}

static func get_item(id: String) -> Resource:
	if id == "unarmed":
		return UNARMED
	if id == "empty_shield":
		return EMPTY_SHIELD
	if ITEMS.has(id):
		return ITEMS[id]
	if variants.has(id):
		return variants[id]
	if id.ends_with(":unknown"):
		var revealed := identify(id)
		var original = get_item(revealed)
		if original == null:
			return null
		var hidden = get_item(id.get_slice(":", 0)).duplicate()
		hidden.title = "Unidentified " + hidden.title
		variants[id] = hidden
		return hidden
	var parts := id.split(":")
	if parts.size() != 2 or not ITEMS.has(parts[0]) or not (parts[1] in AFFIXES or (parts[1] == "relic" and RELICS.has(parts[0]))):
		return null
	var base = ITEMS[parts[0]]
	if parts[1] in ["keen", "swift", "venom", "cursed", "runic"] and base.kind != "weapon":
		return null
	if parts[1] in ["warded", "vital"] and not base.kind in ["armor", "helmet", "gloves", "boots", "amulet", "ring", "shield"]:
		return null
	var item = base.duplicate()
	match parts[1]:
		"relic":
			item.title = RELICS[parts[0]]
			item.damage *= 1.35
			item.spell_power += 0.18
			item.armor = minf(0.4, item.armor + 0.07)
			item.magic_resistance = minf(0.4, item.magic_resistance + 0.08)
			item.tint = Color("#d6b66a")
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
		"cursed":
			item.title = "Cursed " + item.title
			item.damage *= 1.45
			item.stamina_cost *= 1.35
		"runic":
			item.title = "Runebound " + item.title
			item.damage *= 1.2
			item.spell_power += 0.15
		"warded":
			item.title += " of Warding"
			item.magic_resistance = minf(0.35, item.magic_resistance + 0.08)
		"vital":
			item.title += " of Fortitude"
			item.armor = minf(0.35, item.armor + 0.05)
	variants[id] = item
	return item

static func enchant(id: String, rng: RandomNumberGenerator) -> String:
	var item = ITEMS.get(id)
	if item == null:
		return id
	var choices: Array = []
	if item.kind == "weapon":
		choices = ["keen", "swift", "runic", "cursed"] if item.projectile_speed > 0 else ["keen", "swift", "venom", "runic", "cursed"]
	elif item.kind in ["armor", "helmet", "gloves", "boots", "amulet", "ring", "shield"]:
		choices = ["warded", "vital"]
	if choices.is_empty():
		return id
	return id + ":" + choices[rng.randi_range(0, choices.size() - 1)]

static func noise_multiplier(id: String) -> float:
	match id.get_slice(":", 0):
		"leather": return 1.1
		"mail": return 1.5
		"ward_mail": return 1.3
		"axe": return 1.25
		"venom_dagger": return 0.7
		_: return 1.0

static func dimensions(id: String) -> Vector2i:
	match id.get_slice(":", 0):
		"iron_helm", "iron_boots": return Vector2i(2, 2)
		"leather_gloves": return Vector2i(2, 1)
		"sword", "staff", "ember_staff", "oracle_staff": return Vector2i(1, 3)
		"spear": return Vector2i(1, 4)
		"axe", "bow", "longbow": return Vector2i(2, 3)
		"leather", "mail", "ward_mail": return Vector2i(2, 3)
		"shield", "iron_shield", "warden_shield": return Vector2i(2, 2)
		"venom_dagger", "arrows": return Vector2i(1, 2)
		_: return Vector2i.ONE

static func stack_limit(id: String) -> int:
	match id:
		"potion": return 5
		"noise_stone": return 10
		"arrows": return 40
		_: return 1

static func identify(id: String) -> String:
	return id.trim_suffix(":unknown")

static func rarity(id: String) -> String:
	var known := identify(id)
	if known.ends_with(":relic") or known in ["warden_shield", "oracle_staff"]:
		return "Legendary"
	if known.ends_with(":runic") or known.ends_with(":cursed"):
		return "Rare"
	if known.contains(":"):
		return "Uncommon"
	return "Common"

static func rarity_color(id: String) -> Color:
	match rarity(id):
		"Legendary": return Color("#e3b65c")
		"Rare": return Color("#a890df")
		"Uncommon": return Color("#8cbf8a")
		_: return Color("#e4dfd3")

static func set_name(id: String) -> String:
	if not id.ends_with(":relic"):
		return ""
	match id.get_slice(":", 0):
		"mail", "iron_helm", "iron_boots": return "Warden"
		"staff", "ward_amulet", "ward_ring": return "Oracle"
		_: return ""
