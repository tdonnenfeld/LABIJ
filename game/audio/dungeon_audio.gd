extends Node3D

const Acoustics = preload("res://game/world/noise.gd")
const Mix = preload("res://game/audio/audio_mix.gd")
const RATE := 22050
const LIMIT := 24
const SOUNDS := ["step", "quiet", "sprint", "melee", "bow", "magic", "impact", "block", "explosion", "stone", "enemy_step", "wake"]
const STONE_STEPS := [
	preload("res://art/audio/steps/stone_L1.ogg"),
	preload("res://art/audio/steps/stone_L2.ogg"),
	preload("res://art/audio/steps/stone_L3.ogg"),
	preload("res://art/audio/steps/stone_R1.ogg"),
	preload("res://art/audio/steps/stone_R2.ogg"),
	preload("res://art/audio/steps/stone_R3.ogg")
]
const ENEMY_STEPS := [
	preload("res://art/audio/steps/kenney_00.ogg"),
	preload("res://art/audio/steps/kenney_02.ogg"),
	preload("res://art/audio/steps/kenney_06.ogg"),
	preload("res://art/audio/steps/kenney_09.ogg")
]
const CUES := {
	"melee": [preload("res://art/audio/combat/swing_01.wav"), preload("res://art/audio/combat/swing_02.wav")],
	"bow": [preload("res://art/audio/combat/bow.wav")],
	"magic": [preload("res://art/audio/magic/cast.wav")],
	"explosion": [preload("res://art/audio/magic/explosion_01.wav"), preload("res://art/audio/magic/explosion_02.wav")],
	"stone": [preload("res://art/audio/combat/stone_01.ogg"), preload("res://art/audio/combat/stone_02.ogg")],
	"block": [preload("res://art/audio/impacts/impactMetal_heavy_001.ogg"), preload("res://art/audio/combat/block_02.ogg")],
	"wake_ogre": [preload("res://art/audio/creatures/ogre_01.wav")],
	"wake_beast": [preload("res://art/audio/creatures/beast_01.wav")],
	"wake_shade": [preload("res://art/audio/creatures/shade.wav")]
}
const IMPACT_SOUND = preload("res://art/audio/impacts/impactMining_002.ogg")
var streams: Dictionary = {}
var previous_variant: Dictionary = {}
var audio_rng := RandomNumberGenerator.new()
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

func sound_for(kind: String) -> AudioStream:
	var variants: Array = []
	if kind in ["step", "quiet", "sprint"]:
		variants = STONE_STEPS
	elif kind == "enemy_step":
		variants = ENEMY_STEPS
	elif CUES.has(kind):
		variants = CUES[kind]
	elif kind == "impact":
		return IMPACT_SOUND
	else:
		return sample(kind)
	if variants.size() == 1:
		return variants[0]
	var group := "player_step" if kind in ["step", "quiet", "sprint"] else kind
	var index := audio_rng.randi_range(0, variants.size() - 2)
	var previous: int = previous_variant.get(group, -1)
	if previous < 0:
		index = audio_rng.randi_range(0, variants.size() - 1)
	elif index >= previous:
		index += 1
	previous_variant[group] = index
	return variants[index]

func play_sound(kind: String, at: Vector3, radius: float) -> void:
	if voices.size() >= LIMIT:
		var oldest: AudioStreamPlayer3D = voices.pop_front()
		oldest.queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.stream = sound_for(kind)
	voice.bus = Mix.EFFECTS
	voice.unit_size = maxf(1.0, radius * 0.35)
	voice.max_distance = maxf(1.5, radius)
	match kind:
		"quiet": voice.volume_db = -19.0
		"step": voice.volume_db = -12.0
		"sprint": voice.volume_db = -7.0
		"enemy_step": voice.volume_db = -13.0
		_: voice.volume_db = -9.0
	voice.volume_db += audio_rng.randf_range(-1.5, 1.5)
	voice.pitch_scale = audio_rng.randf_range(0.94, 1.06) * (0.88 if kind == "sprint" else 1.0)
	add_child(voice)
	voice.global_position = at
	voices.append(voice)
	voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
	voice.play()

func reset() -> void:
	for voice in voices:
		voice.queue_free()
	voices.clear()
