extends RefCounted

const ICONS := {
	"iron_helm": preload("res://art/ui/icons/items/iron_helm.svg"),
	"leather_gloves": preload("res://art/ui/icons/items/leather_gloves.svg"),
	"iron_boots": preload("res://art/ui/icons/items/iron_boots.svg"),
	"ward_amulet": preload("res://art/ui/icons/items/ward_amulet.svg"),
	"ward_ring": preload("res://art/ui/icons/items/ward_ring.svg"),
	"arrows": preload("res://art/ui/icons/items/arrows.svg"),
	"sword": preload("res://art/ui/icons/items/sword.svg"),
	"axe": preload("res://art/ui/icons/items/axe.svg"),
	"spear": preload("res://art/ui/icons/items/spear.svg"),
	"shield": preload("res://art/ui/icons/items/shield.svg"),
	"iron_shield": preload("res://art/ui/icons/items/iron_shield.svg"),
	"potion": preload("res://art/ui/icons/items/potion.svg"),
	"staff": preload("res://art/ui/icons/items/staff.svg"),
	"leather": preload("res://art/ui/icons/items/leather.svg"),
	"mail": preload("res://art/ui/icons/items/mail.svg"),
	"bow": preload("res://art/ui/icons/items/bow.svg"),
	"longbow": preload("res://art/ui/icons/items/longbow.svg"),
	"venom_dagger": preload("res://art/ui/icons/items/venom_dagger.svg"),
	"ember_staff": preload("res://art/ui/icons/items/ember_staff.svg"),
	"ward_mail": preload("res://art/ui/icons/items/ward_mail.svg"),
	"warden_shield": preload("res://art/ui/icons/items/warden_shield.svg"),
	"oracle_staff": preload("res://art/ui/icons/items/oracle_staff.svg"),
	"noise_stone": preload("res://art/ui/icons/items/noise_stone.svg"),
	"jewel": preload("res://art/ui/icons/items/jewel.svg"),
	"scroll_firebolt": preload("res://art/ui/icons/items/scroll_firebolt.svg"),
	"scroll_frostbolt": preload("res://art/ui/icons/items/scroll_frostbolt.svg"),
	"scroll_spark": preload("res://art/ui/icons/items/scroll_spark.svg"),
	"scroll_stonebolt": preload("res://art/ui/icons/items/scroll_stonebolt.svg"),
	"scroll_fireball": preload("res://art/ui/icons/items/scroll_fireball.svg"),
	"scroll_freeze": preload("res://art/ui/icons/items/scroll_freeze.svg"),
	"scroll_thunder": preload("res://art/ui/icons/items/scroll_thunder.svg"),
	"scroll_boulder": preload("res://art/ui/icons/items/scroll_boulder.svg")
}
const FALLBACK = preload("res://art/ui/icons/items/fallback.svg")

static func texture(id: String) -> Texture2D:
	return ICONS.get(id.get_slice(":", 0), FALLBACK)
