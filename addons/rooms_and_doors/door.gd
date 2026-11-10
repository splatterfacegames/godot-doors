class_name Door
extends StaticBody3D
## Thin view of a door (§6.2). Renders state read from RoomsAndDoors and forwards
## interactions to it. Never stores authoritative state. Works with placeholder art.
##
## Orientation: local +Z points into room_b, -Z into room_a. The hinge is at local -X.

@export var door_id: StringName = &""
@export var room_a: StringName = &""
@export var room_b: StringName = &""
@export var key_id: StringName = &""
@export var lock_side: StringName = &""
@export var locked_initially: bool = false
@export_range(0.0, 2.0) var sound_level: float = 0.5
@export_range(0.0, 1.0) var hearing_factor: float = 0.3
@export_range(0.0, 1.0) var sight_factor: float = 0.0
@export_range(0.0, 1.0) var ajar_hearing_bonus: float = 0.6
@export var swing_time: float = 0.35
@export var width: float = 1.0
@export var height: float = 2.1
@export var ajar_angle_deg: float = 22.0
@export var open_angle_deg: float = 95.0
## Character/prop physics layers observed by interaction and safe-close volumes.
@export_flags_3d_physics var actor_collision_mask: int = 6
@export var creak_stream: AudioStream
@export var knock_stream: AudioStream
@export var latch_stream: AudioStream

@onready var _hinge: Node3D = $Hinge
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $Label3D
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _interactable: Area3D = $Interactable
@onready var _swing_area: Area3D = $SwingArea

var _bodies_in_swing: Dictionary = {}
var _rendered_state: int = -1


func _ready() -> void:
	_interactable.collision_mask = actor_collision_mask
	_swing_area.collision_mask = actor_collision_mask
	_apply_size()
	_build_placeholder_clips()
	if creak_stream == null:
		creak_stream = PlaceholderAudio.creak()
	if knock_stream == null:
		knock_stream = PlaceholderAudio.knock()
	if latch_stream == null:
		latch_stream = PlaceholderAudio.latch()
	_swing_area.body_entered.connect(_on_swing_body_entered)
	_swing_area.body_exited.connect(_on_swing_body_exited)
	_interactable.body_entered.connect(_on_threshold_entered)
	_interactable.body_exited.connect(_on_threshold_exited)
	RoomsAndDoors.door_state_changed.connect(_on_door_state_changed)
	RoomsAndDoors.door_used.connect(_on_door_used)
	register_with_system()


func _exit_tree() -> void:
	_audio.stop()
	_audio.stream = null


func register_with_system() -> void:
	RoomsAndDoors.register_door({
		"id": door_id, "room_a": room_a, "room_b": room_b, "key_id": key_id,
		"lock_side": lock_side, "locked": locked_initially, "sound_level": sound_level,
		"hearing_factor": hearing_factor, "sight_factor": sight_factor,
		"ajar_hearing_bonus": ajar_hearing_bonus, "swing_time": swing_time,
	})
	RoomsAndDoors.bind_door_node(door_id, self)
	_render(RoomsAndDoors.get_door(door_id), true)


## Interactable entry point. verb: toggle/open/close/ajar/knock/announce/lock/unlock/
## listen/peek/hold/release. Returns a Result (or {} for void actions).
func interact(actor_id: StringName, verb: StringName = &"toggle", opts: Dictionary = {}) -> Dictionary:
	var policies := RoomsAndDoors.policy_controller as DoorPolicies
	if policies != null and verb in [&"toggle", &"open"]:
		var current := RoomsAndDoors.get_door(door_id)
		if verb == &"open" or int(current.get("state", RAD.DoorState.CLOSED)) != RAD.DoorState.OPEN:
			return policies.request_open(door_id, actor_id, opts)
	match verb:
		&"toggle":
			var st := int(RoomsAndDoors.get_door(door_id).get("state", RAD.DoorState.CLOSED))
			return RoomsAndDoors.try_close(door_id, actor_id, opts) if st == RAD.DoorState.OPEN \
					else RoomsAndDoors.try_open(door_id, actor_id, opts)
		&"open": return RoomsAndDoors.try_open(door_id, actor_id, opts)
		&"close": return RoomsAndDoors.try_close(door_id, actor_id, opts)
		&"ajar": return RoomsAndDoors.set_ajar(door_id, actor_id, opts)
		&"lock": return RoomsAndDoors.try_lock(door_id, actor_id)
		&"unlock": return RoomsAndDoors.try_unlock(door_id, actor_id)
		&"hold": return RoomsAndDoors.hold_open(door_id, actor_id)
		&"release": return RoomsAndDoors.release_hold(door_id, actor_id)
		&"knock": RoomsAndDoors.knock(door_id, actor_id)
		&"announce": RoomsAndDoors.announce(door_id, actor_id, String(opts.get("errand", "")))
		&"listen": RoomsAndDoors.start_listening(actor_id, door_id)
		&"peek": RoomsAndDoors.start_peeking(actor_id, door_id)
	return {}


## Prompt text for the Interactable (§6.2).
func get_prompt(actor_id: StringName) -> String:
	if is_instance_valid(RoomsAndDoors.policy_controller):
		return RoomsAndDoors.policy_controller.get_hint(door_id, actor_id)
	var d := RoomsAndDoors.get_door(door_id)
	if d.is_empty():
		return ""
	var pass_check := RoomsAndDoors.may_pass(actor_id, door_id)
	if bool(d["locked"]):
		return "Unlock" if bool(pass_check["ok"]) else "Locked — Knock"
	match int(d["state"]):
		RAD.DoorState.OPEN: return "Close"
		RAD.DoorState.AJAR: return "Open / Listen"
	return "Open / Knock"


func _on_door_state_changed(id: StringName, door: Dictionary) -> void:
	if id == door_id:
		_render(door, false)


func _on_door_used(id: StringName, _actor: StringName, action: StringName, noise: float) -> void:
	if id != door_id or not is_inside_tree():
		return
	var stream: AudioStream = creak_stream
	match action:
		&"knock", &"announce":
			stream = knock_stream
			if _anim.has_animation(&"knock"):
				_anim.play(&"knock")
		&"lock", &"unlock", &"close":
			stream = latch_stream
	_audio.stream = stream
	_audio.volume_db = linear_to_db(clampf(noise, 0.02, 3.0))
	_audio.play()


func _render(door: Dictionary, snap: bool) -> void:
	if door.is_empty() or not is_inside_tree():
		return
	var st := int(door["state"])
	# AJAR blocks bodies but not sound/sight; only OPEN lets bodies through.
	var visual_only := bool(get_meta(&"visual_only", false))
	_shape.set_deferred(&"disabled", st == RAD.DoorState.OPEN and not visual_only)
	_label.text = "%s\n%s%s%s" % [door_id, RAD.door_state_name(st),
			" [LOCKED]" if bool(door["locked"]) else "",
			" held:%s" % door["held_by"] if StringName(door["held_by"]) != &"" else ""]
	if st == _rendered_state and not snap:
		return
	_rendered_state = st
	var clip: StringName = [&"close", &"ajar", &"open"][st]
	if snap or not _anim.has_animation(clip):
		_hinge.rotation_degrees.y = _angle_for(st)
	else:
		_anim.play(clip)


func _angle_for(state: int) -> float:
	match state:
		RAD.DoorState.AJAR: return ajar_angle_deg
		RAD.DoorState.OPEN: return open_angle_deg
	return 0.0


func _on_swing_body_entered(body: Node) -> void:
	if body == self:
		return
	_bodies_in_swing[body.get_instance_id()] = true
	RoomsAndDoors.set_door_blocked(door_id, true)


func _on_swing_body_exited(body: Node) -> void:
	_bodies_in_swing.erase(body.get_instance_id())
	if _bodies_in_swing.is_empty():
		RoomsAndDoors.set_door_blocked(door_id, false)


func _on_threshold_entered(body: Node) -> void:
	var actor := RoomsAndDoors.character_id_for_body(body)
	if actor != &"" and is_instance_valid(RoomsAndDoors.policy_controller):
		RoomsAndDoors.policy_controller.enter_threshold(door_id, actor)


func _on_threshold_exited(body: Node) -> void:
	var actor := RoomsAndDoors.character_id_for_body(body)
	if actor != &"" and is_instance_valid(RoomsAndDoors.policy_controller):
		RoomsAndDoors.policy_controller.exit_threshold(door_id, actor)


func apply_policy_geometry(config: Dictionary) -> void:
	width = maxf(0.1, float(config.get("width", width)))
	height = maxf(0.1, float(config.get("height", height)))
	set_meta(&"visual_only", StringName(config.get("mode", "interactive")) == &"visual_only")
	_apply_size()
	_render(RoomsAndDoors.get_door(door_id), true)


func _apply_size() -> void:
	var block := _shape.shape as BoxShape3D
	if block != null:
		block = block.duplicate()
		block.size = Vector3(width, height, block.size.z)
		_shape.shape = block
		_shape.position.y = height * 0.5
	_hinge.position.x = -width * 0.5
	var panel := _hinge.get_node_or_null(^"Panel") as MeshInstance3D
	if panel != null and panel.mesh is BoxMesh:
		var m := (panel.mesh as BoxMesh).duplicate() as BoxMesh
		m.size = Vector3(width, height, m.size.z)
		panel.mesh = m
		panel.position = Vector3(width * 0.5, height * 0.5, 0.0)
	_label.position.y = height + 0.35
	_swing_area.position = Vector3(0.0, height * 0.5, width * 0.55)
	var swing_shape := _swing_area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if swing_shape != null:
		var swing_box := BoxShape3D.new()
		swing_box.size = Vector3(width, height, width * 1.1)
		swing_shape.shape = swing_box
	_interactable.position.y = height * 0.5
	var interaction_shape := _interactable.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if interaction_shape != null:
		var interaction_box := BoxShape3D.new()
		interaction_box.size = Vector3(width + 0.6, height + 0.1, maxf(2.4, width * 2.0))
		interaction_shape.shape = interaction_box


## Placeholder open/close/ajar/knock clips driving Hinge rotation (§6.2).
func _build_placeholder_clips() -> void:
	var lib: AnimationLibrary
	if _anim.has_animation_library(&""):
		lib = _anim.get_animation_library(&"")
	else:
		lib = AnimationLibrary.new()
		_anim.add_animation_library(&"", lib)
	var path := NodePath("%s:rotation_degrees:y" % get_path_to(_hinge))
	var targets := { &"open": open_angle_deg, &"close": 0.0, &"ajar": ajar_angle_deg }
	for clip in targets:
		if lib.has_animation(clip):
			continue
		var a := Animation.new()
		a.length = maxf(swing_time, 0.05)
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, path)
		a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
		# First key is replaced at play time with the current angle.
		a.track_insert_key(t, 0.0, 0.0)
		a.track_insert_key(t, a.length, float(targets[clip]))
		lib.add_animation(clip, a)
	if not lib.has_animation(&"knock"):
		var k := Animation.new()
		k.length = 0.45
		var kt := k.add_track(Animation.TYPE_VALUE)
		k.track_set_path(kt, NodePath("%s:position:z" % get_path_to(_hinge)))
		for i in 3:
			k.track_insert_key(kt, i * 0.15, 0.0)
			k.track_insert_key(kt, i * 0.15 + 0.05, -0.01)
		k.track_insert_key(kt, 0.45, 0.0)
		lib.add_animation(&"knock", k)
	_anim.animation_started.connect(_on_anim_started)


func _on_anim_started(clip: StringName) -> void:
	if clip in [&"open", &"close", &"ajar"]:
		var a := _anim.get_animation(clip)
		a.track_set_key_value(0, 0, _hinge.rotation_degrees.y)
