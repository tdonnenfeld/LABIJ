extends Node3D

const Mix = preload("res://game/audio/audio_mix.gd")
const Acoustics = preload("res://game/world/noise.gd")
const FIRE = preload("res://art/audio/world/fire_loop.ogg")
const DRIP = preload("res://art/audio/world/drip.wav")
const WIND = preload("res://art/audio/world/wind.wav")
const TORCH_LIMIT := 2
const TORCH_RANGE := 7.0
const DRIP_RANGE := 12.0
var torches: Dictionary = {}
var floor_id := -1
var scan_timer := 0.0
var drip_timer := 4.0
var wind_timer := 0.0
var wind: AudioStreamPlayer
var drip: AudioStreamPlayer3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Mix.ensure()
	wind = AudioStreamPlayer.new()
	wind.stream = WIND
	wind.bus = Mix.AMBIENCE
	wind.volume_db = -80.0
	add_child(wind)
	drip = AudioStreamPlayer3D.new()
	drip.stream = DRIP
	drip.bus = Mix.AMBIENCE
	drip.volume_db = -26.0
	drip.unit_size = 3.0
	drip.max_distance = DRIP_RANGE
	add_child(drip)

static func nearby_torches(positions: Array, origin: Vector3, viewer: Vector3, tiles: Dictionary) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	var reach := Acoustics.reach(tiles, viewer, TORCH_RANGE)
	for local in positions:
		var at: Vector3 = origin + local
		if Acoustics.audible(reach, viewer, at, TORCH_RANGE):
			candidates.append(at)
	candidates.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(viewer) < b.distance_squared_to(viewer))
	if candidates.size() > TORCH_LIMIT:
		candidates.resize(TORCH_LIMIT)
	return candidates

static func drip_sources(tiles: Dictionary, viewer: Vector3, origin: Vector3) -> Array[Vector3]:
	var sources: Array[Vector3] = []
	var reach := Acoustics.reach(tiles, viewer, DRIP_RANGE)
	for cell in reach:
		if posmod(cell.x * 73 + cell.y * 151, 7) != 0:
			continue
		var at := origin + Vector3(cell.x * Acoustics.CELL, 2.7, cell.y * Acoustics.CELL)
		var distance := Vector2(at.x - viewer.x, at.z - viewer.z).length()
		if distance >= 3.0 and Acoustics.audible(reach, viewer, at, DRIP_RANGE):
			sources.append(at)
	return sources

func update_environment(level, listener, delta: float) -> void:
	if listener.floor_id != floor_id:
		reset()
		floor_id = listener.floor_id
		drip_timer = rng.randf_range(3.0, 7.0)
		wind_timer = 0.0
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.4
		var positions: Array = []
		if level.visual_builder:
			positions = level.visual_builder.torches
		var nearby := nearby_torches(positions, level.position, listener.position, level.tiles)
		refresh_torches(nearby)
	drip_timer -= delta
	if drip_timer <= 0.0:
		drip_timer = rng.randf_range(9.0, 17.0)
		var sources := drip_sources(level.tiles, listener.position, level.position)
		if not sources.is_empty():
			drip.global_position = sources[rng.randi_range(0, sources.size() - 1)]
			drip.pitch_scale = rng.randf_range(0.92, 1.08)
			drip.play()
	if drip.playing:
		var reachable := Acoustics.reach(level.tiles, listener.position, DRIP_RANGE)
		if not Acoustics.audible(reachable, listener.position, drip.global_position, DRIP_RANGE):
			drip.stop()
	if wind.playing:
		var progress := wind.get_playback_position()
		var envelope := clampf(minf(progress, WIND.get_length() - progress) / 0.8, 0.0001, 1.0)
		wind.volume_db = -32.0 + linear_to_db(envelope)
	else:
		wind_timer -= delta
		if wind_timer <= 0.0:
			wind_timer = rng.randf_range(0.4, 1.5)
			wind.volume_db = -80.0
			wind.play()

func refresh_torches(nearby: Array[Vector3]) -> void:
	for at in torches.keys():
		if not nearby.has(at):
			torches[at].stop()
			torches[at].queue_free()
			torches.erase(at)
	for at in nearby:
		if torches.has(at):
			continue
		var player := AudioStreamPlayer3D.new()
		var stream: AudioStreamOggVorbis = FIRE.duplicate()
		stream.loop = true
		player.stream = stream
		player.bus = Mix.AMBIENCE
		player.unit_size = 2.0
		player.max_distance = TORCH_RANGE
		player.volume_db = -24.0
		add_child(player)
		player.global_position = at
		torches[at] = player
		player.play(rng.randf_range(0.0, stream.get_length()))

func reset() -> void:
	for player in torches.values():
		player.stop()
		player.queue_free()
	torches.clear()
	if wind:
		wind.stop()
	if drip:
		drip.stop()
	floor_id = -1
	scan_timer = 0.0
