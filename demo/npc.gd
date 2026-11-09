class_name ManorNpc
extends CharacterBody3D
## A household NPC: a Mannequin body, an NpcDoorAgent in wait_for_body mode, and a
## task queue the story fills (walk to a spot, say a line, take a pose, wait,
## operate a door). Locomotion is straight lines inside rectangular rooms.

signal task_done(task: Dictionary)

const WALK_SPEED := 1.35

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var role: StringName = &"servant"

var mannequin: Mannequin
var agent: NpcDoorAgent
var builder: ManorBuilder
var speech: TypesetterText3D
var tasks: Array[Dictionary] = []
var _task: Dictionary = {}
var _waypoints: Array[Vector3] = []
var _face_yaw: float = NAN
var _speech_left: float = 0.0
var _wait_left: float = 0.0
var _rest_pose: int = Mannequin.Pose.STAND
var _lie_height: float = 0.0


func setup(id: StringName, nice_name: String, npc_role: StringName, look: Dictionary, b: ManorBuilder) -> void:
	character_id = id
	display_name = nice_name
	role = npc_role
	builder = b
	name = "Npc_" + String(id)
	collision_layer = ManorBuilder.LAYER_NPC
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	mannequin = Mannequin.new()
	mannequin.body_color = look.get("body", Color(0.86, 0.78, 0.66))
	mannequin.accent_color = look.get("accent", Color(0.3, 0.3, 0.5))
	mannequin.accent = look.get("style", "sash")
	mannequin.height_scale = look.get("height", 1.0)
	add_child(mannequin)
	agent = NpcDoorAgent.new()
	agent.character_id = id
	agent.wait_for_body = true
	add_child(agent)
	agent.approaching.connect(_on_approaching)
	agent.cross_requested.connect(_on_cross_requested)
	agent.arrived.connect(_on_arrived)
	agent.gave_up.connect(func(_r, _why): _finish_task())
	speech = TypesetterText3D.new()
	speech.font = TypesetterSettings.get_default_font_asset()
	speech.font_size = 2.6
	speech.rect_size = Vector2(26, 6)
	speech.horizontal_alignment = TypesetterText3D.HorizontalAlignmentOptions.CENTER
	speech.vertical_alignment = TypesetterText3D.VerticalAlignmentOptions.BOTTOM
	speech.color = Color(1, 0.96, 0.85)
	speech.position = Vector3(0, 2.25, 0)
	speech.visible = false
	add_child(speech)


func place_at_spot(spot: StringName) -> void:
	global_position = ManorLayout.spot_position(spot)
	mannequin.rotation_degrees.y = ManorLayout.SPOTS[spot][2]
	RoomsAndDoors.set_occupant_room(character_id, ManorLayout.spot_room(spot), true)


## Task kinds: go (spot), say (text, seconds), pose (pose), wait (seconds),
## door (door, op), call (callable), sleep (spot).
func push(task: Dictionary) -> void:
	tasks.append(task)


func clear_tasks() -> void:
	tasks.clear()
	_task = {}
	_waypoints.clear()
	agent.cancel()


func is_idle() -> bool:
	return _task.is_empty() and tasks.is_empty()


func say(text: String, seconds: float = 3.5) -> void:
	speech.text = text
	speech.visible = true
	_speech_left = seconds


func _physics_process(delta: float) -> void:
	_tick_speech(delta)
	if _task.is_empty() and not tasks.is_empty():
		_start_task(tasks.pop_front())
	_walk(delta)
	if _task.get("kind") == "wait":
		_wait_left -= delta * RoomsAndDoors.time_scale
		if _wait_left <= 0.0:
			_finish_task()
	if agent.state == NpcDoorAgent.State.AWAIT_KNOCK:
		mannequin.pose = Mannequin.Pose.KNOCK
	elif _waypoints.is_empty() and agent.state not in [NpcDoorAgent.State.APPROACH, NpcDoorAgent.State.CROSSING]:
		mannequin.pose = _rest_pose
	else:
		mannequin.pose = Mannequin.Pose.WALK


func _tick_speech(delta: float) -> void:
	if _speech_left > 0.0:
		_speech_left -= delta
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			speech.global_basis = cam.global_basis
		if _speech_left <= 0.0:
			speech.visible = false


func _start_task(t: Dictionary) -> void:
	_task = t
	match String(t["kind"]):
		"go", "sleep", "sit", "read":
			_rest_pose = Mannequin.Pose.STAND
			_lie_height = 0.0
			var spot: StringName = t["spot"]
			agent.go_to(ManorLayout.spot_room(spot), t.get("business", true))
		"say":
			say(t["text"], t.get("seconds", 3.5))
			_finish_task()
		"pose":
			_rest_pose = t["pose"]
			_finish_task()
		"wait":
			_wait_left = t["seconds"]
		"door":
			var door: StringName = t["door"]
			match String(t["op"]):
				"lock": RoomsAndDoors.try_lock(door, character_id)
				"unlock": RoomsAndDoors.try_unlock(door, character_id)
				"open": RoomsAndDoors.try_open(door, character_id)
				"close": RoomsAndDoors.try_close(door, character_id)
			_finish_task()
		"call":
			(t["fn"] as Callable).call()
			_finish_task()
		_:
			_finish_task()


func _finish_task() -> void:
	var t := _task
	_task = {}
	if not t.is_empty():
		task_done.emit(t)


func _on_approaching(door_id: StringName) -> void:
	var door: Door = builder.doors[door_id]
	var here := RoomsAndDoors.room_of(character_id)
	_waypoints = [_door_point(door, here, 0.95)]
	_face_yaw = NAN


func _on_cross_requested(door_id: StringName, to_room: StringName) -> void:
	var door: Door = builder.doors[door_id]
	_waypoints = [door.global_position, _door_point(door, to_room, 1.5)]


func _on_arrived(_room: StringName) -> void:
	if _task.is_empty():
		return
	var spot: StringName = _task.get("spot", &"")
	if spot == &"":
		_finish_task()
		return
	_waypoints = [ManorLayout.spot_position(spot)]
	_face_yaw = ManorLayout.SPOTS[spot][2]


## A point `dist` metres from the door on the `room` side.
func _door_point(door: Door, room: StringName, dist: float) -> Vector3:
	var n := door.global_basis.z.normalized()
	var sign := 1.0 if room == door.room_b else -1.0
	return door.global_position + n * dist * sign


func _walk(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var target := _waypoints[0]
	var to := target - global_position
	to.y = 0.0
	var step := WALK_SPEED * delta * RoomsAndDoors.time_scale
	if to.length() <= step:
		global_position = Vector3(target.x, _lie_height, target.z)
		_waypoints.pop_front()
		if _waypoints.is_empty():
			_reached()
		return
	global_position += to.normalized() * step
	mannequin.speed = WALK_SPEED
	var yaw := rad_to_deg(atan2(-to.x, -to.z))
	mannequin.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(mannequin.rotation_degrees.y), deg_to_rad(yaw), 0.2))


func _reached() -> void:
	mannequin.speed = 0.0
	match agent.state:
		NpcDoorAgent.State.APPROACH:
			agent.notify_at_door()
			return
		NpcDoorAgent.State.CROSSING:
			agent.notify_crossed()
			return
	if not is_nan(_face_yaw):
		mannequin.rotation_degrees.y = _face_yaw
	if _task.is_empty():
		return
	match String(_task["kind"]):
		"sleep":
			_rest_pose = Mannequin.Pose.SLEEP
			_lie_height = 0.6
			global_position.y = 0.6
			RoomsAndDoors.set_sleeping(character_id, true)
		"sit":
			_rest_pose = Mannequin.Pose.SIT
		"read":
			_rest_pose = Mannequin.Pose.READ
	_finish_task()
