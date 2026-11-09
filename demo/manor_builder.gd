class_name ManorBuilder
extends RefCounted
## Builds Ashcombe House from ManorLayout: floors, walls with door openings,
## RoomAreas, Door.tscn instances, furniture, lamps, props and floor signs.

const WALL_H := 2.8
const WALL_T := 0.18
const DOOR_H := 2.15
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_NPC := 4

const DOOR_SCENE := preload("res://addons/rooms_and_doors/Door.tscn")

var root: Node3D
var walls: Array[MeshInstance3D] = []
var doors: Dictionary = {}       # door_id -> Door
var props: Dictionary = {}       # prop_id -> Node3D
var room_areas: Dictionary = {}  # room_id -> RoomArea
var font: TypesetterFontAsset


func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Manor"
	parent.add_child(root)
	font = TypesetterSettings.get_default_font_asset()
	_environment()
	for r in ManorLayout.ROOMS:
		_floor(r)
		_room_area(r)
	_walls()
	for d in ManorLayout.DOORS:
		_door(d)
	for f in ManorLayout.FURNITURE:
		_furniture(f)
	for l in ManorLayout.LAMPS:
		_lamp(l[0], l[1])
	for p in ManorLayout.PROPS:
		_prop(p)
	for r in ManorLayout.ROOMS:
		_sign(r)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.62)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-60, 30, 0)
	root.add_child(moon)
	# Lawn under everything so the outside reads as outside.
	var lawn := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 50)
	lawn.mesh = pm
	lawn.position = Vector3(0, -0.02, 0)
	lawn.material_override = _mat(Color(0.1, 0.13, 0.09))
	root.add_child(lawn)


func _floor(r: Dictionary) -> void:
	var rect: Rect2 = r["rect"]
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(rect.size.x, 0.1, rect.size.y)
	m.mesh = b
	m.position = Vector3(rect.get_center().x, -0.05, rect.get_center().y)
	m.material_override = _mat(r["floor"])
	root.add_child(m)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = b.size
	cs.shape = bs
	body.add_child(cs)
	m.add_child(body)


func _room_area(r: Dictionary) -> void:
	var rect: Rect2 = r["rect"]
	var a := RoomArea.new()
	a.name = "Room_" + String(r["id"]).replace("@", "")
	a.room_id = r["id"]
	a.display_name = r["name"]
	a.privacy = r["privacy"]
	a.owner_id = r.get("owner", &"")
	a.ambient_noise = r["ambient"]
	a.collision_layer = 0
	a.collision_mask = LAYER_PLAYER | LAYER_NPC
	a.position = Vector3(rect.get_center().x, 1.4, rect.get_center().y)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(rect.size.x - 0.02, 2.8, rect.size.y - 0.02)
	cs.shape = bs
	a.add_child(cs)
	root.add_child(a)
	room_areas[r["id"]] = a


## Walls go on every cell edge between two different rooms (or a room and
## nothing), except between the exterior and nothing. Door openings are cut out.
func _walls() -> void:
	var owner := {}
	var exterior := {}
	for r in ManorLayout.ROOMS:
		var rect: Rect2 = r["rect"]
		for x in range(int(rect.position.x), int(rect.end.x)):
			for z in range(int(rect.position.y), int(rect.end.y)):
				owner[Vector2i(x, z)] = r["id"]
		exterior[r["id"]] = r.get("exterior", false)
	# Unit edges keyed by line: horizontal edges at z (cells z-1 | z), vertical at x.
	var h := {}  # z -> Array[int x]
	var v := {}  # x -> Array[int z]
	for cell in owner.keys():
		var c: Vector2i = cell
		for dir in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
			var n: Vector2i = c + dir
			var a: StringName = owner[c]
			var b: StringName = owner.get(n, &"")
			if a == b:
				continue
			var ext_a: bool = exterior[a]
			var ext_b: bool = b == &"" or bool(exterior.get(b, false))
			if ext_a and ext_b:
				continue
			# Each shared edge is seen from both cells; record it from one side only.
			if b != &"" and String(a) > String(b):
				continue
			if dir.y != 0:
				var z := c.y if dir.y < 0 else c.y + 1
				if not h.has(z):
					h[z] = []
				h[z].append(c.x)
			else:
				var x := c.x if dir.x < 0 else c.x + 1
				if not v.has(x):
					v[x] = []
				v[x].append(c.y)
	var openings_h := {}
	var openings_v := {}
	for d in ManorLayout.DOORS:
		var w: float = d.get("width", 1.0)
		var p: Vector2 = d["pos"]
		if is_equal_approx(fmod(absf(float(d["rot"])), 180.0), 0.0):
			if not openings_h.has(p.y):
				openings_h[p.y] = []
			openings_h[p.y].append(Vector2(p.x - w * 0.5 - 0.06, p.x + w * 0.5 + 0.06))
		else:
			if not openings_v.has(p.x):
				openings_v[p.x] = []
			openings_v[p.x].append(Vector2(p.y - w * 0.5 - 0.06, p.y + w * 0.5 + 0.06))
	for z in h:
		for run in _runs(h[z]):
			for seg in _subtract(run, openings_h.get(float(z), [])):
				_wall_box(Vector3((seg.x + seg.y) * 0.5, 0, z), Vector3(seg.y - seg.x + WALL_T, WALL_H, WALL_T))
	for x in v:
		for run in _runs(v[x]):
			for seg in _subtract(run, openings_v.get(float(x), [])):
				_wall_box(Vector3(x, 0, (seg.x + seg.y) * 0.5), Vector3(WALL_T, WALL_H, seg.y - seg.x + WALL_T))
	# Lintels over openings.
	for d in ManorLayout.DOORS:
		var w: float = d.get("width", 1.0) + 0.12
		var p: Vector2 = d["pos"]
		var horiz := is_equal_approx(fmod(absf(float(d["rot"])), 180.0), 0.0)
		var size := Vector3(w, WALL_H - DOOR_H, WALL_T) if horiz else Vector3(WALL_T, WALL_H - DOOR_H, w)
		_wall_box(Vector3(p.x, DOOR_H, p.y), size, false)


func _runs(cells: Array) -> Array[Vector2]:
	cells.sort()
	var out: Array[Vector2] = []
	var start: int = cells[0]
	var prev: int = cells[0]
	for i in range(1, cells.size()):
		var c: int = cells[i]
		if c == prev:
			continue
		if c != prev + 1:
			out.append(Vector2(start, prev + 1))
			start = c
		prev = c
	out.append(Vector2(start, prev + 1))
	return out


func _subtract(run: Vector2, holes: Array) -> Array[Vector2]:
	var segs: Array[Vector2] = [run]
	for hole in holes:
		var next: Array[Vector2] = []
		for s in segs:
			if hole.y <= s.x or hole.x >= s.y:
				next.append(s)
				continue
			if hole.x > s.x:
				next.append(Vector2(s.x, hole.x))
			if hole.y < s.y:
				next.append(Vector2(hole.y, s.y))
		segs = next
	var out: Array[Vector2] = []
	for s in segs:
		if s.y - s.x > 0.05:
			out.append(s)
	return out


func _wall_box(base: Vector3, size: Vector3, full := true) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = base + Vector3(0, size.y * 0.5, 0)
	var mat := _mat(Color(0.62, 0.57, 0.5))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.material_override = mat
	root.add_child(m)
	walls.append(m)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	m.add_child(body)


func _door(d: Dictionary) -> void:
	var door: Door = DOOR_SCENE.instantiate()
	door.name = "Door_" + String(d["id"])
	door.door_id = d["id"]
	door.room_a = d["a"]
	door.room_b = d["b"]
	door.key_id = d.get("key", &"")
	door.lock_side = d.get("lock_side", &"")
	door.locked_initially = d.get("locked", false)
	door.sound_level = d.get("sound", 0.5)
	door.hearing_factor = d.get("hearing", 0.3)
	door.sight_factor = d.get("sight", 0.0)
	door.width = d.get("width", 1.0)
	door.height = DOOR_H - 0.05
	door.position = Vector3((d["pos"] as Vector2).x, 0, (d["pos"] as Vector2).y)
	door.rotation_degrees.y = d["rot"]
	door.collision_layer = LAYER_WORLD
	root.add_child(door)
	(door.get_node(^"SwingArea") as Area3D).collision_mask = LAYER_PLAYER | LAYER_NPC
	(door.get_node(^"Label3D") as Label3D).visible = false
	var panel := door.get_node(^"Hinge/Panel") as MeshInstance3D
	panel.material_override = _mat(Color(0.78, 0.6, 0.38))
	var w: float = d.get("width", 1.0)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.12, DOOR_H, 0.3)
		post.mesh = pb
		post.material_override = _mat(Color(0.2, 0.13, 0.08))
		post.position = Vector3(side * (w * 0.5 + 0.06), DOOR_H * 0.5, 0)
		door.add_child(post)
	doors[d["id"]] = door


func _furniture(f: Dictionary) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = f["size"]
	m.mesh = b
	m.position = Vector3((f["pos"] as Vector2).x, (f["size"] as Vector3).y * 0.5, (f["pos"] as Vector2).y)
	m.material_override = _mat(f["color"])
	root.add_child(m)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = f["size"]
	cs.shape = bs
	body.add_child(cs)
	m.add_child(body)
	if f.get("tag", &"") == &"bed":
		var pillow := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(1.6, 0.15, 0.5)
		pillow.mesh = pb
		pillow.position = Vector3(0, 0.37, 1.1)
		pillow.material_override = _mat(Color(0.95, 0.95, 0.92))
		m.add_child(pillow)
	elif f.get("tag", &"") == &"hearth":
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.55, 0.25)
		fire.light_energy = 0.0
		fire.omni_range = 5.0
		fire.position = Vector3(0, 0.2, 0.6)
		fire.name = "Fire"
		m.add_child(fire)
		props[&"hearth_light"] = fire


func _lamp(at: Vector2, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.52)
	l.light_energy = energy * 1.7
	l.omni_range = 8.5
	l.omni_attenuation = 1.2
	l.position = Vector3(at.x, 2.4, at.y)
	root.add_child(l)


func _prop(p: Dictionary) -> void:
	var n := Node3D.new()
	n.name = "Prop_" + String(p["id"])
	n.position = Vector3((p["pos"] as Vector2).x, 0, (p["pos"] as Vector2).y)
	n.set_meta(&"prop_id", p["id"])
	n.set_meta(&"prompt", p["prompt"])
	n.set_meta(&"room", p["room"])
	var glint := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	glint.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	glint.material_override = mat
	glint.position.y = 1.1
	glint.name = "Glint"
	n.add_child(glint)
	root.add_child(n)
	props[p["id"]] = n


func _sign(r: Dictionary) -> void:
	if font == null:
		return
	var rect: Rect2 = r["rect"]
	var t := TypesetterText3D.new()
	t.font = font
	t.font_size = 6.0
	t.rect_size = Vector2(rect.size.x * 1.6, 2.0)
	t.horizontal_alignment = TypesetterText3D.HorizontalAlignmentOptions.CENTER
	t.vertical_alignment = TypesetterText3D.VerticalAlignmentOptions.MIDDLE
	t.color = Color(0.95, 0.88, 0.7, 0.55)
	t.text = String(r["name"]).to_upper()
	t.character_spacing = 12.0
	t.rotation_degrees = Vector3(-90, 0, 0)
	t.scale = Vector3.ONE * 0.5
	t.position = Vector3(rect.get_center().x, 0.02, rect.end.y - 0.6)
	root.add_child(t)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m
