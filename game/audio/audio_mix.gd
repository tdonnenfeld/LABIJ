extends RefCounted

const EFFECTS := "LABIJ Effects"
const AMBIENCE := "LABIJ Ambience"
const VOICE := "LABIJ Voice"

static func ensure() -> void:
	for bus in [EFFECTS, AMBIENCE, VOICE]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	if DisplayServer.get_name() != "headless":
		var index := AudioServer.get_bus_index(EFFECTS)
		if AudioServer.get_bus_effect_count(index) == 0:
			var reverb := AudioEffectReverb.new()
			reverb.room_size = 0.55
			reverb.damping = 0.65
			reverb.wet = 0.13
			reverb.dry = 0.95
			AudioServer.add_bus_effect(index, reverb)

static func set_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var volume := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, volume == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume)))
