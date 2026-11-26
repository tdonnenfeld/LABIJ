extends SceneTree

const Codec = preload("res://game/audio/voice_codec.gd")
const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func packet(amplitude: float) -> PackedByteArray:
	var frames := PackedVector2Array()
	frames.resize(960)
	for i in range(frames.size()):
		frames[i] = Vector2.ONE * amplitude * sin(TAU * i / 80.0)
	return Codec.encode(frames)

func run() -> void:
	check(Codec.radius(packet(0.0)) == 0.0, "Silence gate")
	check(Codec.radius(PackedByteArray([1, 2])) == 0.0, "Malformed frame")
	var quiet := Codec.radius(packet(0.015))
	var loud := Codec.radius(packet(0.8))
	check(quiet > 0 and quiet < Codec.SHOUT_RADIUS and loud >= Codec.SHOUT_RADIUS, "Quiet and loud mapping")
	check(Codec.decode(packet(0.5)).size() == Codec.FRAME, "PCM roundtrip frame length")
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	var other := Player.new()
	root.add_child(other)
	other.setup(false, false)
	var mob: Dictionary = world.monsters[0]
	actor.position = mob.node.position
	other.position = actor.position
	mob.asleep = true
	world.voice_noise(actor, 1, quiet)
	check(not mob.asleep and mob.investigate > 0 and mob.threat.is_empty(), "Quiet speech wakes without aggro")
	world.voice_noise(actor, 1, loud)
	check(mob.target == 1 and mob.threat.has(1), "Shout pulls enemy")
	check(actor.noise_peak == loud, "Voice contributes to meter")
	var before: float = mob.threat[1]
	world.voice_noise(actor, 2, loud)
	check(mob.target == 1 and mob.threat[1] == before and not mob.threat.has(2), "No shout taunt against engaged enemy")
	check(world.voice_audible(actor, other, loud), "Nearby teammate can hear")
	other.floor_id = 1
	check(not world.voice_audible(actor, other, loud), "No cross-floor voice")
	quit(0 if failures == 0 else 1)
