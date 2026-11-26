extends RefCounted

static var materials: Dictionary = {}
const RESOLUTION := 128

static func grain(x: int, y: int, salt: int) -> float:
	return float(posmod(x * 193 + y * 317 + x * y * 17 + salt * 7919, 101)) / 100.0

static func stone_texture(bricks: bool, pattern: int = 0) -> ImageTexture:
	var image := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGB8)
	var base := Color("#77776b") if bricks else Color("#65665b")
	var mortar := Color("#393c36") if bricks else Color("#34372f")
	var width: int = [64, 32, 128, 32][pattern] if bricks else [32, 64, 32, 128][pattern]
	var height: int = [32, 16, 64, 32][pattern] if bricks else [64, 64, 32, 32][pattern]
	for y in range(RESOLUTION):
		var row := floori(float(y) / height)
		for x in range(RESOLUTION):
			var shifted := int(x + ((width / 2) * (row % 2) if bricks else 0))
			var col := floori(float(shifted) / width)
			var u := posmod(shifted, width)
			var v: int = y % height
			var edge := mini(mini(u, width - 1 - u), mini(v, height - 1 - v))
			var stone := base * (0.84 + 0.26 * grain(posmod(col, floori(float(RESOLUTION) / width)), row, 3))
			var noise := (grain(x, y, 7) - 0.5) * 0.16 + (grain(floori(x / 4.0), floori(y / 4.0), 19) - 0.5) * 0.13
			var color := stone.lightened(maxf(0.0, noise)).darkened(maxf(0.0, -noise))
			if edge == 0:
				color = mortar.darkened(grain(x, y, 2) * 0.15)
			elif v == 1 or u == 1:
				color = color.lightened(0.13)
			elif v >= height - 3 or u >= width - 3:
				color = color.darkened(0.20)
			if grain(floori(x / 8.0), floori(y / 8.0), 29) > 0.83 and edge > 1:
				color = color.lerp(Color("#545e42"), 0.22)
			image.set_pixel(x, y, Color(color.r, color.g, color.b))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func stone(bricks: bool, pattern: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = stone_texture(bricks, pattern)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / 3.0
	mat.roughness = 0.95
	return mat

static func solid(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

static func material(id: String) -> StandardMaterial3D:
	if materials.is_empty():
		materials["floor"] = stone(false)
		materials["wall"] = stone(true)
		for i in range(1, 4):
			materials["floor%d" % i] = stone(false, i)
			materials["wall%d" % i] = stone(true, i)
			materials["floor%d" % i].albedo_color = [Color.WHITE, Color("#b8b3a0"), Color("#888e83"), Color("#a59885")][i]
			materials["wall%d" % i].albedo_color = [Color.WHITE, Color("#a4a69a"), Color("#b7a897"), Color("#8d9388")][i]
		var ceiling: StandardMaterial3D = materials["wall"].duplicate()
		ceiling.albedo_color = Color("#8d8c82")
		materials["ceiling"] = ceiling
		materials["trim"] = solid(Color("#55564c"))
		materials["iron"] = solid(Color("#363630"))
		materials["wood"] = solid(Color("#67442a"))
		materials["flame"] = solid(Color("#ff9238"), 2.5)
		materials["ember"] = solid(Color("#ffd18a"), 2.0)
		materials["water"] = solid(Color("#294b53"))
		materials["water"].roughness = 0.18
		materials["gold"] = solid(Color("#a68a4c"))
		var colors := {"bone":"#b9ad91","cloth":"#703e38","cloth_blue":"#3f5a60","moss":"#48583b","rubble":"#77766b","clay":"#87563c","paper":"#c3ad7d","book":"#453a30","dark":"#242624","crystal":"#58858a","marble":"#aca391","grout":"#383a36","ash":"#4e4743"}
		for key in colors:
			materials[key] = solid(Color(colors[key]), 0.35 if key == "crystal" else 0.0)
	return materials[id]

static func tinted(id: String, tint: Color) -> StandardMaterial3D:
	var key := id + ":" + tint.to_html()
	if not materials.has(key):
		var mat: StandardMaterial3D = material(id).duplicate()
		mat.albedo_color *= tint
		materials[key] = mat
	return materials[key]
