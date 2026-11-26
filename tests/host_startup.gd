extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func make_game(title: String) -> Node:
	var viewport := SubViewport.new()
	viewport.name = title
	viewport.own_world_3d = true
	root.add_child(viewport)
	set_multiplayer(MultiplayerAPI.create_default_interface(), viewport.get_path())
	var game = load("res://game/main.tscn").instantiate()
	viewport.add_child(game)
	return game

func run() -> void:
	var host = make_game("HostViewport")
	await process_frame
	host.party_selector.value = 2
	host.yaw = 2.0
	host.pitch = 1.0
	host._host()
	check(host.active and host.multiplayer.is_server() and host.actors.has(1), "Listen host enters with local player")
	check(host.party_size == 2 and host.actors.size() == 1 and host.ready_peers.is_empty(), "Host starts without guests")
	check(host.yaw == 0.0 and host.pitch == 0.0 and not host.menu.visible, "Host view and menu initialized")
	check(host.world.floors[0].visible and not host.world.floors[1].visible, "Only starting floor visible")
	for i in range(8):
		await physics_frame
	check(host.tick > 0 and host.actors[1].health > 0, "Host simulation runs before any join")
	var guest = make_game("GuestViewport")
	await process_frame
	guest.address.text = "127.0.0.1"
	guest._join()
	for i in range(600):
		if guest.active and host.ready_peers.size() == 1:
			break
		await process_frame
	check(guest.active and host.ready_peers.size() == 1, "Real ENet bootstrap completed")
	if guest.active and host.ready_peers.size() == 1:
		var peer: int = guest.multiplayer.get_unique_id()
		check(guest.actors.has(peer) and guest.actors.has(1) and host.actors.has(peer), "Both peers have complete roster")
		check(guest.received_tick >= 0 and guest.expedition_seed == host.expedition_seed, "Reliable initial snapshot applied")
		check(guest.world.floors[0].tiles == host.world.floors[0].tiles, "Matching procedural layout")
		check(guest.actors[peer].position.distance_to(host.actors[peer].position) < 0.4, "Authoritative initial position")
		check(host.actors[1].position.distance_to(host.actors[peer].position) >= 0.64, "Distinct spawn positions")
		check(host.reserved_slots() == 2 and host.pending_profiles.is_empty(), "Handshake does not double-count capacity")
	guest.leave_expedition(false)
	for i in range(60):
		if host.actors.size() == 1:
			break
		await process_frame
	check(host.active and host.actors.size() == 1, "Host continues after guest leaves")
	host.leave_expedition(false)
	await process_frame
	host._solo()
	check(host.active and host.actors.size() == 1 and host.party_size == 1 and host.ready_peers.is_empty(), "Solo restart after hosting")
	host.leave_expedition(false)
	await process_frame
	for game in [host, guest]:
		var viewport: Node = game.get_parent()
		set_multiplayer(null, viewport.get_path())
		viewport.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)
