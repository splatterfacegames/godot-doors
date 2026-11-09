class_name ManorCamera
extends Node3D
## High three-quarter camera that follows a target and fades walls between itself
## and the target, so the house reads as a dollhouse.

@export var distance: float = 11.0
@export var pitch_deg: float = 58.0

var target: Node3D
var walls: Array[MeshInstance3D] = []
var yaw: float = 0.0
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	add_child(camera)


func _process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_Z):
		yaw += delta * 1.6
	if Input.is_physical_key_pressed(KEY_X):
		yaw -= delta * 1.6
	if target == null:
		return
	var focus := target.global_position + Vector3(0, 1.0, 0)
	global_position = global_position.lerp(focus, 1.0 - exp(-delta * 6.0))
	var p := deg_to_rad(pitch_deg)
	var offset := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * distance
	camera.global_position = global_position + offset
	camera.look_at(global_position, Vector3.UP)
	_fade_walls(delta, focus)


func _fade_walls(delta: float, focus: Vector3) -> void:
	var cam := Vector2(camera.global_position.x, camera.global_position.z)
	var foc := Vector2(focus.x, focus.z)
	for w in walls:
		var aabb := w.get_aabb()
		var c := w.global_position
		var half := Vector2(aabb.size.x, aabb.size.z) * 0.5
		var near := _segment_hits_rect(foc, cam.lerp(foc, 0.0), Vector2(c.x, c.z), half + Vector2(0.9, 0.9))
		# Only walls on the camera side of the focus fade.
		var toward := (Vector2(c.x, c.z) - foc).dot(cam - foc) > 0.0
		var want := 0.18 if (near and toward) else 1.0
		var mat := w.material_override as StandardMaterial3D
		mat.albedo_color.a = lerpf(mat.albedo_color.a, want, 1.0 - exp(-delta * 8.0))


func _segment_hits_rect(a: Vector2, b: Vector2, centre: Vector2, half: Vector2) -> bool:
	# Sample the focus->camera segment over its first 9 m.
	var dir := (b - a)
	var len := minf(dir.length(), 9.0)
	dir = dir.normalized()
	var t := 0.0
	while t <= len:
		var p := a + dir * t
		if absf(p.x - centre.x) <= half.x and absf(p.y - centre.y) <= half.y:
			return true
		t += 0.35
	return false
