extends Node3D

const Mix = preload("res://game/audio/audio_mix.gd")
const Codec = preload("res://game/audio/voice_codec.gd")
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var speakers: Dictionary = {}
var bus_index := -1
var transmitting := false
var level := 0.0

func start_capture() -> void:
	if microphone:
		return
	bus_index = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "LABIJ Microphone")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.15
	AudioServer.add_bus_effect(bus_index, capture)
	AudioServer.set_bus_volume_db(bus_index, -80.0)
	microphone = AudioStreamPlayer.new()
	microphone.stream = AudioStreamMicrophone.new()
	microphone.bus = "LABIJ Microphone"
	add_child(microphone)

func poll(enabled: bool) -> Array:
	var packets: Array = []
	if not enabled:
		stop_capture()
		return packets
	if not microphone:
		start_capture()
	if not microphone.playing:
		capture.clear_buffer()
		microphone.play()
	transmitting = true
	var count := maxi(1, roundi(AudioServer.get_mix_rate() * 0.02))
	if capture.get_frames_available() > count * 5:
		capture.clear_buffer()
		return packets
	for i in range(5):
		if capture.get_frames_available() < count:
			break
		var data := Codec.encode(capture.get_buffer(count))
		level = Codec.radius(data)
		if level > 0.0:
			packets.append(data)
	return packets

func stop_capture() -> void:
	transmitting = false
	level = 0.0
	if microphone and microphone.playing:
		microphone.stop()
		capture.clear_buffer()

func receive(peer: int, at: Vector3, floor_id: int, radius: float, data: PackedByteArray) -> void:
	if data.size() != Codec.BYTES:
		return
	if not speakers.has(peer):
		var player := AudioStreamPlayer3D.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
		generator.mix_rate = Codec.RATE
		generator.buffer_length = 0.16
		player.stream = generator
		player.bus = Mix.VOICE
		player.volume_db = -3.0
		add_child(player)
		player.global_position = at
		player.play()
		var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
		var silence := PackedVector2Array()
		silence.resize(Codec.FRAME * 2)
		playback.push_buffer(silence)
		speakers[peer] = {"player": player, "playback": playback, "floor": floor_id, "age": 0.0}
	var entry: Dictionary = speakers[peer]
	entry.age = 0.0
	entry.floor = floor_id
	entry.player.global_position = at
	entry.player.unit_size = maxf(1.0, radius * 0.45)
	entry.player.max_distance = maxf(2.0, radius)
	if entry.playback.can_push_buffer(Codec.FRAME):
		entry.playback.push_buffer(Codec.decode(data))

func advance(delta: float, floor_id: int, actors: Dictionary) -> void:
	for peer in speakers.keys():
		var entry: Dictionary = speakers[peer]
		entry.age += delta
		if entry.age > 0.3 or entry.floor != floor_id or not actors.has(peer) or actors[peer].floor_id != floor_id:
			entry.player.queue_free()
			speakers.erase(peer)
		else:
			entry.player.global_position = actors[peer].position

func reset() -> void:
	stop_capture()
	for entry in speakers.values():
		entry.player.queue_free()
	speakers.clear()

func _exit_tree() -> void:
	stop_capture()
	if bus_index >= 0 and AudioServer.get_bus_index("LABIJ Microphone") == bus_index:
		AudioServer.remove_bus(bus_index)
