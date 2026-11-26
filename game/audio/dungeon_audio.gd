extends Node3D

const Acoustics = preload("res://game/world/noise.gd")
const RATE := 22050
const LIMIT := 24
const SOUNDS := ["step", "quiet", "sprint", "melee", "bow", "magic", "impact", "block", "explosion", "stone", "enemy_step", "wake"]
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []

func sample(kind: String) -> AudioStreamWAV:
	if streams.has(kind):
		return streams[kind]
	var settings: Array = {
		"step": [0.12, 85.0, 0.78], "quiet": [0.10, 135.0, 0.60], "sprint": [0.16, 65.0, 0.80],
		"melee": [0.18, 270.0, 0.85], "bow": [0.11, 450.0, 0.35], "magic": [0.32, 430.0, 0.15],
		"impact": [0.13, 105.0, 0.65], "block": [0.20, 720.0, 0.35], "explosion": [0.42, 55.0, 0.75],
		"stone": [0.16, 650.0, 0.58], "enemy_step": [0.15, 75.0, 0.68], "wake": [0.28, 105.0, 0.40]
	}.get(kind, [0.12, 100.0, 0.5])
	var count := int(float(settings[0]) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(kind.hash())
	var filtered := 0.0
	for i in range(count):
		var time := float(i) / RATE
		var progress := float(i) / count
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.24)
		var tone := sin(TAU * float(settings[1]) * time * (1.0 - 0.25 * progress))
		var envelope := minf(1.0, time * 250.0) * pow(1.0 - progress, 2.0)
		var value := (tone * (1.0 - float(settings[2])) + filtered * float(settings[2])) * envelope
		data.encode_s16(i * 2, roundi(clampf(value * 0.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	streams[kind] = stream
	return stream

func hear(events: Array, world, listener) -> void:
	for event in events:
		if event[0] != listener.floor_id:
			continue
		var at: Vector3 = event[1]
		var radius: float = event[2]
		var distance := Vector2(at.x - listener.position.x, at.z - listener.position.z).length()
		if distance > radius:
			continue
		var tiles: Dictionary = world.floors[listener.floor_id].tiles
		var reach := Acoustics.reach(tiles, at, radius)
		if not Acoustics.audible(reach, at, listener.position, radius):
			continue
		play_sound(event[3], at, radius)

func play_sound(kind: String, at: Vector3, radius: float) -> void:
	if voices.size() >= LIMIT:
		var oldest: AudioStreamPlayer3D = voices.pop_front()
		oldest.queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.stream = sample(kind)
	voice.unit_size = maxf(1.0, radius * 0.35)
	voice.max_distance = maxf(1.5, radius)
	voice.volume_db = -10.0 if kind in ["step", "quiet", "enemy_step"] else -5.0
	add_child(voice)
	voice.global_position = at
	voices.append(voice)
	voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
	voice.play()

func reset() -> void:
	for voice in voices:
		voice.queue_free()
	voices.clear()
