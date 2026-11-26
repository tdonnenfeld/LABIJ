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
	"mail": preload("res://content/items/mail.tres")
}

static func get_item(id: String) -> Resource:
	return ITEMS.get(id)
