extends RefCounted

const EFFECTS := "LABIJ Effects"
const AMBIENCE := "LABIJ Ambience"
const VOICE := "LABIJ Voice"

static func ensure() -> void:
	for bus in [EFFECTS, AMBIENCE, VOICE]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)

static func set_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var volume := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, volume == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume)))
