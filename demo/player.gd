class_name ManorPlayer
extends CharacterBody3D
## The new maid. WASD to walk (Shift sneaks: slower, quiet doors). Interacts with
## the nearest door or prop through RoomsAndDoors; never touches door state itself.

signal message(text: String)
signal prop_used(prop_id: StringName)
signal chore_progress(prop_id: StringName, progress: float)

const WALK := 2.6
const SNEAK := 1.1
const REACH_DOOR := 1.8
const REACH_PROP := 1.5
const CHORE_SECONDS := 3.0

@export var character_id: StringName = &"maid"

var mannequin: Mannequin
var builder: ManorBuilder
var camera_yaw: float = 0.0
var enabled: bool = false
var sneaking: bool = false
var posture: int = RAD.Posture.NORMAL
var target_door: StringName = &""
var target_prop: StringName = &""
var _chore_t: float = 0.0
var _knock_t: float = 0.0
var used_props: Dictionary = {}
## Driven by a script (demo verification modes): ignore keyboard input.
var scripted: bool = false
## Scripted walking: points to walk through, in order.
var walk_points: Array[Vector3] = []
## Scripted walking speed (0 = the normal walk/sneak speed).
var walk_speed_override: float = 0.0


func setup(b: ManorBuilder) -> void:
	builder = b
	name = "Player"
	collision_layer = ManorBuilder.LAYER_PLAYER
	collision_mask = ManorBuilder.LAYER_WORLD | ManorBuilder.LAYER_NPC
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	mannequin = Mannequin.new()
	mannequin.body_color = Color(0.9, 0.84, 0.74)
	mannequin.accent_color = Color(0.12, 0.12, 0.16)
	mannequin.accent = "apron"
	mannequin.height_scale = 0.97
	add_child(mannequin)
	floor_snap_length = 0.3


func _physics_process(delta: float) -> void:
	if not enabled:
		mannequin.speed = 0.0
		return
	_update_targets()
	if not scripted:
		sneaking = Input.is_physical_key_pressed(KEY_SHIFT)
		_update_posture()
	var dir := Vector2.ZERO
	if posture == RAD.Posture.NORMAL and not scripted:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	dir = dir.normalized().rotated(-camera_yaw)
	var speed := SNEAK if sneaking else WALK
	if scripted and not walk_points.is_empty():
		var to := walk_points[0] - global_position
		to.y = 0.0
		if to.length() < 0.12:
			walk_points.pop_front()
		else:
			dir = Vector2(to.x, to.z).normalized()
			if walk_speed_override > 0.0:
				speed = walk_speed_override
	velocity.x = dir.x * speed
	velocity.z = dir.y * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	mannequin.speed = flat.length()
	if flat.length() > 0.1:
		var yaw := atan2(-flat.x, -flat.y)
		mannequin.rotation.y = lerp_angle(mannequin.rotation.y, yaw, 0.25)
	if not scripted:
		_update_chore(delta)
	_knock_t = maxf(0.0, _knock_t - delta)
	if _knock_t > 0.0:
		mannequin.pose = Mannequin.Pose.KNOCK
	elif posture == RAD.Posture.LISTEN:
		mannequin.pose = Mannequin.Pose.LISTEN
	elif posture == RAD.Posture.PEEK:
		mannequin.pose = Mannequin.Pose.PEEK
	elif _chore_t > 0.0:
		mannequin.pose = Mannequin.Pose.WORK
	else:
		mannequin.pose = Mannequin.Pose.WALK


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	match k:
		KEY_E: _use()
		KEY_F: _knock()
		KEY_G: _ajar()
		KEY_L: _lock_toggle()


func _update_targets() -> void:
	var here := RoomsAndDoors.room_of(character_id)
	var best := REACH_DOOR
	target_door = &""
	for id in builder.doors:
		var d: Door = builder.doors[id]
		if here != d.room_a and here != d.room_b:
			continue
		var dist := _flat_distance(d.global_position)
		if dist < best:
			best = dist
			target_door = id
	target_prop = &""
	var best_p := REACH_PROP
	for id in builder.props:
		var p: Node3D = builder.props[id]
		if not p.has_meta(&"prop_id") or not p.visible or p.get_meta(&"room") != here:
			continue
		var dist := _flat_distance(p.global_position)
		if dist < best_p:
			best_p = dist
			target_prop = id
	# A prop in reach beats a door further away.
	if target_prop != &"" and target_door != &"" and best_p < best:
		target_door = &""


func _update_posture() -> void:
	var want := RAD.Posture.NORMAL
	if target_door != &"":
		if Input.is_physical_key_pressed(KEY_R):
			want = RAD.Posture.LISTEN
		elif Input.is_physical_key_pressed(KEY_T):
			want = RAD.Posture.PEEK
	if want == posture:
		return
	if posture == RAD.Posture.LISTEN:
		RoomsAndDoors.stop_listening(character_id)
	elif posture == RAD.Posture.PEEK:
		RoomsAndDoors.stop_peeking(character_id)
	posture = RAD.Posture.NORMAL
	if want == RAD.Posture.LISTEN and RoomsAndDoors.start_listening(character_id, target_door):
		posture = want
		_face(builder.doors[target_door].global_position)
	elif want == RAD.Posture.PEEK and RoomsAndDoors.start_peeking(character_id, target_door):
		posture = want
		_face(builder.doors[target_door].global_position)


func _update_chore(delta: float) -> void:
	var holding := Input.is_physical_key_pressed(KEY_E) and target_prop != &"" \
			and bool(ManorLayout.PROPS.any(func(p): return p["id"] == target_prop and p.get("chore", false))) \
			and not used_props.has(target_prop)
	if holding:
		_chore_t += delta
		chore_progress.emit(target_prop, _chore_t / CHORE_SECONDS)
		if _chore_t >= CHORE_SECONDS:
			used_props[target_prop] = true
			_chore_t = 0.0
			chore_progress.emit(target_prop, -1.0)
			prop_used.emit(target_prop)
	elif _chore_t > 0.0:
		_chore_t = 0.0
		chore_progress.emit(target_prop, -1.0)


func _use() -> void:
	if target_prop != &"":
		var is_chore := ManorLayout.PROPS.any(func(p): return p["id"] == target_prop and p.get("chore", false))
		if not is_chore:
			prop_used.emit(target_prop)
		return
	if target_door == &"":
		return
	var d := RoomsAndDoors.get_door(target_door)
	var opts := { "quiet": sneaking }
	if int(d["state"]) == RAD.DoorState.OPEN:
		var r := RoomsAndDoors.try_close(target_door, character_id, opts)
		if not bool(r["ok"]):
			message.emit("It won't close — %s." % _reason(r["reason"]))
		return
	if bool(d["locked"]):
		var u := RoomsAndDoors.try_unlock(target_door, character_id)
		if not bool(u["ok"]):
			message.emit("Locked.")
			return
		message.emit("You turn the key.")
	var o := RoomsAndDoors.try_open(target_door, character_id, opts)
	if not bool(o["ok"]):
		message.emit("It won't open — %s." % _reason(o["reason"]))


func _knock() -> void:
	if target_door == &"":
		return
	RoomsAndDoors.knock(target_door, character_id)
	_knock_t = 0.6
	_face(builder.doors[target_door].global_position)


func _ajar() -> void:
	if target_door == &"":
		return
	var r := RoomsAndDoors.set_ajar(target_door, character_id, { "quiet": sneaking })
	if not bool(r["ok"]):
		message.emit("Can't leave it ajar — %s." % _reason(r["reason"]))


func _lock_toggle() -> void:
	if target_door == &"":
		return
	var d := RoomsAndDoors.get_door(target_door)
	var r := RoomsAndDoors.try_unlock(target_door, character_id) if bool(d["locked"]) \
			else RoomsAndDoors.try_lock(target_door, character_id)
	if bool(r["ok"]):
		message.emit("Unlocked." if bool(d["locked"]) else "Locked.")
	else:
		message.emit("You can't — %s." % _reason(r["reason"]))


func prompt_text() -> String:
	if not enabled:
		return ""
	if posture == RAD.Posture.LISTEN:
		return "Listening at the door…  (release R)"
	if posture == RAD.Posture.PEEK:
		return "Peeking through the keyhole…  (release T)"
	if target_prop != &"":
		var p: Node3D = builder.props[target_prop]
		var is_chore := ManorLayout.PROPS.any(func(x): return x["id"] == target_prop and x.get("chore", false))
		return ("[E hold] " if is_chore else "[E] ") + String(p.get_meta(&"prompt"))
	if target_door == &"":
		return ""
	var d := RoomsAndDoors.get_door(target_door)
	var parts: PackedStringArray = []
	var st := int(d["state"])
	if st == RAD.DoorState.OPEN:
		parts.append("[E] Close")
	elif bool(d["locked"]):
		parts.append("[E] Unlock" if bool(RoomsAndDoors.may_pass(character_id, target_door)["ok"]) else "Locked")
	else:
		parts.append("[E] Open")
	if st != RAD.DoorState.OPEN:
		parts.append("[F] Knock")
		parts.append("[R] Listen")
		if float(d["sight_factor"]) > 0.0 or st == RAD.DoorState.AJAR:
			parts.append("[T] Peek")
	if st == RAD.DoorState.CLOSED and not bool(d["locked"]):
		parts.append("[G] Leave ajar")
	if sneaking:
		parts.append("(quietly)")
	return "   ".join(parts)


func _face(at: Vector3) -> void:
	var to := at - global_position
	mannequin.rotation.y = atan2(-to.x, -to.z)


func _flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _reason(r: StringName) -> String:
	match r:
		RAD.LOCKED: return "locked"
		RAD.NO_KEY: return "you have no key"
		RAD.BLOCKED: return "something is in the way"
		RAD.HELD: return "someone is holding it"
		RAD.JAMMED: return "jammed"
		RAD.TRESPASS_DENIED: return "you may not"
	return String(r).to_lower()
