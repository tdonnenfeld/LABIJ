extends SceneTree

const Dungeon = preload("res://game/dungeon.gd")
const ThemeKit = preload("res://game/visuals/stone_theme.gd")
const Builder = preload("res://game/visuals/dungeon_visual_builder.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func collision_signature(level: Node3D) -> Array:
	var result: Array = []
	for child in level.get_children():
		if child is StaticBody3D:
			var shape: BoxShape3D = child.get_child(child.get_child_count() - 1).shape
			result.append([child.position, shape.size])
	return result

func run() -> void:
	var plain := Dungeon.new()
	root.add_child(plain)
	plain.generate(42069, false, 3)
	var decorated := Dungeon.new()
	root.add_child(decorated)
	decorated.generate(42069, true, 3)
	check(plain.tiles == decorated.tiles and plain.rooms == decorated.rooms and plain.end_cell == decorated.end_cell, "Art preserves generation")
	check(collision_signature(plain) == collision_signature(decorated), "Art preserves collision shapes")
	check(plain.visual_builder == null and decorated.visual_builder != null, "No art on headless generation")
	var builder = decorated.visual_builder
	check(builder.lights.size() == 4 and not builder.torches.is_empty(), "Bounded torch pool")
	var rendered: Dictionary = {}
	for batch in builder.batches.values():
		if batch.material in ["floor", "floor1", "floor2", "floor3"]:
			for transform in batch.transforms:
				var cell := Vector2i(roundi(transform.origin.x / Dungeon.CELL), roundi(transform.origin.z / Dungeon.CELL))
				rendered[cell] = int(rendered.get(cell, 0)) + 1
	var expected := plain.tiles.duplicate()
	for cell in plain.hidden_tiles:
		expected[cell] = true
	check(rendered.size() == expected.size(), "All floor cells rendered")
	for cell in expected:
		check(rendered.get(cell, 0) == 1, "Every cell rendered once: %s" % cell)
	check(ThemeKit.material("floor") == ThemeKit.material("floor"), "Shared material cache")
	check(ThemeKit.material("wall").albedo_texture.get_width() == 128, "Low resolution texture")
	builder.update_lighting(builder.torches[0], 0.3)
	check(builder.lights[0].visible, "Torch lights activate near viewer")
	var before := collision_signature(decorated)
	Builder.route_marker(decorated, Vector3.ZERO, Color.GOLD, true)
	check(collision_signature(decorated) == before, "Route art never adds collision")
	quit(0 if failures == 0 else 1)
