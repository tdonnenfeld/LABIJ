extends RefCounted

const ITEMS := {
	"sword": preload("res://content/items/sword.tres"),
	"axe": preload("res://content/items/axe.tres"),
	"spear": preload("res://content/items/spear.tres"),
	"shield": preload("res://content/items/shield.tres"),
	"iron_shield": preload("res://content/items/iron_shield.tres"),
	"potion": preload("res://content/items/potion.tres")
}

static func get_item(id: String) -> Resource:
	return ITEMS.get(id)
