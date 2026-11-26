extends SceneTree

const Vision = preload("res://game/monsters/vision.gd")
const World = preload("res://game/world.gd")
const Player = preload("res://game/player.gd")
const DungeonAudio = preload("res://game/audio/dungeon_audio.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	check(Vision.detects(0, Vector3(0, 0, -6), 12, false, 120), "Forward detection")
	check(not Vision.detects(0, Vector3(0, 0, 6), 12, false, 120), "Rear blind spot")
	check(Vision.detects(0, Vector3(0, 0, 1), 12, false, 120), "Close proximity")
	check(not Vision.detects(0, Vector3(0, 0, -3), 12, true, 120), "Sleeping limited detection")
	check(Vision.rear(0, Vector3(0, 0, 2)) and not Vision.rear(0, Vector3(0, 0, -2)), "Rear sector")
	var world := World.new()
	root.add_child(world)
	world.build(123, false, 2)
	var actor := Player.new()
	root.add_child(actor)
	actor.setup(false, false)
	actor.skills.credit(11, 200)
	check(actor.buy_talent("soft_step") and actor.buy_talent("ambush") and actor.buy_talent("backstab"), "Backstab talent")
	var mob: Dictionary = world.monsters[0]
	mob.kind = "goblin"
	mob.asleep = false
	mob.health = 100.0
	mob.node.rotation.y = 0.0
	mob.target = 2
	mob.threat[2] = 100.0
	actor.position = mob.node.position + Vector3(0, 0, 1.5)
	world.hit_monster(actor, mob, {1: actor})
	check(is_equal_approx(mob.health, 66.25), "Rear strike adds 35%")
	mob.target = 1
	world.hit_monster(actor, mob, {1: actor})
	check(is_equal_approx(mob.health, 41.25), "No bonus against enemy targeting attacker")
	world.face_toward(mob, mob.node.position + Vector3(2, 0, 0))
	check(is_equal_approx(mob.node.rotation.y, -PI / 2), "Facing follows movement")
	var snap := world.monster_snapshot()
	mob.node.rotation.y = 0.0
	world.apply_monsters(snap)
	check(is_equal_approx(mob.node.rotation.y, -PI / 2), "Heading replication")
	world.drain_sounds()
	world.player_noise(actor, 6.0, "step")
	var events := world.drain_sounds()
	check(events.any(func(event): return event[3] == "step"), "Sound emitted with authoritative noise")
	check(world.drain_sounds().is_empty(), "Sound queue drains")
	var audio := DungeonAudio.new()
	root.add_child(audio)
	for kind in DungeonAudio.SOUNDS:
		var stream := audio.sample(kind)
		check(stream.data.size() > 0 and stream.mix_rate == 22050 and stream == audio.sample(kind), "Cached PCM: " + kind)
	for kind in ["step", "quiet", "sprint", "enemy_step"]:
		var first := audio.sound_for(kind)
		var second := audio.sound_for(kind)
		check(first is AudioStreamOggVorbis and first.get_length() > 0.0, "Recorded step: " + kind)
		check(first != second, "No consecutive repeated step: " + kind)
	check(audio.sound_for("block") is AudioStreamOggVorbis and audio.sound_for("impact") is AudioStreamOggVorbis, "Recorded impacts")
	quit(0 if failures == 0 else 1)
