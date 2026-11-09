class_name Mannequin
extends Node3D
## A generic jointed mannequin built from primitives: no assets, no skeleton.
## Faces -Z. Drive it with `speed` (m/s) and `pose`; it blends between poses.

enum Pose { STAND, WALK, LISTEN, PEEK, KNOCK, WORK, SIT, SLEEP, READ }

@export var body_color: Color = Color(0.86, 0.78, 0.66)
@export var joint_color: Color = Color(0.55, 0.45, 0.36)
## Role accent: a sash for family, an apron for servants, a coat for visitors.
@export var accent_color: Color = Color(0.2, 0.3, 0.5)
@export_enum("sash", "apron", "coat", "none") var accent: String = "sash"
@export var height_scale: float = 1.0

var pose: int = Pose.STAND
var speed: float = 0.0

var _hips: Node3D
var _spine: Node3D
var _neck: Node3D
var _shoulder := {}
var _elbow := {}
var _hip := {}
var _knee := {}
var _phase: float = 0.0
var _t: float = 0.0
var _cur := {}


func _ready() -> void:
	scale = Vector3.ONE * height_scale
	_build()


func _process(delta: float) -> void:
	_t += delta
	var target := _target_angles()
	var k := 1.0 - exp(-delta * 10.0)
	for key in target:
		_cur[key] = lerpf(float(_cur.get(key, 0.0)), float(target[key]), k)
	_apply()


func _target_angles() -> Dictionary:
	var a := {
		"hips_y": 0.95, "hips_rot_x": 0.0, "spine_x": 0.0, "spine_z": 0.0, "neck_x": 0.0, "neck_z": 0.0,
		"sh_l_x": 0.0, "sh_r_x": 0.0, "sh_l_z": -0.08, "sh_r_z": 0.08, "el_l": 0.15, "el_r": 0.15,
		"hip_l": 0.0, "hip_r": 0.0, "kn_l": 0.0, "kn_r": 0.0, "lie": 0.0,
	}
	var breathe := sin(_t * 1.7) * 0.02
	a["spine_x"] = breathe
	match pose:
		Pose.WALK, Pose.STAND:
			if speed > 0.05:
				_phase += get_process_delta_time() * (4.0 + speed * 3.0)
				var amp := clampf(speed / 2.5, 0.25, 0.75)
				var s := sin(_phase)
				a["hip_l"] = s * amp
				a["hip_r"] = -s * amp
				a["kn_l"] = maxf(0.0, -cos(_phase)) * amp * 1.4
				a["kn_r"] = maxf(0.0, cos(_phase)) * amp * 1.4
				a["sh_l_x"] = -s * amp * 0.8
				a["sh_r_x"] = s * amp * 0.8
				a["el_l"] = 0.3
				a["el_r"] = 0.3
				a["hips_y"] = 0.95 + absf(cos(_phase)) * 0.03
				a["spine_x"] = -0.05
		Pose.LISTEN:
			a["spine_x"] = -0.25
			a["spine_z"] = 0.18
			a["neck_z"] = 0.35
			a["neck_x"] = -0.1
			a["sh_r_x"] = 0.3
			a["el_r"] = 1.9
			a["sh_r_z"] = 1.2
			a["kn_l"] = 0.2
			a["kn_r"] = 0.2
			a["hip_l"] = 0.1
			a["hip_r"] = 0.1
			a["hips_y"] = 0.91
		Pose.PEEK:
			a["hips_y"] = 0.62
			a["hip_l"] = 1.1
			a["hip_r"] = 0.8
			a["kn_l"] = 1.9
			a["kn_r"] = 1.6
			a["spine_x"] = -0.55
			a["neck_x"] = 0.35
			a["sh_l_x"] = 0.6
			a["sh_r_x"] = 0.6
			a["el_l"] = 1.0
			a["el_r"] = 1.0
		Pose.KNOCK:
			a["sh_r_x"] = 1.5 + sin(_t * 14.0) * 0.12
			a["el_r"] = 1.2 + sin(_t * 14.0) * 0.25
			a["sh_r_z"] = -0.1
			a["neck_x"] = -0.05
		Pose.WORK:
			a["spine_x"] = -0.45
			a["sh_l_x"] = 1.00 + sin(_t * 5.0) * 0.3
			a["sh_r_x"] = 1.00 - sin(_t * 5.0) * 0.3
			a["el_l"] = 0.8
			a["el_r"] = 0.8
			a["kn_l"] = 0.25
			a["kn_r"] = 0.25
			a["hip_l"] = 0.25
			a["hip_r"] = 0.25
			a["hips_y"] = 0.9
		Pose.SIT:
			a["hips_y"] = 0.55
			a["hip_l"] = 1.5
			a["hip_r"] = 1.5
			a["kn_l"] = 1.5
			a["kn_r"] = 1.5
			a["sh_l_x"] = 0.4
			a["sh_r_x"] = 0.4
			a["el_l"] = 1.0
			a["el_r"] = 1.0
			a["spine_x"] = 0.08 + breathe
		Pose.READ:
			a["hips_y"] = 0.55
			a["hip_l"] = 1.5
			a["hip_r"] = 1.5
			a["kn_l"] = 1.5
			a["kn_r"] = 1.5
			a["sh_l_x"] = 0.9
			a["sh_r_x"] = 0.9
			a["el_l"] = 1.6
			a["el_r"] = 1.6
			a["sh_l_z"] = 0.35
			a["sh_r_z"] = -0.35
			a["neck_x"] = -0.4
			a["spine_x"] = -0.12
		Pose.SLEEP:
			a["lie"] = 1.0
			a["hips_y"] = 0.25
			a["sh_l_z"] = 0.2
			a["sh_r_z"] = -0.2
			a["kn_l"] = 0.15
			a["kn_r"] = 0.3
			a["spine_x"] = breathe * 2.0
	return a


func _apply() -> void:
	var lie := float(_cur["lie"])
	_hips.position.y = float(_cur["hips_y"])
	_hips.rotation.x = lie * (PI * 0.5)
	_hips.position.z = lie * -0.35
	_spine.rotation = Vector3(_cur["spine_x"], 0, _cur["spine_z"])
	_neck.rotation = Vector3(_cur["neck_x"], 0, _cur["neck_z"])
	_shoulder["l"].rotation = Vector3(_cur["sh_l_x"], 0, _cur["sh_l_z"])
	_shoulder["r"].rotation = Vector3(_cur["sh_r_x"], 0, _cur["sh_r_z"])
	_elbow["l"].rotation.x = float(_cur["el_l"])
	_elbow["r"].rotation.x = float(_cur["el_r"])
	_hip["l"].rotation.x = _cur["hip_l"]
	_hip["r"].rotation.x = _cur["hip_r"]
	_knee["l"].rotation.x = -float(_cur["kn_l"])
	_knee["r"].rotation.x = -float(_cur["kn_r"])


func head_global() -> Vector3:
	return _neck.global_position + Vector3(0, 0.3, 0)


# --- construction --------------------------------------------------------------------

func _build() -> void:
	var body := _mat(body_color)
	var joint := _mat(joint_color)
	var acc := _mat(accent_color)
	_hips = _node(self, Vector3(0, 0.95, 0))
	_part(_hips, _capsule(0.15, 0.32), Vector3(0, 0.0, 0), body, Vector3(0, 0, PI / 2))
	_spine = _node(_hips, Vector3(0, 0.08, 0))
	_part(_spine, _capsule(0.17, 0.5), Vector3(0, 0.25, 0), body)
	_part(_spine, _capsule(0.13, 0.36), Vector3(0, 0.42, 0), body, Vector3(0, 0, PI / 2))
	match accent:
		"sash":
			_part(_spine, _box(Vector3(0.36, 0.08, 0.36)), Vector3(0, 0.3, 0), acc, Vector3(0, 0, 0.5))
		"apron":
			_part(_spine, _box(Vector3(0.3, 0.42, 0.05)), Vector3(0, 0.05, -0.16), _mat(Color(0.93, 0.93, 0.9)))
			_part(_hips, _box(Vector3(0.34, 0.5, 0.05)), Vector3(0, -0.2, -0.17), _mat(Color(0.93, 0.93, 0.9)))
			_part(_spine, _box(Vector3(0.36, 0.2, 0.34)), Vector3(0, 0.2, 0), acc)
		"coat":
			_part(_spine, _box(Vector3(0.4, 0.62, 0.3)), Vector3(0, 0.2, 0.0), acc)
			_part(_hips, _box(Vector3(0.38, 0.4, 0.28)), Vector3(0, -0.18, 0.02), acc)
	_neck = _node(_spine, Vector3(0, 0.55, 0))
	_part(_neck, _sphere(0.06), Vector3.ZERO, joint)
	_part(_neck, _sphere(0.13, 0.17), Vector3(0, 0.16, 0), body)
	# A nose so facing reads at a glance.
	_part(_neck, _sphere(0.03), Vector3(0, 0.16, -0.125), joint)
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var sh := _node(_spine, Vector3(0.21 * sx, 0.44, 0))
		_part(sh, _sphere(0.06), Vector3.ZERO, joint)
		_part(sh, _capsule(0.05, 0.3), Vector3(0, -0.16, 0), body)
		var el := _node(sh, Vector3(0, -0.31, 0))
		_part(el, _sphere(0.045), Vector3.ZERO, joint)
		_part(el, _capsule(0.045, 0.27), Vector3(0, -0.14, 0), body)
		_part(el, _sphere(0.055), Vector3(0, -0.3, 0), body)
		_shoulder[side] = sh
		_elbow[side] = el
		var hp := _node(_hips, Vector3(0.1 * sx, -0.06, 0))
		_part(hp, _sphere(0.07), Vector3.ZERO, joint)
		_part(hp, _capsule(0.07, 0.42), Vector3(0, -0.22, 0), body)
		var kn := _node(hp, Vector3(0, -0.44, 0))
		_part(kn, _sphere(0.055), Vector3.ZERO, joint)
		_part(kn, _capsule(0.055, 0.4), Vector3(0, -0.21, 0), body)
		_part(kn, _box(Vector3(0.1, 0.06, 0.22)), Vector3(0, -0.42, -0.05), joint)
		_hip[side] = hp
		_knee[side] = kn
	_apply_defaults()


func _apply_defaults() -> void:
	for k in _target_angles():
		_cur[k] = _target_angles()[k]
	_apply()


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float, h: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = (h if h > 0.0 else r) * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	return m
