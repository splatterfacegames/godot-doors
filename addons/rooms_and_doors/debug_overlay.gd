extends CanvasLayer
## Debug overlay (§13). Toggle with ProjectSettings "rooms_and_doors/debug/overlay" or
## RoomsAndDoors.toggle_debug_overlay(). Draws the room graph, door states,
## witnesses of the player's room and the last 20 system events.

const COL_CLOSED := Color(0.6, 0.6, 0.6)
const COL_AJAR := Color(1.0, 0.65, 0.1)
const COL_OPEN := Color(0.3, 0.9, 0.4)
const COL_LOCKED := Color(0.95, 0.25, 0.25)

var _canvas: Control
var _font: Font
var _dirty := true


func _ready() -> void:
	layer = 100
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)
	_font = ThemeDB.fallback_font
	RoomsAndDoors.event_logged.connect(func(_t: String) -> void: _dirty = true)
	RoomsAndDoors.door_state_changed.connect(func(_a, _b) -> void: _dirty = true)


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_canvas.queue_redraw()


func _draw_overlay() -> void:
	var rooms := RoomsAndDoors.room_ids()
	var size := _canvas.get_viewport_rect().size
	var graph_rect := Rect2(Vector2(16, 16), Vector2(minf(size.x * 0.45, 520.0), minf(size.y * 0.55, 420.0)))
	_canvas.draw_rect(graph_rect, Color(0, 0, 0, 0.6))
	var centre := graph_rect.get_center()
	var radius := minf(graph_rect.size.x, graph_rect.size.y) * 0.38
	var pos := {}
	for i in rooms.size():
		var ang := TAU * float(i) / maxf(1.0, rooms.size()) - PI / 2.0
		pos[rooms[i]] = centre + Vector2(cos(ang), sin(ang)) * radius
	for d in RoomsAndDoors.door_ids():
		var door := RoomsAndDoors.get_door(d)
		var a: Vector2 = pos.get(door["room_a"], centre)
		var b: Vector2 = pos.get(door["room_b"], centre)
		var col: Color = [COL_CLOSED, COL_AJAR, COL_OPEN][int(door["state"])]
		_canvas.draw_line(a, b, col, 3.0)
		var mid := (a + b) * 0.5
		if bool(door["locked"]):
			_canvas.draw_rect(Rect2(mid - Vector2(5, 5), Vector2(10, 10)), COL_LOCKED)
		_text(mid + Vector2(6, -4), "%s %s" % [String(d).get_file(), RAD.door_state_name(int(door["state"]))], col, 11)
	var player := RoomsAndDoors.get_player()
	var proom := RoomsAndDoors.room_of(player)
	for r in rooms:
		var p: Vector2 = pos[r]
		var tier := RoomsAndDoors.simulation_tier(r)
		var fill := Color(0.2, 0.35, 0.8) if r == proom else Color(0.15, 0.15, 0.2)
		_canvas.draw_circle(p, 14.0, fill)
		_canvas.draw_arc(p, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)
		var occ := RoomsAndDoors.occupants(r)
		_text(p + Vector2(-30, 28), "%s  T%d  %s" % [String(r).get_file(), tier, RAD.privacy_name(RoomsAndDoors.effective_privacy(r))], Color.WHITE, 12)
		_text(p + Vector2(-30, 42), ", ".join(occ.map(func(o): return String(o))), Color(0.8, 0.9, 1.0), 11)
	var y := graph_rect.end.y + 20.0
	if proom != &"":
		var w := RoomsAndDoors.witnesses_of(proom, RAD.LOUD_CONVERSATION)
		_text(Vector2(20, y), "Witnesses of %s (conversation): %s" % [proom, ", ".join(w.map(func(o): return String(o)))], COL_AJAR, 13)
		y += 18.0
	_text(Vector2(20, y), "t=%.1fs  %02d:%02d%s  fade=%s" % [RoomsAndDoors.sim_time, int(RoomsAndDoors.clock_hour()),
			int(fmod(RoomsAndDoors.clock_hour(), 1.0) * 60.0), " night" if RoomsAndDoors.is_night() else "", RoomsAndDoors.is_fading()], Color.WHITE, 12)
	var log := RoomsAndDoors.event_log()
	var lx := graph_rect.end.x + 16.0
	_canvas.draw_rect(Rect2(Vector2(lx - 6, 16), Vector2(minf(size.x - lx - 10, 640.0), 20.0 * 16.0 + 12.0)), Color(0, 0, 0, 0.6))
	for i in log.size():
		_text(Vector2(lx, 32 + i * 16), log[i], Color(0.9, 0.9, 0.9), 12)


func _text(at: Vector2, s: String, col: Color, size: int) -> void:
	_canvas.draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
