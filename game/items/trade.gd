extends RefCounted

const Inventory = preload("res://game/items/inventory.gd")
const Catalog = preload("res://game/items/catalog.gd")
const RANGE := 3.5
const TIMEOUT := 45.0
var sessions: Dictionary = {}
var members: Dictionary = {}
var notices: Dictionary = {}
var next_id := 1

static func available(actor) -> bool:
	return actor.health > 0 and actor.combat_timer <= 0.0 and actor.attack_phase == 0 and actor.cast_id == ""

static func nearby(a, b) -> bool:
	return a != b and available(a) and available(b) and a.floor_id == b.floor_id and a.position.distance_to(b.position) <= RANGE

func reset() -> void:
	sessions.clear()
	members.clear()
	notices.clear()

func valid(session: Dictionary, actors: Dictionary) -> bool:
	if not actors.has(session.a) or not actors.has(session.b):
		return false
	var a = actors[session.a]
	var b = actors[session.b]
	return nearby(a, b) and a.inventory.revision == session.rev_a and b.inventory.revision == session.rev_b

func invite(id: int, target: int, actors: Dictionary) -> bool:
	if id == target or members.has(id) or members.has(target) or not actors.has(id) or not actors.has(target):
		return false
	if not nearby(actors[id], actors[target]):
		notices[id] = "Trade requires a nearby companion outside combat."
		return false
	var session := {"id": next_id, "a": id, "b": target, "rev_a": actors[id].inventory.revision, "rev_b": actors[target].inventory.revision, "joined": false, "offer_a": -1, "offer_b": -1, "confirmed": [], "version": 1, "remaining": TIMEOUT}
	sessions[next_id] = session
	members[id] = next_id
	members[target] = next_id
	notices.erase(id)
	notices.erase(target)
	next_id += 1
	return true

func close(session: Dictionary, message: String) -> void:
	for peer in [session.a, session.b]:
		members.erase(peer)
		notices[peer] = message
	sessions.erase(session.id)

func cancel(id: int, message: String = "Trade cancelled.") -> void:
	if members.has(id):
		close(sessions[members[id]], message)

func sweep(actors: Dictionary, delta: float) -> void:
	for session in sessions.values():
		session.remaining -= delta
		if session.remaining <= 0.0:
			close(session, "Trade expired.")
		elif not valid(session, actors):
			close(session, "Trade cancelled: moved apart, combat or inventory changed.")

func valid_offer(bag, index: int) -> bool:
	return index == -1 or (index >= 0 and index < bag.items.size() and not bag.is_equipped(index))

func transact(a, b, index_a: int, index_b: int) -> bool:
	if not valid_offer(a, index_a) or not valid_offer(b, index_b) or (index_a == -1 and index_b == -1):
		return false
	var clone_a := Inventory.new()
	var clone_b := Inventory.new()
	clone_a.apply(a.state())
	clone_b.apply(b.state())
	var amount_a := clone_a.quantity(index_a)
	var amount_b := clone_b.quantity(index_b)
	var item_a := clone_a.remove_stack(index_a) if index_a >= 0 else ""
	var item_b := clone_b.remove_stack(index_b) if index_b >= 0 else ""
	if not item_a.is_empty() and not clone_b.add(item_a, amount_a):
		return false
	if not item_b.is_empty() and not clone_a.add(item_b, amount_b):
		return false
	a.apply(clone_a.state())
	b.apply(clone_b.state())
	return true

func operate(id: int, operation: String, value: int, session_id: int, version: int, revision: int, actors: Dictionary) -> bool:
	if operation == "invite":
		if not actors.has(id) or actors[id].inventory.revision != revision:
			return false
		return invite(id, value, actors)
	if not members.has(id) or members[id] != session_id:
		return false
	var session: Dictionary = sessions[session_id]
	if operation == "cancel":
		close(session, "Trade cancelled.")
		return true
	if not valid(session, actors):
		close(session, "Trade cancelled: moved apart, combat or inventory changed.")
		return false
	if revision != actors[id].inventory.revision or version != session.version:
		return false
	if operation == "join":
		if id != session.b or session.joined:
			return false
		session.joined = true
		session.version += 1
		return true
	if not session.joined:
		return false
	if operation == "offer":
		if not valid_offer(actors[id].inventory, value):
			return false
		session["offer_a" if id == session.a else "offer_b"] = value
		session.confirmed.clear()
		session.version += 1
		return true
	if operation == "confirm":
		if session.offer_a == -1 and session.offer_b == -1:
			return false
		if id not in session.confirmed:
			session.confirmed.append(id)
		if session.confirmed.size() == 2:
			var ok := transact(actors[session.a].inventory, actors[session.b].inventory, session.offer_a, session.offer_b)
			close(session, "Trade completed." if ok else "Trade failed: insufficient backpack space.")
			return ok
		return true
	return false

func description(bag, index: int) -> String:
	if index < 0 or index >= bag.items.size():
		return "Nothing"
	return "%s ×%d" % [Catalog.get_item(bag.items[index]).title, bag.quantity(index)]

func view(id: int, actors: Dictionary) -> Dictionary:
	if not members.has(id):
		return {"id": 0, "notice": notices.get(id, "")}
	var session: Dictionary = sessions[members[id]]
	var is_a: bool = id == session.a
	var partner: int = session.b if is_a else session.a
	if not actors.has(id) or not actors.has(partner):
		return {"id": 0, "notice": "Companion left."}
	var own: int = session.offer_a if is_a else session.offer_b
	var other: int = session.offer_b if is_a else session.offer_a
	return {"id": session.id, "partner": partner, "name": actors[partner].display_name, "incoming": not is_a and not session.joined, "joined": session.joined, "own": own, "own_text": description(actors[id].inventory, own), "other": other, "other_text": description(actors[partner].inventory, other), "version": session.version, "revision": actors[id].inventory.revision, "confirmed": id in session.confirmed, "other_confirmed": partner in session.confirmed, "notice": ""}
