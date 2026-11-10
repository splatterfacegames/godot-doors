class_name NpcDoorAgent
extends Node
## Room-graph door behaviour for an NPC (§10). Plans with may_pass, opens doors
## fully before crossing (AJAR doors included: being heard is the point), knocks when
## it has business at a door it may not pass, otherwise reroutes or waits, and closes
## doors behind it by its role's manners. It only changes rooms through OPEN doors.
##
## Fine movement (navmesh, animation) is the game's job. Two modes:
## - timed (default): the agent waits `step_time` per door; move the body on `crossed`.
## - `wait_for_body`: the agent waits for the body. Walk to the door on `approaching`
##   and call notify_at_door(); walk through on `cross_requested` and call
##   notify_crossed() once clear of the swing. The agent owns the door protocol,
##   never locomotion.

signal approaching(door_id: StringName)
signal crossed(door_id: StringName, to_room: StringName)
signal cross_requested(door_id: StringName, to_room: StringName)
signal arrived(room_id: StringName)
signal knocked(door_id: StringName)
signal waiting(door_id: StringName)
signal gave_up(room_id: StringName, reason: StringName)

enum State { IDLE, PLAN, APPROACH, SWING, CROSSING, AWAIT_KNOCK, WAIT, ARRIVED, FAILED }

@export var character_id: StringName = &""
## Seconds to walk from where it is to the next door.
@export var step_time: float = 1.0
@export var wait_retry: float = 3.0
@export var max_waits: int = 3
@export var max_knocks: int = 2
## -1: derive from role (servant: close all; family: close PRIVATE+; others: never).
@export var close_behind_min_privacy: int = -1
## §4.4: Tier 3 rooms run no per-agent logic.
@export var pause_in_abstract_tier: bool = true
## Wait for the body (notify_at_door / notify_crossed) instead of step_time.
@export var wait_for_body: bool = false

var state: State = State.IDLE
var goal: StringName = &""
var business: bool = false
var path: Array[StringName] = []
var current_door: StringName = &""
var blocked_door: StringName = &""
var _timer: float = 0.0
var _waits: int = 0
var _knocks: int = 0
var _last_response: StringName = &""
var _body_at_door: bool = false
var _body_crossed: bool = false
var _cross_from: StringName = &""
var _cross_to: StringName = &""
var _knock_next: bool = false


func _ready() -> void:
	RoomsAndDoors.ticked.connect(_on_ticked)
	RoomsAndDoors.knock_answered.connect(_on_knock_answered)


## business = it has a reason to be admitted (knocks rather than rerouting/waiting).
func go_to(room_id: StringName, has_business: bool = false) -> void:
	_release_reservation()
	goal = room_id
	business = has_business
	_waits = 0
	_knocks = 0
	blocked_door = &""
	state = State.PLAN


func cancel() -> void:
	_release_reservation()
	state = State.IDLE


func _exit_tree() -> void:
	_release_reservation()


func _release_reservation() -> void:
	if current_door != &"" and is_instance_valid(RoomsAndDoors.policy_controller):
		RoomsAndDoors.policy_controller.exit_threshold(current_door, character_id)


func notify_at_door() -> void:
	_body_at_door = true


func notify_crossed() -> void:
	_body_crossed = true


## The room the agent is heading into while crossing, else its current room.
func crossing_target() -> StringName:
	if state == State.CROSSING:
		return _cross_to
	return RoomsAndDoors.room_of(character_id)


func state_name() -> String:
	return State.keys()[state]


func _on_ticked(dt: float) -> void:
	if state in [State.IDLE, State.ARRIVED, State.FAILED]:
		return
	var here := RoomsAndDoors.room_of(character_id)
	if pause_in_abstract_tier and RoomsAndDoors.simulation_tier(here) >= RAD.Tier.ABSTRACT:
		return
	_timer -= dt
	match state:
		State.PLAN: _plan(here)
		State.APPROACH:
			if (wait_for_body and _body_at_door) or (not wait_for_body and _timer <= 0.0):
				_at_door(here)
		State.SWING: _await_swing(here)
		State.CROSSING:
			if _body_crossed:
				_complete_cross()
		State.WAIT:
			if _timer <= 0.0:
				state = State.PLAN


func _plan(here: StringName) -> void:
	if here == goal:
		state = State.ARRIVED
		arrived.emit(goal)
		return
	path = RoomsAndDoors.find_path(here, goal, character_id)
	if not path.is_empty():
		_begin_approach(path[0])
		return
	# No passable path. Walk the passable prefix of the graph route, then deal with
	# the door that stops us.
	var route := RoomsAndDoors.find_route(here, goal)
	if route.is_empty():
		_fail(&"no_route")
		return
	var room := here
	var prefix: Array[StringName] = []
	blocked_door = &""
	for d in route:
		# may_pass from `room`: emulate with a path query over a single door.
		var nxt := _other_side(d, room)
		if RoomsAndDoors.find_path(room, nxt, character_id).is_empty():
			blocked_door = d
			break
		prefix.append(d)
		room = nxt
	if not prefix.is_empty():
		path = prefix
		_begin_approach(path[0])
		return
	if business and _knocks < max_knocks:
		# Walk to the door first; knock on arrival (see _at_door).
		_knock_next = true
		_begin_approach(blocked_door)
		return
	if _waits < max_waits:
		_waits += 1
		state = State.WAIT
		_timer = wait_retry
		waiting.emit(blocked_door)
		return
	_fail(&"blocked")


func _begin_approach(door_id: StringName) -> void:
	current_door = door_id
	state = State.APPROACH
	_timer = step_time
	_body_at_door = false
	approaching.emit(door_id)


func _at_door(here: StringName) -> void:
	if _knock_next:
		_knock_next = false
		_knocks += 1
		state = State.AWAIT_KNOCK
		_last_response = &""
		var room := _other_side(blocked_door, here)
		if RoomsAndDoors.admission(character_id, room) == RAD.Admission.ON_DUTY 				or RoomsAndDoors.duty_remaining(character_id, room) > 0.0:
			RoomsAndDoors.announce(blocked_door, character_id, "on duty")
		else:
			RoomsAndDoors.knock(blocked_door, character_id)
		knocked.emit(blocked_door)
		return
	var policies := RoomsAndDoors.policy_controller as DoorPolicies
	if policies != null:
		var reservation := policies.reserve_threshold(current_door, character_id)
		if not bool(reservation["ok"]):
			state = State.WAIT
			_timer = wait_retry
			waiting.emit(current_door)
			return
	var check := RoomsAndDoors.may_pass(character_id, current_door)
	if not bool(check["ok"]):
		_release_reservation()
		state = State.PLAN
		return
	var d := RoomsAndDoors.get_door(current_door)
	if bool(d["locked"]):
		if not bool(RoomsAndDoors.try_unlock(current_door, character_id)["ok"]):
			_release_reservation()
			state = State.PLAN
			return
	if int(d["state"]) != RAD.DoorState.OPEN or bool(d.get("swinging", false)):
		var r: Dictionary
		if policies != null:
			r = policies.request_open(current_door, character_id, {"trigger": policies.trigger_for(current_door)})
		else:
			r = RoomsAndDoors.try_open(current_door, character_id)
		if not bool(r["ok"]):
			_release_reservation()
			state = State.WAIT
			_timer = wait_retry
			waiting.emit(current_door)
			return
	state = State.SWING
	_await_swing(here)


func _await_swing(here: StringName) -> void:
	var d := RoomsAndDoors.get_door(current_door)
	if d.is_empty():
		_release_reservation()
		state = State.PLAN
		return
	if int(d["state"]) != RAD.DoorState.OPEN:
		if not bool(d.get("swinging", false)):
			# Someone shut it on us; go back to the door.
			_begin_approach(current_door)
		return
	if bool(d.get("swinging", false)):
		return
	_cross_from = here
	_cross_to = _other_side(current_door, here)
	if is_instance_valid(RoomsAndDoors.policy_controller):
		RoomsAndDoors.policy_controller.enter_threshold(current_door, character_id)
	if wait_for_body:
		_body_crossed = false
		state = State.CROSSING
		cross_requested.emit(current_door, _cross_to)
		return
	_complete_cross()


func _complete_cross() -> void:
	var here := _cross_from
	var to := _cross_to
	RoomsAndDoors.set_occupant_room(character_id, to)
	_release_reservation()
	crossed.emit(current_door, to)
	if _should_close_behind(here, to):
		RoomsAndDoors.try_close(current_door, character_id)
	path.pop_front()
	if RoomsAndDoors.room_of(character_id) == goal:
		state = State.ARRIVED
		arrived.emit(goal)
	elif path.is_empty():
		state = State.PLAN
	else:
		_begin_approach(path[0])


func _on_knock_answered(door_id: StringName, actor_id: StringName, response: StringName, _owner: StringName) -> void:
	if actor_id != character_id or door_id != blocked_door or state != State.AWAIT_KNOCK:
		return
	_last_response = response
	match response:
		RAD.RESPONSE_COME_IN:
			state = State.PLAN
		RAD.RESPONSE_WAIT:
			state = State.WAIT
			_timer = maxf(wait_retry, 5.5)
		_:
			# Silence: nobody will let us in. Reroute later or give up.
			_knocks = max_knocks
			state = State.WAIT
			_timer = wait_retry


func _should_close_behind(from: StringName, to: StringName) -> bool:
	var min_p := close_behind_min_privacy
	if min_p < 0:
		match RoomsAndDoors.character_role(character_id):
			&"servant": min_p = RAD.Privacy.PUBLIC
			&"family": min_p = RAD.Privacy.PRIVATE
			_: return false
	var p := maxi(RoomsAndDoors.effective_privacy(from), RoomsAndDoors.effective_privacy(to))
	return p >= min_p


func _other_side(door_id: StringName, room_id: StringName) -> StringName:
	var d := RoomsAndDoors.get_door(door_id)
	return StringName(d["room_b"]) if StringName(d["room_a"]) == room_id else StringName(d["room_a"])


func _fail(reason: StringName) -> void:
	_release_reservation()
	state = State.FAILED
	gave_up.emit(goal, reason)
