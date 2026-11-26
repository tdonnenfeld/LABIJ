extends SceneTree

const Ambient = preload("res://game/audio/environmental_audio.gd")
const Mix = preload("res://game/audio/audio_mix.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	for asset in [Ambient.FIRE, Ambient.DRIP, Ambient.WIND]:
		check(asset.get_length() > 0.0, "Environmental audio imported")
	var tiles := {Vector2i.ZERO: true, Vector2i(1, 0): true, Vector2i(2, 0): true, Vector2i(0, 1): true}
	var origin := Vector3(0, -30, 0)
	var viewer := origin + Vector3.UP
	var points := [Vector3(6, 2, 0), Vector3(3, 2, 0), Vector3(0, 2, 0), Vector3(3, 2, 3)]
	var nearest := Ambient.nearby_torches(points, origin, viewer, tiles)
	check(nearest.size() == 2 and nearest[0] == origin + points[2] and nearest[1] == origin + points[1], "Nearest audible torch cap and floor offset")
	check(Ambient.nearby_torches([Vector3(3, 2, 3)], origin, viewer, tiles).is_empty(), "Disconnected torch not audible")
	var drips := Ambient.drip_sources(tiles, viewer, origin)
	for at in drips:
		check(is_equal_approx(at.y, -27.3), "Drip height uses current floor")
	Mix.ensure()
	Mix.ensure()
	Mix.set_volume(Mix.AMBIENCE, 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Mix.AMBIENCE)), "Ambience mute")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Mix.VOICE)), "Independent voice bus")
	Mix.set_volume(Mix.AMBIENCE, 0.5)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Mix.AMBIENCE)), "Ambience unmute")
	quit(0 if failures == 0 else 1)
