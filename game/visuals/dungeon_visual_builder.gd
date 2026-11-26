extends Node3D

const Props = preload("res://game/visuals/dungeon_props.gd")
const StoneKit = preload("res://game/visuals/stone_theme.gd")
const CELL := 3.0
const CHUNK := 8
const LIGHT_LIMIT := 4
const SIDES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var batches: Dictionary = {}
var torches: Array[Vector3] = []
var lights: Array[OmniLight3D] = []
var light_timer := 0.0
var theme_id := 0
var room_styles: Dictionary = {}
var moving_props: Array = []
var water_time := 0.0
const ROOM_STYLES := ["crypt", "storeroom", "library", "shrine", "prison", "cistern", "armory", "ruins"]
const THEMES := [Color("#ffffff"), Color("#a3a09b"), Color("#7598a4"), Color("#b8a587"), Color("#8f9ca6"), Color("#b99580"), Color("#c5b69a")]

func box(id: String, at: Vector3, size: Vector3, angle: float = 0.0) -> void:
	var chunk := Vector2i(floori(at.x / (CELL * CHUNK)), floori(at.z / (CELL * CHUNK)))
	var key := "%s:%d:%d" % [id, chunk.x, chunk.y]
	if not batches.has(key):
		batches[key] = {"material": id, "transforms": []}
	var basis := Basis(Vector3.UP, angle).scaled_local(size)
	batches[key].transforms.append(Transform3D(basis, at))

func build(tiles: Dictionary, seed_value: int, corridor_blocks: Array = [], floor_theme: int = 0, room_bounds: Array = [], ceiling_heights: Dictionary = {}, bridge_cells: Dictionary = {}, arena_cells: Dictionary = {}, architecture: Array = [], gate_cells: Dictionary = {}) -> void:
	theme_id = clampi(floor_theme, 0, THEMES.size() - 1)
	for i in range(room_bounds.size()):
		var bounds: Rect2i = room_bounds[i]
		var style: String = ROOM_STYLES[posmod(seed_value + i * 13 + theme_id * 3, ROOM_STYLES.size())]
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				room_styles[Vector2i(x, y)] = style
	var narrowed: Dictionary = {}
	for block in corridor_blocks:
		var at: Vector3 = block[0]
		narrowed[Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))] = true
	for key in tiles:
		var cell: Vector2i = key
		var origin := Vector3(cell.x * CELL, 0, cell.y * CELL)
		var style: String = room_styles.get(cell, "corridor")
		var height: float = ceiling_heights.get(cell, 3.0)
		var tile_variant := posmod(cell.x * 73 + cell.y * 151 + seed_value, 11)
		var floor_id := "floor" if tile_variant < 5 else "floor%d" % (1 + tile_variant % 3)
		box(floor_id, origin + Vector3.DOWN * 0.15, Vector3(3, 0.3, 3))
		if not narrowed.has(cell):
			decorate_floor(origin, cell, style, seed_value)
		box("ceiling", origin + Vector3.UP * (height + 0.15), Vector3(3, 0.3, 3))
		if height > 3.0:
			vault(origin, height)
		if bridge_cells.has(cell):
			bridge(origin, bridge_cells[cell])
		if gate_cells.has(cell):
			open_gate(origin, gate_cells[cell])
		if arena_cells.has(cell):
			arena_tile(origin, cell, seed_value)
		for side in SIDES:
			if tiles.has(cell + side):
				var neighbor: float = ceiling_heights.get(cell + side, 3.0)
				if height > neighbor:
					var edge := origin + Vector3(side.x, 0, side.y) * 1.5
					box("wall", edge + Vector3.UP * (height + neighbor) * 0.5, Vector3(3, height - neighbor, 0.2), PI / 2.0 if side.x != 0 else 0.0)
				continue
			var normal := Vector3(side.x, 0, side.y)
			var angle := PI / 2.0 if side.x != 0 else 0.0
			var at := origin + normal * 1.5
			var wall_variant := posmod(cell.x * 31 + cell.y * 79 + side.x * 11 + side.y * 17 + seed_value, 9)
			var wall_id := "wall" if wall_variant < 5 else "wall%d" % (1 + wall_variant % 3)
			box(wall_id, at + Vector3.UP * height * 0.5, Vector3(3, height, 0.2), angle)
			box("trim", at - normal * 0.025 + Vector3.UP * 0.12, Vector3(3, 0.24, 0.22), angle)
			box("trim", at - normal * 0.025 + Vector3.UP * (height - 0.12), Vector3(3, 0.24, 0.22), angle)
			var hash_value := posmod(cell.x * 73 + cell.y * 151 + side.x * 17 + side.y * 31 + seed_value, 19)
			if hash_value == 0 and not narrowed.has(cell):
				add_torch(at, normal, angle)
			if not narrowed.has(cell) and abs(cell.x) + abs(cell.y) > 2:
				decorate_wall(at, normal, angle, style, hash_value)
				decorate_special(at, normal, angle, style, hash_value)
			if hash_value in [4, 11] and not narrowed.has(cell):
				box("wall", at - normal * 0.04 + Vector3.UP * 1.5, Vector3(0.34, 3.0, 0.20), angle)
		add_arch(tiles, cell, origin)
		if not narrowed.has(cell):
			decorate_cell(tiles, cell, origin, seed_value)
			decorate_corner(tiles, cell, origin, style, seed_value)
			decorate_theme(tiles, cell, origin, seed_value)
	for block in corridor_blocks:
		var at: Vector3 = block[0]
		var cell := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
		if bridge_cells.has(cell):
			# Existing collision walls stay in place; dark sides suggest a recessed channel.
			box("dark", at, block[1])
		else:
			box("wall", at, block[1])
	for feature in architecture:
		if feature.kind == "dais":
			for i in range(3):
				box("trim", feature.at + Vector3.UP * (0.05 + i * 0.09), Vector3(0.62 - i * 0.12, 0.10, 0.62 - i * 0.12))
	flush_batches()
	for i in range(LIGHT_LIMIT):
		var light := OmniLight3D.new()
		light.light_color = [Color("#ffb56a"), Color("#d8ae85"), Color("#8bc5cf"), Color("#eac18c"), Color("#c7c9e2"), Color("#ff9766"), Color("#f8d58b")][theme_id]
		light.omni_range = 8.5
		light.omni_attenuation = 1.4
		light.light_energy = 1.7
		light.shadow_enabled = false
		add_child(light)
		light.hide()
		lights.append(light)

func add_arch(tiles: Dictionary, cell: Vector2i, origin: Vector3) -> void:
	for side in [Vector2i.RIGHT, Vector2i.DOWN]:
		var across := Vector2i(-side.y, side.x)
		if not tiles.has(cell + side) or not tiles.has(cell - side) or tiles.has(cell + across) or tiles.has(cell - across):
			continue
		for direction in [side, -side]:
			var next: Vector2i = cell + direction
			if not tiles.has(next + across) and not tiles.has(next - across):
				continue
			var forward := Vector3(direction.x, 0, direction.y)
			var cross := Vector3(across.x, 0, across.y)
			var angle := PI / 2.0 if direction.x != 0 else 0.0
			var at := origin + forward * 1.35
			box("trim", at + Vector3.UP * 2.88, Vector3(3.0, 0.24, 0.32), angle)
			for sign_value in [-1.0, 1.0]:
				box("trim", at + cross * sign_value * 1.40 + Vector3.UP * 1.45, Vector3(0.14, 2.90, 0.32), angle)
				box("wall", at + cross * sign_value * 1.25 + Vector3.UP * 2.75, Vector3(0.42, 0.30, 0.32), angle)

func add_torch(at: Vector3, normal: Vector3, angle: float) -> void:
	var stem := at - normal * 0.24 + Vector3.UP * 1.75
	box("iron", at - normal * 0.14 + Vector3.UP * 1.7, Vector3(0.20, 0.28, 0.12), angle)
	box("wood", stem, Vector3(0.11, 0.44, 0.11), angle)
	box("iron", stem + Vector3.UP * 0.22, Vector3(0.20, 0.13, 0.20), angle)
	box("flame", stem + Vector3.UP * 0.36, Vector3(0.17, 0.24, 0.17), PI / 4)
	box("ember", stem + Vector3.UP * 0.42, Vector3(0.09, 0.22, 0.09))
	torches.append(stem - normal * 0.18 + Vector3.UP * 0.32)

func flush_batches() -> void:
	for batch in batches.values():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = StoneKit.tinted(batch.material, THEMES[theme_id]) if (batch.material.begins_with("floor") or batch.material.begins_with("wall") or batch.material in ["ceiling", "trim"]) else StoneKit.material(batch.material)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = batch.transforms.size()
		for i in range(multimesh.instance_count):
			multimesh.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		add_child(instance)

func update_lighting(viewer: Vector3, delta: float) -> void:
	light_timer -= delta
	if light_timer <= 0.0:
		light_timer = 0.25
		var nearest: Array[Vector3] = []
		for at in torches:
			if at.distance_squared_to(viewer) <= 16.0 * 16.0:
				nearest.append(at)
		nearest.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(viewer) < b.distance_squared_to(viewer))
		for i in range(lights.size()):
			lights[i].visible = i < nearest.size()
			if lights[i].visible:
				lights[i].position = nearest[i]
	water_time += delta
	for entry in moving_props:
		var node: Node3D = entry.node
		if node.position.distance_squared_to(viewer) > 20.0 * 20.0:
			continue
		if entry.kind == "water":
			node.scale.y = 1.0 + sin(water_time * 4.0 + entry.phase) * 0.07
		elif entry.kind == "chain":
			node.rotation.z = sin(water_time * 1.5 + entry.phase) * 0.05
		else:
			var cloth := node.get_node_or_null("Cloth") as Node3D
			if cloth:
				cloth.rotation.x = sin(water_time * 2.0 + entry.phase) * 0.08
	var time := float(Time.get_ticks_msec()) / 1000.0
	for i in range(lights.size()):
		if lights[i].visible:
			var phase := lights[i].position.x * 0.8 + lights[i].position.z * 0.6
			lights[i].light_energy = 1.65 + 0.14 * sin(time * 7.7 + phase) + 0.09 * sin(time * 13.0 + phase)

static func route_marker(parent: Node3D, at: Vector3, color: Color, descending: bool) -> void:
	var stone := StoneKit.material("wall")
	var accent := StoneKit.solid(color, 0.65)
	for i in range(3):
		var step := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.7, 0.045, 0.52)
		step.mesh = mesh
		step.material_override = stone
		parent.add_child(step)
		step.position = at + Vector3(0, 0.025 + float(i) * 0.045, (float(i) - 1.0) * 0.53 * (1.0 if descending else -1.0))
		var rim := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(1.72, 0.025, 0.045)
		rim.mesh = strip
		rim.material_override = accent
		step.add_child(rim)
		rim.position = Vector3(0, 0.033, 0.24)

func decorate_cell(tiles: Dictionary, cell: Vector2i, origin: Vector3, seed_value: int) -> void:
	if abs(cell.x) + abs(cell.y) <= 2:
		return
	var walls: Array[Vector2i] = []
	for side in SIDES:
		if not tiles.has(cell + side):
			walls.append(side)
	if walls.size() != 2 or walls[0] == -walls[1]:
		return
	var variation := posmod(cell.x * 97 + cell.y * 53 + seed_value, 11)
	var normal := Vector3(walls[0].x, 0, walls[0].y)
	var across := Vector3(walls[1].x, 0, walls[1].y)
	var at := origin + (normal + across) * 1.12
	if variation == 0:
		box("wood", at + Vector3.UP * 0.27, Vector3(0.46, 0.53, 0.46))
		for y in [0.11, 0.44]:
			box("iron", at + Vector3.UP * y, Vector3(0.49, 0.045, 0.49))
	elif variation == 1:
		box("wood", at + Vector3.UP * 0.18, Vector3(0.50, 0.35, 0.50))
		box("wood", at + Vector3.UP * 0.39, Vector3(0.51, 0.08, 0.51))
		box("iron", at + Vector3.UP * 0.35 - normal * 0.26, Vector3(0.08, 0.10, 0.08))
	elif variation == 2:
		box("trim", at + Vector3.UP * 0.18, Vector3(0.45, 0.36, 0.45))
		box("ember", at + Vector3.UP * 0.43, Vector3(0.055, 0.13, 0.055))
	elif variation == 4:
		box("wood", at + Vector3.UP * 0.24, Vector3(0.48, 0.48, 0.48))
		for y in [0.08, 0.39]:
			box("iron", at + Vector3.UP * y, Vector3(0.50, 0.045, 0.50))
		box("wood", at + Vector3.UP * 0.53, Vector3(0.32, 0.10, 0.32), PI / 4.0)
	elif variation == 5:
		box("trim", at + Vector3.UP * 0.09, Vector3(0.52, 0.18, 0.52))
		box("wall", at + Vector3.UP * 0.37, Vector3(0.30, 0.48, 0.30), PI / 4.0)
		box("trim", at + Vector3.UP * 0.63, Vector3(0.43, 0.10, 0.43))
	elif variation == 3:
		for i in range(4):
			box("iron", at + normal * 0.22 + Vector3.UP * (1.1 + i * 0.15), Vector3(0.09, 0.16, 0.08), i * PI / 2.0)

func decorate_theme(tiles: Dictionary, cell: Vector2i, origin: Vector3, seed_value: int) -> void:
	if abs(cell.x) + abs(cell.y) <= 2:
		return
	var roll := posmod(cell.x * 83 + cell.y * 31 + seed_value, 7)
	if theme_id == 2 and roll < 3:
		box("water", origin + Vector3.UP * 0.012, Vector3(2.7, 0.02, 2.7))
	if roll != 0:
		return
	for side in SIDES:
		if tiles.has(cell + side):
			continue
		var normal := Vector3(side.x, 0, side.y)
		var across := Vector3(-side.y, 0, side.x)
		var at := origin + normal * 1.35
		if theme_id == 1:
			for j in range(-2, 3):
				box("iron", at + across * j * 0.23 + Vector3.UP * 1.3, Vector3(0.045, 2.6, 0.045))
		elif theme_id in [0, 4]:
			box("trim", at + Vector3.UP * 0.24, Vector3(0.48, 0.48, 0.48))
			box("wall", at + Vector3.UP * 0.65, Vector3(0.36, 0.28, 0.36))
		elif theme_id in [3, 6]:
			box("gold", at + Vector3.UP * 1.75, Vector3(0.32, 0.32, 0.32), PI / 4.0)
		break

func decorate_floor(origin: Vector3, cell: Vector2i, style: String, seed_value: int) -> void:
	var roll := posmod(cell.x * 41 + cell.y * 67 + seed_value, 17)
	if style in ["shrine", "library", "armory"]:
		for side in [-1.0, 1.0]:
			box("grout", origin + Vector3(side * 1.33, 0.009, 0), Vector3(0.035, 0.012, 2.7))
			box("marble", origin + Vector3(side * 1.22, 0.008, 0), Vector3(0.13, 0.012, 2.7))
		if roll < 3:
			box("gold", origin + Vector3.UP * 0.014, Vector3(0.45, 0.015, 0.45), PI / 4.0)
			box("marble", origin + Vector3.UP * 0.025, Vector3(0.24, 0.015, 0.24), PI / 4.0)
	elif style in ["cistern", "ruins"] and roll < 6:
		for i in range(3):
			var offset := Vector3(-0.95 + i * 0.18, 0.014, 0.8 + (i % 2) * 0.12)
			box("moss", origin + offset, Vector3(0.25, 0.02, 0.18), float(i))
	elif style == "crypt" and roll < 4:
		for i in range(3):
			box("bone", origin + Vector3(0.95 + i * 0.12, 0.035, -1.02 + i * 0.08), Vector3(0.055, 0.06, 0.24), float(i) * 1.3)
	if roll == 8:
		for i in range(3):
			box("rubble", origin + Vector3(-1.0 + i * 0.12, 0.04, 1.02), Vector3(0.17, 0.08, 0.13), float(i))

func decorate_wall(at: Vector3, normal: Vector3, angle: float, style: String, roll: int) -> void:
	var cross := Vector3(normal.z, 0, -normal.x)
	var base := at - normal * 0.19
	if roll in [0, 4, 11]:
		return
	if style == "library" and roll < 7:
		for y in [0.55, 1.05, 1.55, 2.05]:
			box("wood", base + Vector3.UP * y, Vector3(1.45, 0.09, 0.18), angle)
			for i in range(7):
				var color := ["book", "cloth", "cloth_blue", "paper"][posmod(i + int(y * 10) + roll, 4)]
				box(color, base + cross * (-0.57 + i * 0.19) + Vector3.UP * (y + 0.19), Vector3(0.13, 0.29 + 0.04 * (i % 2), 0.14), angle)
		for sign_value in [-1.0, 1.0]:
			box("wood", base + cross * sign_value * 0.76 + Vector3.UP * 1.3, Vector3(0.10, 1.65, 0.2), angle)
	elif style == "armory" and roll < 8:
		box("wood", base + Vector3.UP * 1.45, Vector3(1.5, 0.16, 0.16), angle)
		for i in range(4):
			var x := cross * (-0.55 + i * 0.36)
			box("wood", base + x + Vector3.UP * 1.35, Vector3(0.07, 1.45, 0.07), angle)
			box("iron", base + x + Vector3.UP * 2.1, Vector3(0.12, 0.27, 0.09), angle)
	elif style == "prison" and roll < 9:
		box("dark", base + Vector3.UP * 1.55, Vector3(1.55, 1.75, 0.07), angle)
		for i in range(7):
			box("iron", base - normal * 0.05 + cross * (-0.69 + i * 0.23) + Vector3.UP * 1.55, Vector3(0.06, 1.78, 0.09), angle)
		for y in [0.7, 2.4]:
			box("iron", base - normal * 0.05 + Vector3.UP * y, Vector3(1.58, 0.09, 0.10), angle)
	elif style == "shrine" and roll < 9:
		box("trim", base + Vector3.UP * 1.65, Vector3(0.88, 1.2, 0.15), angle)
		box("marble", base - normal * 0.07 + Vector3.UP * 1.65, Vector3(0.65, 0.95, 0.10), angle)
		box("gold", base - normal * 0.13 + Vector3.UP * 1.65, Vector3(0.35, 0.35, 0.10), angle + PI / 4.0)
	elif style in ["crypt", "ruins"] and roll < 8:
		box("dark", base + Vector3.UP * 1.35, Vector3(0.95, 1.6, 0.09), angle)
		for y in [0.52, 2.18]:
			box("trim", base - normal * 0.06 + Vector3.UP * y, Vector3(1.13, 0.16, 0.19), angle)
		box("bone", base - normal * 0.09 + Vector3.UP * 1.72, Vector3(0.24, 0.23, 0.14), angle)
		for sign_value in [-1.0, 1.0]:
			box("bone", base - normal * 0.09 + cross * sign_value * 0.12 + Vector3.UP * 1.35, Vector3(0.08, 0.38, 0.09), angle)
	elif style == "cistern" and roll < 9:
		for i in range(4):
			box("moss", base + cross * (-0.7 + i * 0.4) + Vector3.UP * (0.35 + (i % 2) * 0.23), Vector3(0.33, 0.55, 0.065), angle)
		box("iron", base + Vector3.UP * 0.45, Vector3(0.46, 0.48, 0.09), angle)
		for i in range(3):
			box("dark", base - normal * 0.06 + cross * (-0.14 + i * 0.14) + Vector3.UP * 0.45, Vector3(0.065, 0.34, 0.07), angle)
	elif style == "storeroom" and roll < 8:
		for y in [0.65, 1.25]:
			box("wood", base + Vector3.UP * y, Vector3(1.25, 0.10, 0.19), angle)
			for i in range(3):
				var offset := cross * (-0.38 + i * 0.38)
				box("clay", base + offset + Vector3.UP * (y + 0.19), Vector3(0.22, 0.28, 0.17), angle)
				box("clay", base + offset + Vector3.UP * (y + 0.36), Vector3(0.15, 0.07, 0.14), angle)
	elif roll in [9, 13]:
		box("wood", base + Vector3.UP * 2.35, Vector3(0.85, 0.09, 0.14), angle)
		box("cloth" if theme_id % 2 == 0 else "cloth_blue", base + Vector3.UP * 1.83, Vector3(0.65, 1.0, 0.08), angle)
		box("gold", base - normal * 0.05 + Vector3.UP * 1.9, Vector3(0.22, 0.22, 0.04), angle)

func decorate_corner(tiles: Dictionary, cell: Vector2i, origin: Vector3, style: String, seed_value: int) -> void:
	if abs(cell.x) + abs(cell.y) <= 2:
		return
	var walls: Array[Vector2i] = []
	for side in SIDES:
		if not tiles.has(cell + side):
			walls.append(side)
	if walls.size() != 2 or walls[0] == -walls[1]:
		return
	var roll := posmod(cell.x * 97 + cell.y * 53 + seed_value, 11)
	if roll < 6:
		return
	var n := Vector3(walls[0].x, 0, walls[0].y)
	var cross := Vector3(walls[1].x, 0, walls[1].y)
	var at := origin + (n + cross) * 1.12
	match style:
		"crypt":
			box("trim", at + Vector3.UP * 0.18, Vector3(0.52, 0.36, 0.52))
			box("bone", at + Vector3.UP * 0.43, Vector3(0.21, 0.19, 0.19))
			for side in [-1.0, 1.0]:
				box("dark", at + cross * side * 0.05 - n * 0.10 + Vector3.UP * 0.46, Vector3(0.042, 0.045, 0.042))
		"storeroom", "library":
			for j in range(3):
				box("wood", at + Vector3.UP * (0.12 + j * 0.16), Vector3(0.44, 0.15, 0.44), float(j) * 0.12)
				box("iron", at + Vector3.UP * (0.19 + j * 0.16), Vector3(0.46, 0.035, 0.46))
		"shrine":
			box("marble", at + Vector3.UP * 0.25, Vector3(0.44, 0.5, 0.44))
			box("gold", at + Vector3.UP * 0.53, Vector3(0.49, 0.08, 0.49))
			for j in range(3):
				box("paper", at + cross * (j - 1) * 0.11 + Vector3.UP * 0.66, Vector3(0.065, 0.18, 0.065))
				box("ember", at + cross * (j - 1) * 0.11 + Vector3.UP * 0.78, Vector3(0.045, 0.08, 0.045))
		"cistern":
			for j in range(3):
				box("crystal", at + cross * (j - 1) * 0.13 + Vector3.UP * (0.18 + j * 0.065), Vector3(0.10, 0.36 + j * 0.13, 0.10), float(j) * 0.7)
		"armory":
			box("wood", at + Vector3.UP * 0.38, Vector3(0.46, 0.76, 0.46))
			box("iron", at - n * 0.24 + Vector3.UP * 0.52, Vector3(0.12, 0.42, 0.33))
		_:
			for j in range(4):
				box("rubble", at - n * j * 0.07 + Vector3.UP * (0.07 + j * 0.045), Vector3(0.25, 0.13, 0.22), float(j) * 0.9)

func vault(origin: Vector3, height: float) -> void:
	for side in [-1.0, 1.0]:
		for i in range(4):
			var x := side * (1.34 - i * 0.34)
			var y := height - 0.85 + sqrt(maxf(0.0, 0.85 * 0.85 - x * x * 0.35))
			box("trim", origin + Vector3(x, y, 0), Vector3(0.38, 0.17, 0.20))
		box("wall", origin + Vector3(side * 1.34, height - 0.75, 0), Vector3(0.22, 0.8, 0.25))

func bridge(origin: Vector3, axis: Vector2i) -> void:
	var along := Vector3(axis.x, 0, axis.y)
	var across := Vector3(-axis.y, 0, axis.x)
	var angle := PI / 2.0 if axis.x != 0 else 0.0
	for i in range(10):
		box("wood", origin + along * (-1.35 + i * 0.30) + Vector3.UP * 0.018, Vector3(1.82, 0.035, 0.27), angle)
	for side in [-1.0, 1.0]:
		box("iron", origin + across * side * 0.90 + Vector3.UP * 0.73, Vector3(0.055, 0.055, 3), angle)
		for step in [-1.1, 0.0, 1.1]:
			box("wood", origin + across * side * 0.90 + along * step + Vector3.UP * 0.39, Vector3(0.10, 0.78, 0.10))

func arena_tile(origin: Vector3, cell: Vector2i, seed_value: int) -> void:
	var roll := posmod(cell.x * 19 + cell.y * 43 + seed_value, 5)
	for side in [-1.0, 1.0]:
		box("gold", origin + Vector3(side * 1.28, 0.025, 0), Vector3(0.08, 0.02, 2.8))
	if roll == 0:
		box("marble", origin + Vector3.UP * 0.024, Vector3(0.9, 0.025, 0.9), PI / 4.0)
		box("ash", origin + Vector3.UP * 0.041, Vector3(0.55, 0.02, 0.55), PI / 4.0)

func decorate_special(at: Vector3, normal: Vector3, angle: float, style: String, roll: int) -> void:
	var cross := Vector3(normal.z, 0, -normal.x)
	var base := at - normal * 0.35
	if roll == 3 and style in ["shrine", "crypt", "armory"]:
		Props.make(self, "column", base + cross * 1.1)
	elif roll == 6 and style in ["storeroom", "library"]:
		Props.make(self, "barrel" if style == "storeroom" else "table", base - normal * 0.12 + cross * 0.85)
	elif roll == 10 and style in ["cistern", "ruins"]:
		Props.make(self, "mushrooms", base + cross * 0.8)
	elif roll == 12 and style == "prison":
		var chain := Props.chain(self, base + Vector3.UP * 2.7)
		moving_props.append({"node": chain, "kind": "chain", "phase": at.x})
	elif roll == 14 and style in ["shrine", "armory"]:
		var banner := Props.banner(self, base + Vector3.UP * 2.5, angle)
		moving_props.append({"node": banner, "kind": "banner", "phase": at.z})
	elif roll == 15 and style == "cistern":
		var water := Node3D.new()
		add_child(water)
		water.position = base + Vector3.UP * 1.25
		Props.block(water, Vector3.ZERO, Vector3(0.58, 2.45, 0.075), "water").rotation.y = angle
		moving_props.append({"node": water, "kind": "water", "phase": at.x})

func open_gate(origin: Vector3, data: Dictionary) -> void:
	var axis: Vector2i = data.axis
	var across := Vector3(-axis.y, 0, axis.x)
	var angle := PI / 2.0 if axis.x != 0 else 0.0
	var width: float = data.width
	var material := "wood" if data.kind == "door" else "iron"
	for side in [-1.0, 1.0]:
		box("trim", origin + across * side * (width * 0.5 + 0.07) + Vector3.UP * 1.45, Vector3(0.14, 2.9, 0.22), angle)
	box(material, origin + Vector3.UP * 2.80, Vector3(width, 0.18, 0.24), angle)
	if data.kind == "portcullis":
		for i in range(7):
			box("iron", origin + across * (-width * 0.45 + width * 0.15 * i) + Vector3.UP * 2.66, Vector3(0.055, 0.48, 0.055))
	elif data.kind == "gate":
		for side in [-1.0, 1.0]:
			box("iron", origin + across * side * (width * 0.5 + 0.03) + Vector3.UP * 1.25, Vector3(0.06, 2.5, 0.4), angle)
	else:
		for side in [-1.0, 1.0]:
			box("wood", origin + across * side * (width * 0.5 + 0.04) + Vector3.UP * 1.2, Vector3(0.065, 2.4, 0.6), angle)
