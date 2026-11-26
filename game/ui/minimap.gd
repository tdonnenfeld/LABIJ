extends Control

const Parchment = preload("res://game/ui/parchment.gd")
var page_style := Parchment.parchment(4.0)
const Exploration = preload("res://game/world/exploration.gd")
const Acoustics = preload("res://game/world/noise.gd")
var memory := Exploration.new()
var floor_id := 0
var center := Vector2i.ZERO
var markers: Dictionary = {}
var party: Array = []
var heading := 0.0
var floor_title := ""
var corridor_widths: Dictionary = {}

func refresh(world, actor, actors: Dictionary, angle: float) -> void:
	floor_id = actor.floor_id
	center = Acoustics.cell(actor.position)
	heading = angle
	floor_title = world.Routes.NAMES[floor_id]
	corridor_widths = world.floors[floor_id].corridor_widths
	memory.reveal(floor_id, world.floors[floor_id].tiles, actor.position)
	markers.clear()
	markers[Acoustics.cell(world.stair_position(floor_id, false))] = "S" if floor_id == 0 else "U"
	if floor_id < world.Routes.MAIN_COUNT - 1:
		markers[Acoustics.cell(world.stair_position(floor_id, true))] = "D"
	for branch in world.branch_entries:
		if world.Routes.PARENTS[branch] == floor_id:
			markers[Acoustics.cell(world.branch_entries[branch])] = "B"
	party.clear()
	for other in actors.values():
		if other != actor and other.floor_id == floor_id and other.health > 0:
			party.append(Acoustics.cell(other.position))
	queue_redraw()

func _draw() -> void:
	draw_style_box(page_style, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(8, 21), Vector2(size.x - 8, 21), Parchment.BRASS, 1.0)
	var step := minf(size.x - 16.0, size.y - 32.0) / 17.0
	if step <= 0:
		return
	var middle := Vector2(size.x * 0.5, (size.y + 24.0) * 0.5)
	var cells: Dictionary = memory.explored.get(floor_id, {})
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(7, 16), floor_title + " [M]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Parchment.INK)
	for cell in cells:
		var offset: Vector2i = cell - center
		if absi(offset.x) > 8 or absi(offset.y) > 8:
			continue
		var at := middle + Vector2(offset) * step
		var extent := Vector2.ONE * (step - 0.7)
		if corridor_widths.has(cell):
			var corridor: Dictionary = corridor_widths[cell]
			var narrow: float = step * corridor.width / 3.0
			extent = Vector2(step, narrow) if corridor.axis.x != 0 else Vector2(narrow, step)
		draw_rect(Rect2(at - extent * 0.5, extent), Color("#78634a"))
		if markers.has(cell):
			draw_string(font, at + Vector2(-4, 4), markers[cell], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffe3a0"))
		if party.has(cell):
			draw_circle(at, 2.5, Color("#72b8db"))
	var forward := Vector2(-sin(heading), -cos(heading))
	draw_circle(middle, 3.5, Color("#8c3935"))
	draw_line(middle, middle + forward * step * 0.75, Color("#f3e9c4"), 2.0)

func reset() -> void:
	memory.explored.clear()
	markers.clear()
	party.clear()
	corridor_widths = {}
	queue_redraw()
