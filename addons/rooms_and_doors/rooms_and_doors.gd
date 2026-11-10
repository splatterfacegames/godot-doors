extends Node
## RoomsAndDoors autoload: the single source of truth for rooms, doors, keys,
## admission, hearing/sight, knocking, residency tiers and content gating.
## See rooms-and-doors-system.md. No other script may own door/room state.
##
## Enums live in RAD (rad.gd). Results are Dictionaries:
##   Result      = { ok, reason, door }
##   PassCheck   = { ok, reason }
##   HearResult  = { heard, identified, participants, effective }
##   SightResult = { seen, level, activity, identities, peek_time }

const SAVE_VERSION := 1
const SETTING_DEBUG := "rooms_and_doors/debug/overlay"
const SETTING_FADE := "rooms_and_doors/content/fade_to_black"
const HOUSE_ACTOR := &"@house"
const MAX_LOG := 20

# --- Signals (past tense snake_case; `discovery` name is contractual) -----------------
signal room_registered(room_id: StringName)
signal door_registered(door_id: StringName)
signal character_registered(character_id: StringName)
signal door_state_changed(door_id: StringName, door: Dictionary)
signal door_used(door_id: StringName, actor_id: StringName, action: StringName, noise: float)
signal door_blocked(door_id: StringName)
signal door_forced(door_id: StringName, actor_id: StringName)
signal door_locked(door_id: StringName, actor_id: StringName)
signal door_unlocked(door_id: StringName, actor_id: StringName)
signal door_held(door_id: StringName, actor_id: StringName)
signal door_released(door_id: StringName, actor_id: StringName)
signal door_knocked(door_id: StringName, actor_id: StringName, room_id: StringName)
signal knock_answered(door_id: StringName, actor_id: StringName, response: StringName, owner_id: StringName)
signal door_clip_detected(character_id: StringName, from_room: StringName, to_room: StringName)
signal occupant_changed(character_id: StringName, from_room: StringName, to_room: StringName)
signal noise_emitted(door_id: StringName, rooms: Array, noise: float, kind: StringName)
signal noise_heard(listener_id: StringName, door_id: StringName, effective: float, kind: StringName)
signal character_woken(character_id: StringName, cause: StringName)
signal listening_started(character_id: StringName, door_id: StringName, room_id: StringName)
signal listening_stopped(character_id: StringName, door_id: StringName)
signal peeking_started(character_id: StringName, door_id: StringName)
signal peeking_stopped(character_id: StringName, door_id: StringName)
signal witness_gained(event_id: StringName, witness_id: StringName)
signal trespass_committed(character_id: StringName, room_id: StringName, entry: Dictionary)
signal discovery(discovered_id: StringName, finder_id: StringName, room_id: StringName, context: Dictionary)
signal ajar_discovered(door_id: StringName, finder_id: StringName)
signal key_granted(character_id: StringName, key_id: StringName)
signal key_revoked(character_id: StringName, key_id: StringName)
signal invitation_set(character_id: StringName, room_id: StringName, by_whom: StringName)
signal duty_set(character_id: StringName, room_id: StringName, window: Dictionary)
signal duty_lingered(character_id: StringName, room_id: StringName)
signal room_tier_changed(room_id: StringName, tier: int)
signal activity_started(activity_id: StringName, activity: Dictionary)
signal activity_finished(activity_id: StringName, activity: Dictionary)
signal activity_joined(activity_id: StringName, character_id: StringName, elapsed: float)
signal activity_overheard(activity_id: StringName, listener_id: StringName, hear: Dictionary)
signal fade_started(reason: StringName, payload: Dictionary)
signal fade_ended(reason: StringName, payload: Dictionary)
signal fade_rejected(reason: StringName)
signal scene_resolved(scene_id: StringName, room_id: StringName, mode: StringName, data: Dictionary)
signal state_loaded()
signal ticked(dt: float)
signal event_logged(text: String)

# --- Tunables (PER-GAME; set from game boot code) -----------------------------------
var hear_threshold: float = 0.08
var identify_threshold: float = 0.35
var listen_threshold_scale: float = 0.4
var sleep_threshold_scale: float = 2.5
var hearing_depth_cap: int = 3
var peek_identify_seconds: float = 2.5
var ajar_cone_half_angle_deg: float = 15.0
var ajar_cone_range: float = 15.0
var default_swing_time: float = 0.35
var intimate_auto_close_seconds: float = 4.0
var auto_close_intimate: bool = true
var knock_noise_scale: float = 1.2
var lock_noise_scale: float = 0.5
var trespass_knock_window: float = 30.0
var fade_default_duration: float = 2.0
var overhear_interval: float = 0.5
var discovery_interval: float = 0.5
var max_substep: float = 0.1
## Abstract tiers stop at this many doors.
var tier_cap: int = 3
## Clock: sim_time 0 == start_hour o'clock on day 0.
var start_hour: float = 9.0
var night_start_hour: float = 21.0
var dawn_hour: float = 6.0
var time_scale: float = 1.0
## Tests and turn-based games drive the clock with advance_time().
var manual_clock: bool = false
## Skip swing animations in state (tests). Door.tscn still animates.
var instant_doors: bool = false
## role -> { Privacy -> Admission } (§7.2).
var role_admission: Dictionary = {
	&"family": { RAD.Privacy.PUBLIC: RAD.Admission.RESIDENT, RAD.Privacy.HOUSEHOLD: RAD.Admission.RESIDENT, RAD.Privacy.FAMILY: RAD.Admission.RESIDENT },
	&"servant": { RAD.Privacy.PUBLIC: RAD.Admission.RESIDENT, RAD.Privacy.HOUSEHOLD: RAD.Admission.ON_DUTY },
	&"guest": { RAD.Privacy.PUBLIC: RAD.Admission.RESIDENT },
}
## Optional override: func(room: Dictionary, ctx: Dictionary) -> int (Privacy).
var privacy_rule: Callable = Callable()
var default_knock_policy: KnockPolicy = KnockPolicy.new()

# --- State ----------------------------------------------------------------------------
var sim_time: float = 0.0
var _rooms: Dictionary = {}          # room_id -> room record (+ residents)
var _doors: Dictionary = {}          # door_id -> door record (+ lock_side, jammed, blocked, ...)
var _door_nodes: Dictionary = {}     # door_id -> Node (view), not saved
var _room_doors: Dictionary = {}     # room_id -> Array of door ids
var _chars: Dictionary = {}          # character_id -> character record
var _body_to_char: Dictionary = {}   # instance_id -> character_id
var _keyrings: Dictionary = {}       # character_id -> Array of key ids
var _master_keys: Dictionary = {}    # key_id -> Array of key ids it substitutes for
var _invitations: Dictionary = {}    # character_id -> { room_id -> {by, expires_at, until_exit} }
var _duties: Dictionary = {}         # character_id -> { room_id -> {start, end, expected, key_access, lingered} }
var _pass_grants: Dictionary = {}    # character_id -> { door_id -> expires_at }
var _trespass_log: Array = []
var _knock_policies: Dictionary = {} # owner_id -> KnockPolicy
var _pending_knocks: Array = []
var _knock_cooldown: Dictionary = {} # "actor|door" -> time
var _last_knock: Dictionary = {}     # character_id -> {door, time}
var _pending_swings: Dictionary = {} # door_id -> {due, target, actor}
var _activities: Dictionary = {}     # activity_id -> activity record
var _scenes: Dictionary = {}         # scene_id -> requires
var _discovered: Dictionary = {}     # "a|b|room" -> true
var _witnessed: Dictionary = {}      # event_id -> { witness -> true }
var _tiers: Dictionary = {}
var _player_id: StringName = &""
var _fade: Dictionary = { "active": false }
var _pending_door_state: Dictionary = {}
var _event_log: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _since_overhear: float = 0.0
var _since_discovery: float = 0.0
var _overlay: Node = null
## Optional DoorPolicies controller; physical state remains in this autoload.
var policy_controller: Node = null
var policy_state: Dictionary = {}
var _local_players: Array[StringName] = []
var _door_blockers: Dictionary = {}
var _activity_seq: int = 0


func _ready() -> void:
	_rng.seed = 0x600D_D005
	if not ProjectSettings.has_setting(SETTING_FADE):
		ProjectSettings.set_setting(SETTING_FADE, false)
	if not ProjectSettings.has_setting(SETTING_DEBUG):
		ProjectSettings.set_setting(SETTING_DEBUG, false)
	if bool(ProjectSettings.get_setting(SETTING_DEBUG, false)):
		set_debug_overlay(true)


func _process(delta: float) -> void:
	if not manual_clock:
		advance_time(delta * time_scale)


# ======================================================================================
# Registration
# ======================================================================================

func register_room(cfg: Dictionary) -> void:
	var id := StringName(cfg.get("id", ""))
	if id == &"":
		push_error("RoomsAndDoors.register_room: missing id")
		return
	var existing: Dictionary = _rooms.get(id, {})
	var occupants: Array = existing.get("occupants", [])
	var rec := {
		"id": id,
		"display_name": String(cfg.get("display_name", String(id))),
		"privacy": int(cfg.get("privacy", RAD.Privacy.PUBLIC)),
		"owner_id": StringName(cfg.get("owner_id", "")),
		"ambient_noise": float(cfg.get("ambient_noise", 0.0)),
		"residents": _to_sn_array(cfg.get("residents", [])),
		"occupants": occupants,
	}
	_rooms[id] = rec
	if not _room_doors.has(id):
		_room_doors[id] = []
	_emit(&"room_registered", [id])
	_recompute_tiers()


func register_door(cfg: Dictionary) -> void:
	var id := StringName(cfg.get("id", ""))
	if id == &"":
		push_error("RoomsAndDoors.register_door: missing id")
		return
	var a := StringName(cfg.get("room_a", ""))
	var b := StringName(cfg.get("room_b", ""))
	if a == &"":
		a = RAD.OUTSIDE
	if b == &"":
		b = RAD.OUTSIDE
	for r in [a, b]:
		if not _rooms.has(r):
			register_room({ "id": r, "privacy": RAD.Privacy.PUBLIC })
	var rec: Dictionary
	if _doors.has(id):
		# Re-registration (scene reload): keep runtime state, refresh static config.
		rec = _doors[id]
		_unlink_door(id)
	else:
		rec = {
			"id": id,
			"state": int(cfg.get("state", RAD.DoorState.CLOSED)),
			"locked": bool(cfg.get("locked", false)),
			"held_by": &"",
			"blocked": false,
			"ajar_left_by": &"",
			"auto_close_at": -1.0,
			"sound_level": float(cfg.get("sound_level", 0.5)),
		}
	rec["room_a"] = a
	rec["room_b"] = b
	rec["key_id"] = StringName(cfg.get("key_id", ""))
	rec["lock_side"] = StringName(cfg.get("lock_side", ""))
	rec["hearing_factor"] = float(cfg.get("hearing_factor", 0.3))
	rec["sight_factor"] = float(cfg.get("sight_factor", 0.0))
	rec["ajar_hearing_bonus"] = float(cfg.get("ajar_hearing_bonus", 0.6))
	rec["swing_time"] = float(cfg.get("swing_time", default_swing_time))
	rec["jammed"] = bool(cfg.get("jammed", rec.get("jammed", false)))
	_doors[id] = rec
	(_room_doors[a] as Array).append(id)
	(_room_doors[b] as Array).append(id)
	if _pending_door_state.has(id):
		_apply_saved_door(rec, _pending_door_state[id])
		_pending_door_state.erase(id)
	_emit(&"door_registered", [id])
	_recompute_tiers()
	_notify_door(id)


func bind_door_node(door_id: StringName, node: Node) -> void:
	_door_nodes[door_id] = node


func register_character(character_id: StringName, body: Node, opts: Dictionary = {}) -> void:
	var rec: Dictionary = _chars.get(character_id, {
		"id": character_id, "room": &"", "last_room": &"", "role": &"",
		"sleeping": false, "hear_threshold_scale": 1.0,
		"posture": RAD.Posture.NORMAL, "posture_door": &"", "posture_since": 0.0,
		"entered_at": 0.0,
	})
	rec["body"] = body
	if opts.has("role"):
		rec["role"] = StringName(opts["role"])
	if opts.has("sleeping"):
		rec["sleeping"] = bool(opts["sleeping"])
	if opts.has("hear_threshold_scale"):
		rec["hear_threshold_scale"] = float(opts["hear_threshold_scale"])
	_chars[character_id] = rec
	if body != null:
		_body_to_char[body.get_instance_id()] = character_id
		body.set_meta(&"character_id", character_id)
	if not _keyrings.has(character_id):
		_keyrings[character_id] = []
	_emit(&"character_registered", [character_id])
	if opts.has("room"):
		set_occupant_room(character_id, StringName(opts["room"]), true)


func character_id_for_body(body: Node) -> StringName:
	if body == null:
		return &""
	if _body_to_char.has(body.get_instance_id()):
		return _body_to_char[body.get_instance_id()]
	if body.has_meta(&"character_id"):
		return StringName(body.get_meta(&"character_id"))
	return &""


func set_character_role(character_id: StringName, role: StringName) -> void:
	_char(character_id)["role"] = role


func character_role(character_id: StringName) -> StringName:
	return StringName(_chars.get(character_id, {}).get("role", &""))


func set_sleeping(character_id: StringName, sleeping: bool) -> void:
	var c := _char(character_id)
	var was: bool = c.get("sleeping", false)
	c["sleeping"] = sleeping
	if was and not sleeping:
		_emit(&"character_woken", [character_id, &"script"])
		_check_discoveries()


func is_sleeping(character_id: StringName) -> bool:
	return bool(_chars.get(character_id, {}).get("sleeping", false))


func set_player(character_id: StringName) -> void:
	_player_id = character_id
	_recompute_tiers()


func register_local_player(character_id: StringName) -> void:
	if not _local_players.has(character_id):
		_local_players.append(character_id)
	_recompute_tiers()


func character_body(character_id: StringName) -> Node:
	return _chars.get(character_id, {}).get("body") as Node


func door_view(door_id: StringName) -> Node:
	return _door_nodes.get(door_id) as Node


func is_authoritative() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Trusted server gameplay policy operations; never exposed as client RPCs.
func set_policy_door_state(id: StringName, state: int, locked: bool) -> void:
	if not is_authoritative() or not _doors.has(id):
		return
	_pending_swings.erase(id)
	_doors[id]["locked"] = locked
	_set_state(id, state)
	_notify_door(id)


func set_policy_key(id: StringName, key_id: StringName) -> void:
	if is_authoritative() and _doors.has(id):
		_doors[id]["key_id"] = key_id
		_notify_door(id)


func get_player() -> StringName:
	return _player_id


func register_key(key_id: StringName, opens: Array = []) -> void:
	_master_keys[key_id] = _to_sn_array(opens)


func set_knock_policy(owner_id: StringName, policy: KnockPolicy) -> void:
	_knock_policies[owner_id] = policy


func register_scene(scene_id: StringName, requires: Dictionary) -> void:
	_scenes[scene_id] = requires.duplicate(true)


# ======================================================================================
# Occupancy
# ======================================================================================

## `teleport` = zone load / scripted relocation; skips the door-clip check.
func set_occupant_room(character_id: StringName, room_id: StringName, teleport: bool = false) -> void:
	if not is_authoritative():
		return
	var c := _char(character_id)
	var from: StringName = c.get("room", &"")
	if from == room_id:
		return
	if not teleport and from != &"" and room_id != &"" and is_instance_valid(policy_controller):
		if not policy_controller.authorize_room_entry(character_id, from, room_id):
			return
	if room_id != &"" and not _rooms.has(room_id):
		register_room({ "id": room_id })
	var last: StringName = c.get("last_room", &"")
	if not teleport and room_id != &"" and last != &"" and last != room_id:
		if not _has_open_door_between(last, room_id):
			_emit(&"door_clip_detected", [character_id, last, room_id])
	if from != &"" and _rooms.has(from):
		(_rooms[from]["occupants"] as Array).erase(character_id)
		_expire_until_exit_invitations(character_id, from)
	c["room"] = room_id
	if room_id != &"":
		c["last_room"] = room_id
		c["entered_at"] = sim_time
		(_rooms[room_id]["occupants"] as Array).append(character_id)
	if int(c.get("posture", RAD.Posture.NORMAL)) != RAD.Posture.NORMAL:
		_end_posture(character_id)
	_clear_discoveries_for(character_id)
	_emit(&"occupant_changed", [character_id, from, room_id])
	if room_id != &"":
		_check_trespass(character_id, room_id)
		_join_activities(character_id, room_id)
	if character_id == _player_id or _local_players.has(character_id):
		_recompute_tiers()
	_evaluate_activities()
	_check_discoveries()


func room_of(character_id: StringName) -> StringName:
	return StringName(_chars.get(character_id, {}).get("room", &""))


func occupants(room_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _rooms.has(room_id):
		for o in _rooms[room_id]["occupants"]:
			out.append(o)
	return out


func is_alone(character_id: StringName) -> bool:
	var r := room_of(character_id)
	return r != &"" and occupants(r).size() == 1


func others_present(character_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for o in occupants(room_of(character_id)):
		if o != character_id:
			out.append(o)
	return out


func rooms_adjacent(room_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _room_doors.get(room_id, []):
		var other := _other_side(d, room_id)
		if not out.has(other):
			out.append(other)
	return out


func doors_of_room(room_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _room_doors.get(room_id, []):
		out.append(d)
	return out


func doors_between(a: StringName, b: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _room_doors.get(a, []):
		if _other_side(d, a) == b:
			out.append(d)
	return out


func get_room(room_id: StringName) -> Dictionary:
	return (_rooms.get(room_id, {}) as Dictionary).duplicate(true)


func room_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in _rooms:
		out.append(r)
	return out


func door_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _doors:
		out.append(d)
	return out


func character_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in _chars:
		out.append(c)
	return out


func effective_privacy(room_id: StringName, ctx: Dictionary = {}) -> int:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty():
		return RAD.Privacy.PUBLIC
	var c := ctx.duplicate()
	if not c.has("night"):
		c["night"] = is_night()
	if privacy_rule.is_valid():
		return int(privacy_rule.call(room, c))
	var p: int = room["privacy"]
	# Shipped default (§4.1): PRIVATE -> INTIMATE at night when occupied.
	if p == RAD.Privacy.PRIVATE and bool(c["night"]) and (room["occupants"] as Array).size() > 0:
		return RAD.Privacy.INTIMATE
	return p


# ======================================================================================
# Doors
# ======================================================================================

func get_door(door_id: StringName) -> Dictionary:
	if not _doors.has(door_id):
		return {}
	return _public_door(_doors[door_id])


func try_open(door_id: StringName, actor_id: StringName, opts: Dictionary = {}) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	if is_instance_valid(policy_controller):
		var policy_check: Dictionary = policy_controller.check_open(door_id, actor_id, opts)
		if not bool(policy_check.get("ok", false)):
			return policy_check
	var d: Dictionary = _doors[door_id]
	var force: bool = opts.get("force", false)
	if int(d["state"]) == RAD.DoorState.OPEN and not _pending_swings.has(door_id):
		return RAD.result(true, RAD.OK, get_door(door_id))
	# A proximity trigger may request opening every frame. Preserve the original
	# completion time instead of restarting the same swing indefinitely.
	if _pending_swings.has(door_id) and int(_pending_swings[door_id]["target"]) == RAD.DoorState.OPEN:
		return RAD.result(true, RAD.OK, get_door(door_id))
	if bool(d["jammed"]) and not force:
		return RAD.result(false, RAD.JAMMED, get_door(door_id))
	if bool(d["locked"]) and not force:
		return RAD.result(false, RAD.LOCKED, get_door(door_id))
	var target := _far_side(door_id, actor_id)
	if not force and _rooms.has(target) and int(_rooms[target]["privacy"]) == RAD.Privacy.SEALED \
			and admission(actor_id, target) == RAD.Admission.NONE:
		return RAD.result(false, RAD.TRESPASS_DENIED, get_door(door_id))
	if force:
		d["locked"] = false
		d["jammed"] = false
		_emit(&"door_forced", [door_id, actor_id])
	var instant: bool = opts.get("instant", instant_doors)
	# §10: opening an AJAR door someone else left is a suspicion hook.
	if int(d["state"]) == RAD.DoorState.AJAR and not _pending_swings.has(door_id) 			and actor_id != HOUSE_ACTOR and StringName(d["ajar_left_by"]) not in [&"", actor_id]:
		_emit(&"ajar_discovered", [door_id, actor_id])
	_pending_swings.erase(door_id)
	_set_state(door_id, RAD.DoorState.AJAR)
	_use(door_id, actor_id, &"open", opts)
	if instant or float(d["swing_time"]) <= 0.0:
		_set_state(door_id, RAD.DoorState.OPEN)
	else:
		_pending_swings[door_id] = { "due": sim_time + float(d["swing_time"]), "target": RAD.DoorState.OPEN, "actor": actor_id }
	return RAD.result(true, RAD.OK, get_door(door_id))


func try_close(door_id: StringName, actor_id: StringName, opts: Dictionary = {}) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if is_instance_valid(policy_controller) and not policy_controller.can_close(door_id):
		return RAD.result(false, &"open_only")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	var holder: StringName = d["held_by"]
	if holder != &"" and holder != actor_id:
		return RAD.result(false, RAD.HELD, get_door(door_id))
	if bool(d["jammed"]) and not bool(opts.get("force", false)):
		return RAD.result(false, RAD.JAMMED, get_door(door_id))
	if int(d["state"]) == RAD.DoorState.CLOSED and not _pending_swings.has(door_id):
		return RAD.result(true, RAD.OK, get_door(door_id))
	if holder == actor_id:
		release_hold(door_id, actor_id)
	_pending_swings.erase(door_id)
	if bool(d["blocked"]):
		_set_state(door_id, RAD.DoorState.AJAR)
		_emit(&"door_blocked", [door_id])
		return RAD.result(false, RAD.BLOCKED, get_door(door_id))
	_use(door_id, actor_id, &"close", opts)
	var instant: bool = opts.get("instant", instant_doors)
	if instant or float(d["swing_time"]) <= 0.0:
		_finish_close(door_id)
	else:
		_set_state(door_id, RAD.DoorState.AJAR)
		_pending_swings[door_id] = { "due": sim_time + float(d["swing_time"]), "target": RAD.DoorState.CLOSED, "actor": actor_id }
	var after: Dictionary = get_door(door_id)
	if bool(d["blocked"]):
		return RAD.result(false, RAD.BLOCKED, after)
	return RAD.result(true, RAD.OK, after)


func set_ajar(door_id: StringName, actor_id: StringName, opts: Dictionary = {}) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if is_instance_valid(policy_controller) and not policy_controller.can_close(door_id):
		return RAD.result(false, &"open_only")
	if is_instance_valid(policy_controller):
		var check: Dictionary = policy_controller.check_open(door_id, actor_id, opts)
		if not bool(check.get("ok", false)):
			return check
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	var holder: StringName = d["held_by"]
	if holder != &"" and holder != actor_id:
		return RAD.result(false, RAD.HELD, get_door(door_id))
	if bool(d["locked"]):
		return RAD.result(false, RAD.LOCKED, get_door(door_id))
	if bool(d["jammed"]):
		return RAD.result(false, RAD.JAMMED, get_door(door_id))
	_pending_swings.erase(door_id)
	d["ajar_left_by"] = actor_id
	_use(door_id, actor_id, &"ajar", opts)
	_set_state(door_id, RAD.DoorState.AJAR)
	return RAD.result(true, RAD.OK, get_door(door_id))


func try_lock(door_id: StringName, actor_id: StringName) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	if bool(d["locked"]):
		return RAD.result(true, RAD.OK, get_door(door_id))
	if int(d["state"]) != RAD.DoorState.CLOSED or _pending_swings.has(door_id):
		return RAD.result(false, RAD.BLOCKED, get_door(door_id))
	if not _can_operate_lock(actor_id, door_id, room_of(actor_id)):
		return RAD.result(false, RAD.NO_KEY, get_door(door_id))
	d["locked"] = true
	_use(door_id, actor_id, &"lock", { "scale": lock_noise_scale })
	_emit(&"door_locked", [door_id, actor_id])
	_notify_door(door_id)
	return RAD.result(true, RAD.OK, get_door(door_id))


func try_unlock(door_id: StringName, actor_id: StringName) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if is_instance_valid(policy_controller) and not policy_controller.can_unlock(door_id):
		return RAD.result(false, &"sealed")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	if not bool(d["locked"]):
		return RAD.result(true, RAD.OK, get_door(door_id))
	if not _can_operate_lock(actor_id, door_id, room_of(actor_id)):
		var reason := RAD.NO_KEY if StringName(d["key_id"]) != &"" else RAD.LOCKED
		return RAD.result(false, reason, get_door(door_id))
	_unlock_internal(door_id, actor_id)
	return RAD.result(true, RAD.OK, get_door(door_id))


func hold_open(door_id: StringName, actor_id: StringName) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	var holder: StringName = d["held_by"]
	if holder != &"" and holder != actor_id:
		return RAD.result(false, RAD.HELD, get_door(door_id))
	if int(d["state"]) != RAD.DoorState.OPEN or _pending_swings.has(door_id):
		var r := try_open(door_id, actor_id, { "instant": true })
		if not bool(r["ok"]):
			return r
	d["held_by"] = actor_id
	d["auto_close_at"] = -1.0
	_emit(&"door_held", [door_id, actor_id])
	_notify_door(door_id)
	return RAD.result(true, RAD.OK, get_door(door_id))


func release_hold(door_id: StringName, actor_id: StringName) -> Dictionary:
	if not is_authoritative():
		return RAD.result(false, &"server_authority")
	if not _doors.has(door_id):
		return RAD.result(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	if StringName(d["held_by"]) != actor_id:
		return RAD.result(false, RAD.HELD, get_door(door_id))
	d["held_by"] = &""
	_schedule_auto_close(door_id)
	_emit(&"door_released", [door_id, actor_id])
	_notify_door(door_id)
	return RAD.result(true, RAD.OK, get_door(door_id))


## Door view reports bodies in the swing (§6.1). Never lets a close complete into a body.
func set_door_blocked(door_id: StringName, blocked: bool, source: StringName = &"view") -> void:
	if not is_authoritative() or not _doors.has(door_id):
		return
	if not _door_blockers.has(door_id):
		_door_blockers[door_id] = {}
	if blocked:
		_door_blockers[door_id][source] = true
	else:
		(_door_blockers[door_id] as Dictionary).erase(source)
	blocked = not (_door_blockers[door_id] as Dictionary).is_empty()
	_doors[door_id]["blocked"] = blocked
	if blocked and _pending_swings.has(door_id) and int(_pending_swings[door_id]["target"]) == RAD.DoorState.CLOSED:
		_pending_swings.erase(door_id)
		_set_state(door_id, RAD.DoorState.AJAR)
		_emit(&"door_blocked", [door_id])
	if not blocked:
		_notify_door(door_id)


func set_door_jammed(door_id: StringName, jammed: bool) -> void:
	if not is_authoritative():
		return
	if _doors.has(door_id):
		_doors[door_id]["jammed"] = jammed
		_notify_door(door_id)


## PER-GAME hook: oiling / maintenance.
func set_door_sound_level(door_id: StringName, level: float) -> void:
	if not is_authoritative():
		return
	if _doors.has(door_id):
		_doors[door_id]["sound_level"] = maxf(0.0, level)


func door_noise(door_id: StringName, opts: Dictionary = {}) -> float:
	var d: Dictionary = _doors.get(door_id, {})
	if d.is_empty():
		return 0.0
	var n: float = float(d["sound_level"]) * (0.25 if bool(opts.get("quiet", false)) else 1.0) \
			* (3.0 if bool(opts.get("force", false)) else 1.0)
	return n * float(opts.get("scale", 1.0))


# ======================================================================================
# Keys, admission, duty
# ======================================================================================

func has_key(character_id: StringName, key_id: StringName) -> bool:
	if key_id == &"":
		return false
	for k in _keyrings.get(character_id, []):
		if k == key_id:
			return true
		if (_master_keys.get(k, []) as Array).has(key_id):
			return true
	return false


func grant_key(character_id: StringName, key_id: StringName) -> void:
	if not is_authoritative():
		return
	if not _keyrings.has(character_id):
		_keyrings[character_id] = []
	var ring: Array = _keyrings[character_id]
	if not ring.has(key_id):
		ring.append(key_id)
		_emit(&"key_granted", [character_id, key_id])


func revoke_key(character_id: StringName, key_id: StringName) -> void:
	if not is_authoritative():
		return
	var ring: Array = _keyrings.get(character_id, [])
	if ring.has(key_id):
		ring.erase(key_id)
		_emit(&"key_revoked", [character_id, key_id])


func keyring(character_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _keyrings.get(character_id, []):
		out.append(k)
	return out


## Pure: may this character pass this door from their current room right now?
## ok = true means passable, possibly after unlocking with a key they hold.
func may_pass(character_id: StringName, door_id: StringName) -> Dictionary:
	return _may_pass_from(character_id, door_id, room_of(character_id))


## Pure route/group planning check without moving the character first.
func may_pass_from(character_id: StringName, door_id: StringName, from_room: StringName) -> Dictionary:
	return _may_pass_from(character_id, door_id, from_room)


func admission(character_id: StringName, room_id: StringName) -> int:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty() or character_id == &"":
		return RAD.Admission.NONE
	if StringName(room["owner_id"]) == character_id or (room["residents"] as Array).has(character_id):
		return RAD.Admission.RESIDENT
	var role: StringName = _chars.get(character_id, {}).get("role", &"")
	var by_role: int = int((role_admission.get(role, {}) as Dictionary).get(int(room["privacy"]), RAD.Admission.NONE))
	if by_role == RAD.Admission.RESIDENT:
		return RAD.Admission.RESIDENT
	if _invitation_active(character_id, room_id):
		return RAD.Admission.INVITED
	if by_role == RAD.Admission.ON_DUTY:
		return RAD.Admission.ON_DUTY
	if _duty_admits(character_id, room_id):
		return RAD.Admission.ON_DUTY
	return RAD.Admission.NONE


## opts: { expires_at: float (sim time, <0 = never), until_exit: bool }.
## Default expiry: next dawn (§7.2).
func set_invitation(character_id: StringName, room_id: StringName, by_whom: StringName, opts: Dictionary = {}) -> void:
	if not is_authoritative():
		return
	if not _invitations.has(character_id):
		_invitations[character_id] = {}
	_invitations[character_id][room_id] = {
		"by": by_whom,
		"expires_at": float(opts.get("expires_at", next_dawn_time())),
		"until_exit": bool(opts.get("until_exit", false)),
	}
	_emit(&"invitation_set", [character_id, room_id, by_whom])
	_check_discoveries()


func clear_invitation(character_id: StringName, room_id: StringName) -> void:
	if not is_authoritative():
		return
	if _invitations.has(character_id):
		(_invitations[character_id] as Dictionary).erase(room_id)


## window: { start (default now), end | duration, expected (default end-start),
## key_access (default true: may pass locked doors of this room during the window) }.
func set_duty(character_id: StringName, room_id: StringName, window: Dictionary) -> void:
	if not is_authoritative():
		return
	var start: float = float(window.get("start", sim_time))
	var end: float = float(window.get("end", start + float(window.get("duration", 600.0))))
	var rec := {
		"start": start, "end": end,
		"expected": float(window.get("expected", end - start)),
		"key_access": bool(window.get("key_access", true)),
		"lingered": false,
	}
	if not _duties.has(character_id):
		_duties[character_id] = {}
	_duties[character_id][room_id] = rec
	_emit(&"duty_set", [character_id, room_id, rec.duplicate()])


func clear_duty(character_id: StringName, room_id: StringName) -> void:
	if not is_authoritative():
		return
	if _duties.has(character_id):
		(_duties[character_id] as Dictionary).erase(room_id)


func duty_remaining(character_id: StringName, room_id: StringName) -> float:
	var duty: Dictionary = (_duties.get(character_id, {}) as Dictionary).get(room_id, {})
	if duty.is_empty() or sim_time < float(duty["start"]):
		return 0.0
	return maxf(0.0, float(duty["end"]) - sim_time)


# ======================================================================================
# Hearing, sight, witnesses (§8)
# ======================================================================================

func hear_check(listener_id: StringName, source_room: StringName, loudness: float, participants: Array = []) -> Dictionary:
	var parts: Array[StringName] = []
	if participants.is_empty():
		for o in occupants(source_room):
			if o != listener_id:
				parts.append(o)
	else:
		for p in participants:
			parts.append(StringName(p))
	var res := { "heard": false, "identified": false, "participants": [], "effective": 0.0 }
	var c: Dictionary = _chars.get(listener_id, {})
	var lroom: StringName = c.get("room", &"")
	if c.is_empty() or lroom == &"" or not _rooms.has(source_room):
		return res
	var sleeping: bool = c.get("sleeping", false)
	var scale: float = float(c.get("hear_threshold_scale", 1.0)) * (sleep_threshold_scale if sleeping else 1.0)
	var ambient: float = float(_rooms[lroom]["ambient_noise"])
	var path := _sound_path(source_room, lroom)
	if path.is_empty():
		return res
	var factor: float = path["factor"]
	var effective: float = loudness * factor - ambient
	res["effective"] = effective
	if int(path["hops_closed"]) == 0 and not sleeping:
		# Same acoustic space (same room or joined by OPEN doors): presence, not hearing.
		res["heard"] = true
		res["identified"] = true
		res["participants"] = parts
		return res
	var listening := int(c.get("posture", RAD.Posture.NORMAL)) == RAD.Posture.LISTEN \
			and StringName(c.get("posture_door", &"")) == StringName(path["arrival_door"]) \
			and int(_doors.get(path["arrival_door"], {}).get("state", RAD.DoorState.OPEN)) != RAD.DoorState.OPEN
	if listening:
		scale *= listen_threshold_scale
	if effective > hear_threshold * scale:
		res["heard"] = true
		res["identified"] = listening or effective > identify_threshold * scale
		if res["identified"]:
			res["participants"] = parts
	return res


func sight_check(viewer_id: StringName, target_room: StringName, through_door_id: StringName) -> Dictionary:
	var res := { "seen": false, "level": RAD.SIGHT_NONE, "activity": &"", "identities": [], "peek_time": 0.0 }
	var d: Dictionary = _doors.get(through_door_id, {})
	var c: Dictionary = _chars.get(viewer_id, {})
	if d.is_empty() or c.is_empty():
		return res
	var vroom: StringName = c["room"]
	if not ((d["room_a"] == vroom and d["room_b"] == target_room) or (d["room_b"] == vroom and d["room_a"] == target_room)):
		return res
	var inside := occupants(target_room)
	match int(d["state"]):
		RAD.DoorState.OPEN:
			res["seen"] = true
			res["level"] = RAD.SIGHT_FULL
			res["identities"] = inside
			res["activity"] = activity_class_in(target_room)
		RAD.DoorState.AJAR:
			var in_cone := _ajar_cone(through_door_id, target_room, inside)
			res["level"] = RAD.SIGHT_PARTIAL
			res["identities"] = in_cone
			res["seen"] = not in_cone.is_empty()
			if res["seen"]:
				res["activity"] = activity_class_in(target_room)
		RAD.DoorState.CLOSED:
			var peeking := int(c.get("posture", RAD.Posture.NORMAL)) == RAD.Posture.PEEK \
					and StringName(c.get("posture_door", &"")) == through_door_id
			if float(d["sight_factor"]) > 0.0 and peeking:
				var t: float = sim_time - float(c["posture_since"])
				res["seen"] = true
				res["level"] = RAD.SIGHT_GLIMPSE
				res["activity"] = activity_class_in(target_room)
				res["peek_time"] = t
				if t > peek_identify_seconds:
					res["identities"] = inside
	return res


## All characters who perceive an event of `loudness` in `room_id`: occupants of
## the acoustic space (awake) plus everyone for whom hear_check succeeds.
## Pass `event_id` to emit witness_gained (deduplicated per event).
func witnesses_of(room_id: StringName, loudness: float, event_id: StringName = &"", participants: Array = []) -> Array[StringName]:
	var out: Array[StringName] = []
	for cid in _chars:
		if StringName(_chars[cid]["room"]) == &"":
			continue
		var h := hear_check(cid, room_id, loudness, participants)
		if bool(h["heard"]):
			out.append(cid)
	if event_id != &"":
		if not _witnessed.has(event_id):
			_witnessed[event_id] = {}
		for w in out:
			if not (_witnessed[event_id] as Dictionary).has(w):
				_witnessed[event_id][w] = true
				_emit(&"witness_gained", [event_id, w])
	return out


## Convenience form of §4.3 `can_witness`. event: { loudness, id, participants }.
func can_witness(event_room: StringName, event: Dictionary) -> Array[StringName]:
	return witnesses_of(event_room, float(event.get("loudness", RAD.LOUD_CONVERSATION)),
			StringName(event.get("id", "")), event.get("participants", []))


func start_listening(character_id: StringName, door_id: StringName) -> bool:
	return _begin_posture(character_id, door_id, RAD.Posture.LISTEN)


func stop_listening(character_id: StringName) -> void:
	if int(_char(character_id).get("posture", 0)) == RAD.Posture.LISTEN:
		_end_posture(character_id)


func start_peeking(character_id: StringName, door_id: StringName) -> bool:
	return _begin_posture(character_id, door_id, RAD.Posture.PEEK)


func stop_peeking(character_id: StringName) -> void:
	if int(_char(character_id).get("posture", 0)) == RAD.Posture.PEEK:
		_end_posture(character_id)


func posture_of(character_id: StringName) -> int:
	return int(_chars.get(character_id, {}).get("posture", RAD.Posture.NORMAL))


# ======================================================================================
# Knocking (§9)
# ======================================================================================

func knock(door_id: StringName, actor_id: StringName, opts: Dictionary = {}) -> void:
	if not is_authoritative():
		return
	if not _doors.has(door_id):
		return
	var target := _far_side(door_id, actor_id)
	var announce: bool = opts.get("announce", false)
	_last_knock[actor_id] = { "door": door_id, "room": target, "time": sim_time }
	_emit(&"door_knocked", [door_id, actor_id, target])
	_use(door_id, actor_id, &"announce" if announce else &"knock", { "scale": knock_noise_scale })
	var key := "%s|%s" % [actor_id, door_id]
	if sim_time < float(_knock_cooldown.get(key, -1.0)):
		return
	for p in _pending_knocks:
		if p["actor"] == actor_id and p["door"] == door_id:
			return
	var owner: StringName = _rooms.get(target, {}).get("owner_id", &"")
	var policy: KnockPolicy = _knock_policies.get(owner, default_knock_policy)
	_pending_knocks.append({
		"due": sim_time + policy.pick_delay(_rng),
		"door": door_id, "actor": actor_id, "room": target, "owner": owner,
		"announce": announce, "errand": String(opts.get("errand", "")),
	})


## Servant announcement: name + errand, counts as a knock (§9).
func announce(door_id: StringName, actor_id: StringName, errand: String = "") -> void:
	knock(door_id, actor_id, { "announce": true, "errand": errand })


func has_pass_grant(character_id: StringName, door_id: StringName) -> bool:
	return sim_time <= float((_pass_grants.get(character_id, {}) as Dictionary).get(door_id, -1.0))


# ======================================================================================
# Pathing (§4.3, §10)
# ======================================================================================

func path_exists(from: StringName, to: StringName, for_character: StringName) -> bool:
	return from == to or not find_path(from, to, for_character).is_empty()


## BFS over doors the character may pass. Returns door ids in order, [] if none.
func find_path(from: StringName, to: StringName, for_character: StringName, exclude_doors: Array = []) -> Array[StringName]:
	var empty: Array[StringName] = []
	if from == to or not _rooms.has(from) or not _rooms.has(to):
		return empty
	var prev: Dictionary = { from: [&"", &""] }
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var r: StringName = queue.pop_front()
		for d in _room_doors.get(r, []):
			if exclude_doors.has(d):
				continue
			var nxt := _other_side(d, r)
			if prev.has(nxt):
				continue
			if not bool(_may_pass_from(for_character, d, r)["ok"]):
				continue
			prev[nxt] = [r, d]
			if nxt == to:
				var path: Array[StringName] = []
				var cur := to
				while cur != from:
					path.push_front(prev[cur][1])
					cur = prev[cur][0]
				return path
			queue.append(nxt)
	return empty


## Graph route ignoring passability (for "who is in the way" decisions).
func find_route(from: StringName, to: StringName) -> Array[StringName]:
	return find_path(from, to, &"@any")


# ======================================================================================
# Residency (§4.4)
# ======================================================================================

func simulation_tier(room_id: StringName) -> int:
	return int(_tiers.get(room_id, RAD.Tier.PLAYER))


func resident_rooms() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in _rooms:
		if simulation_tier(r) <= RAD.Tier.ADJACENT:
			out.append(r)
	return out


# ======================================================================================
# Activities: conversations and private scenes that run at every tier
# ======================================================================================

## cfg: { id?, room, participants, loudness, duration, activity_class, scene_id? }.
func start_activity(cfg: Dictionary) -> StringName:
	_activity_seq += 1
	var id := StringName(cfg.get("id", "activity_%d" % _activity_seq))
	var act := {
		"id": id,
		"room": StringName(cfg.get("room", "")),
		"participants": _to_sn_array(cfg.get("participants", [])),
		"loudness": float(cfg.get("loudness", RAD.LOUD_CONVERSATION)),
		"start": float(cfg.get("start", sim_time)),
		"duration": float(cfg.get("duration", 60.0)),
		"activity_class": StringName(cfg.get("activity_class", "conversation")),
		"scene_id": StringName(cfg.get("scene_id", "")),
		"active": true,
		"heard": {},
		"joined": [],
	}
	_activities[id] = act
	_emit(&"activity_started", [id, act.duplicate(true)])
	_evaluate_activity(act)
	return id


func activity_state(activity_id: StringName) -> Dictionary:
	var act: Dictionary = _activities.get(activity_id, {})
	if act.is_empty():
		return {}
	var elapsed: float = minf(sim_time - float(act["start"]), float(act["duration"]))
	var out := act.duplicate(true)
	out["elapsed"] = elapsed
	out["remaining"] = float(act["duration"]) - elapsed
	out["progress"] = elapsed / maxf(0.0001, float(act["duration"]))
	out["tier"] = simulation_tier(act["room"])
	return out


func stop_activity(activity_id: StringName) -> void:
	var act: Dictionary = _activities.get(activity_id, {})
	if not act.is_empty() and bool(act["active"]):
		_finish_activity(act)


func activity_class_in(room_id: StringName) -> StringName:
	for id in _activities:
		var a: Dictionary = _activities[id]
		if bool(a["active"]) and a["room"] == room_id:
			return a["activity_class"]
	return &"occupied" if not occupants(room_id).is_empty() else &"empty"


func active_activities(room_id: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _activities:
		var a: Dictionary = _activities[id]
		if bool(a["active"]) and (room_id == &"" or a["room"] == room_id):
			out.append(id)
	return out


# ======================================================================================
# Content hooks (§11)
# ======================================================================================

func request_fade_to_black(reason: StringName, payload: Dictionary = {}) -> void:
	if bool(_fade["active"]):
		_emit(&"fade_rejected", [reason])
		return
	_fade = {
		"active": true, "reason": reason, "payload": payload.duplicate(true),
		"ends_at": sim_time + float(payload.get("duration", fade_default_duration)),
	}
	_emit(&"fade_started", [reason, payload])


func end_fade() -> void:
	if bool(_fade["active"]):
		var reason: StringName = _fade["reason"]
		var payload: Dictionary = _fade["payload"]
		_fade = { "active": false }
		_emit(&"fade_ended", [reason, payload])


func is_fading() -> bool:
	return bool(_fade["active"])


## requires keys: door_state (DoorState, all doors of room), locked (bool, all doors),
## room_privacy_min (Privacy, effective). Returns { ok, unmet: Array[Dictionary] }.
func scene_preconditions_met(scene_id: StringName, room_id: StringName) -> Dictionary:
	var unmet: Array = []
	if not _scenes.has(scene_id):
		unmet.append({ "key": "scene", "expected": "registered", "actual": "unknown" })
		return { "ok": false, "unmet": unmet }
	if not _rooms.has(room_id):
		unmet.append({ "key": "room", "expected": "registered", "actual": "unknown" })
		return { "ok": false, "unmet": unmet }
	var req: Dictionary = _scenes[scene_id]
	if req.has("door_state"):
		for d in doors_of_room(room_id):
			var st := int(_doors[d]["state"])
			if _pending_swings.has(d):
				st = RAD.DoorState.AJAR
			if st != int(req["door_state"]):
				unmet.append({ "key": "door_state", "door": d, "expected": RAD.door_state_name(int(req["door_state"])), "actual": RAD.door_state_name(st) })
	if req.has("locked"):
		for d in doors_of_room(room_id):
			if bool(_doors[d]["locked"]) != bool(req["locked"]):
				unmet.append({ "key": "locked", "door": d, "expected": bool(req["locked"]), "actual": bool(_doors[d]["locked"]) })
	if req.has("room_privacy_min"):
		var p := effective_privacy(room_id)
		if p < int(req["room_privacy_min"]):
			unmet.append({ "key": "room_privacy_min", "expected": RAD.privacy_name(int(req["room_privacy_min"])), "actual": RAD.privacy_name(p) })
	return { "ok": unmet.is_empty(), "unmet": unmet }


## Resolves a restricted scene. Fade builds (ProjectSettings rooms_and_doors/content/fade_to_black)
## fade and emit summary state; full builds emit mode "full" for the game to play the scene.
## payload: { participants, loudness, summary, duration }.
func request_scene(scene_id: StringName, room_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var pre := scene_preconditions_met(scene_id, room_id)
	if not bool(pre["ok"]):
		return { "ok": false, "mode": &"", "unmet": pre["unmet"] }
	var parts: Array = payload.get("participants", [])
	var loud: float = float(payload.get("loudness", RAD.LOUD_CONVERSATION))
	var witnesses: Array[StringName] = []
	for w in witnesses_of(room_id, loud, scene_id, parts):
		if not parts.has(w):
			witnesses.append(w)
	var states := {}
	for d in doors_of_room(room_id):
		states[d] = { "state": RAD.door_state_name(int(_doors[d]["state"])), "locked": bool(_doors[d]["locked"]) }
	var data := {
		"privacy": effective_privacy(room_id),
		"witnesses": witnesses,
		"witness_count": witnesses.size(),
		"doors": states,
		"summary": payload.get("summary", {}),
		"time": sim_time,
	}
	var mode := &"fade" if bool(ProjectSettings.get_setting(SETTING_FADE, false)) else &"full"
	if mode == &"fade":
		request_fade_to_black(scene_id, payload)
	_emit(&"scene_resolved", [scene_id, room_id, mode, data])
	return { "ok": true, "mode": mode, "unmet": [], "data": data }


# ======================================================================================
# Clock
# ======================================================================================

func advance_time(dt: float) -> void:
	if not is_authoritative():
		return
	var left := dt
	while left > 0.0:
		var step := minf(left, max_substep)
		left -= step
		sim_time += step
		_tick(step)


func clock_hour() -> float:
	return fposmod(start_hour + sim_time / 3600.0, 24.0)


func is_night() -> bool:
	var h := clock_hour()
	return h >= night_start_hour or h < dawn_hour


func set_clock_hour(hour: float) -> void:
	sim_time += fposmod(hour - clock_hour(), 24.0) * 3600.0


func next_dawn_time() -> float:
	var h := clock_hour()
	var until := fposmod(dawn_hour - h, 24.0)
	if until <= 0.0:
		until = 24.0
	return sim_time + until * 3600.0


# ======================================================================================
# Save / load (§12)
# ======================================================================================

func save_state() -> Dictionary:
	var doors := {}
	for id in _doors:
		var d: Dictionary = _doors[id]
		var st := int(d["state"])
		if _pending_swings.has(id):
			st = int(_pending_swings[id]["target"])
		doors[String(id)] = {
			"state": st, "locked": d["locked"], "held_by": String(d["held_by"]),
			"sound_level": d["sound_level"], "jammed": d["jammed"],
			"ajar_left_by": String(d["ajar_left_by"]), "auto_close_at": d["auto_close_at"],
		}
	var chars := {}
	for id in _chars:
		var c: Dictionary = _chars[id]
		chars[String(id)] = {
			"room": String(c["room"]), "last_room": String(c["last_room"]), "role": String(c["role"]),
			"sleeping": c["sleeping"], "hear_threshold_scale": c["hear_threshold_scale"],
			"entered_at": c["entered_at"],
		}
	var acts := {}
	for id in _activities:
		var a: Dictionary = _activities[id]
		acts[String(id)] = {
			"room": String(a["room"]), "participants": _to_str_array(a["participants"]),
			"loudness": a["loudness"], "start": a["start"], "duration": a["duration"],
			"activity_class": String(a["activity_class"]), "scene_id": String(a["scene_id"]),
			"active": a["active"], "heard": _str_keys(a["heard"]), "joined": _to_str_array(a["joined"]),
		}
	return {
		"version": SAVE_VERSION,
		"policies": _nested_str(policy_state),
		"local_players": _to_str_array(_local_players),
		"sim_time": sim_time,
		"player": String(_player_id),
		"doors": doors,
		"characters": chars,
		"keyrings": _nested_str(_keyrings),
		"master_keys": _nested_str(_master_keys),
		"invitations": _nested_str(_invitations),
		"duties": _nested_str(_duties),
		"pass_grants": _nested_str(_pass_grants),
		"trespass_log": _trespass_log.duplicate(true),
		"knock_cooldown": _knock_cooldown.duplicate(),
		"activities": acts,
		"activity_seq": _activity_seq,
		"fade": _fade.duplicate(true) if not bool(_fade["active"]) else {
			"active": true, "reason": String(_fade["reason"]), "payload": _fade["payload"], "ends_at": _fade["ends_at"] },
	}


## Tolerates missing keys and JSON round-trips (strings for StringNames, floats for ints).
## Doors not yet registered receive their state when they register.
func load_state(data: Dictionary) -> void:
	_door_blockers.clear()
	policy_state = (data.get("policies", {}) as Dictionary).duplicate(true)
	_local_players.clear()
	for player in data.get("local_players", []):
		_local_players.append(StringName(player))
	var version := int(data.get("version", SAVE_VERSION))
	if version > SAVE_VERSION:
		push_warning("RoomsAndDoors.load_state: save version %d newer than %d" % [version, SAVE_VERSION])
	# (Migrations go here when SAVE_VERSION is bumped.)
	sim_time = float(data.get("sim_time", sim_time))
	_player_id = StringName(data.get("player", String(_player_id)))
	_pending_swings.clear()
	_pending_knocks.clear()
	_discovered.clear()
	for id in data.get("doors", {}):
		var sd: Dictionary = data["doors"][id]
		var sid := StringName(id)
		if _doors.has(sid):
			_apply_saved_door(_doors[sid], sd)
		else:
			_pending_door_state[sid] = sd
	for r in _rooms:
		(_rooms[r]["occupants"] as Array).clear()
	for cid in _chars:
		_chars[cid]["room"] = &""
	for id in data.get("characters", {}):
		var sc: Dictionary = data["characters"][id]
		var cid := StringName(id)
		var c := _char(cid)
		c["role"] = StringName(sc.get("role", String(c["role"])))
		c["sleeping"] = bool(sc.get("sleeping", false))
		c["hear_threshold_scale"] = float(sc.get("hear_threshold_scale", 1.0))
		c["posture"] = RAD.Posture.NORMAL
		c["posture_door"] = &""
		var room := StringName(sc.get("room", ""))
		c["room"] = room
		c["last_room"] = StringName(sc.get("last_room", String(room)))
		c["entered_at"] = float(sc.get("entered_at", sim_time))
		if room != &"":
			if not _rooms.has(room):
				register_room({ "id": room })
			(_rooms[room]["occupants"] as Array).append(cid)
	_keyrings = _load_sn_lists(data.get("keyrings", {}))
	if data.has("master_keys"):
		var mk := _load_sn_lists(data["master_keys"])
		for k in mk:
			_master_keys[k] = mk[k]
	_invitations = _load_nested(data.get("invitations", {}), ["by"])
	_duties = _load_nested(data.get("duties", {}), [])
	_pass_grants = _load_nested(data.get("pass_grants", {}), [])
	_trespass_log = (data.get("trespass_log", []) as Array).duplicate(true)
	_knock_cooldown = (data.get("knock_cooldown", {}) as Dictionary).duplicate()
	_activities.clear()
	for id in data.get("activities", {}):
		var sa: Dictionary = data["activities"][id]
		var heard := {}
		for k in sa.get("heard", {}):
			heard[StringName(k)] = bool(sa["heard"][k])
		_activities[StringName(id)] = {
			"id": StringName(id), "room": StringName(sa.get("room", "")),
			"participants": _to_sn_array(sa.get("participants", [])),
			"loudness": float(sa.get("loudness", RAD.LOUD_CONVERSATION)),
			"start": float(sa.get("start", sim_time)), "duration": float(sa.get("duration", 60.0)),
			"activity_class": StringName(sa.get("activity_class", "conversation")),
			"scene_id": StringName(sa.get("scene_id", "")), "active": bool(sa.get("active", true)),
			"heard": heard, "joined": _to_sn_array(sa.get("joined", [])),
		}
	_activity_seq = int(data.get("activity_seq", _activity_seq))
	var f: Dictionary = data.get("fade", { "active": false })
	if bool(f.get("active", false)):
		_fade = { "active": true, "reason": StringName(f.get("reason", "")), "payload": f.get("payload", {}), "ends_at": float(f.get("ends_at", sim_time)) }
	else:
		_fade = { "active": false }
	_recompute_tiers()
	for d in _doors:
		_notify_door(d)
	_emit(&"state_loaded", [])


## Simulates quitting: forget everything, including registrations.
func reset() -> void:
	sim_time = 0.0
	policy_state.clear()
	_local_players.clear()
	_door_blockers.clear()
	for coll in [_rooms, _doors, _door_nodes, _room_doors, _chars, _body_to_char, _keyrings,
			_master_keys, _invitations, _duties, _pass_grants, _knock_policies, _knock_cooldown,
			_last_knock, _pending_swings, _activities, _scenes, _discovered, _witnessed, _tiers,
			_pending_door_state]:
		(coll as Dictionary).clear()
	_trespass_log.clear()
	_pending_knocks.clear()
	_event_log.clear()
	_player_id = &""
	_fade = { "active": false }
	_activity_seq = 0


func trespass_log() -> Array:
	return _trespass_log.duplicate(true)


func event_log() -> Array[String]:
	return _event_log.duplicate()


# ======================================================================================
# Debug
# ======================================================================================

func set_debug_overlay(on: bool) -> void:
	if on and _overlay == null:
		_overlay = preload("res://addons/rooms_and_doors/debug_overlay.gd").new()
		add_child(_overlay)
	elif not on and _overlay != null:
		_overlay.queue_free()
		_overlay = null


func toggle_debug_overlay() -> void:
	set_debug_overlay(_overlay == null)


# ======================================================================================
# Internals
# ======================================================================================

func _tick(dt: float) -> void:
	# Door swings.
	for id in _pending_swings.keys():
		var sw: Dictionary = _pending_swings[id]
		if sim_time >= float(sw["due"]):
			_pending_swings.erase(id)
			if int(sw["target"]) == RAD.DoorState.OPEN:
				_set_state(id, RAD.DoorState.OPEN)
			else:
				_finish_close(id)
	# Auto-close (§6.1).
	for id in _doors:
		var d: Dictionary = _doors[id]
		var at: float = d["auto_close_at"]
		if at >= 0.0 and sim_time >= at:
			d["auto_close_at"] = -1.0
			if StringName(d["held_by"]) == &"" and int(d["state"]) != RAD.DoorState.CLOSED:
				try_close(id, HOUSE_ACTOR, { "quiet": true })
	# Knock responses.
	var due: Array = []
	for p in _pending_knocks:
		if sim_time >= float(p["due"]):
			due.append(p)
	for p in due:
		_pending_knocks.erase(p)
		_resolve_knock(p)
	# Fade.
	if bool(_fade["active"]) and sim_time >= float(_fade["ends_at"]):
		end_fade()
	# Activities: finish on schedule at every tier.
	for id in _activities:
		var a: Dictionary = _activities[id]
		if bool(a["active"]) and sim_time >= float(a["start"]) + float(a["duration"]):
			_finish_activity(a)
	_since_overhear += dt
	if _since_overhear >= overhear_interval:
		_since_overhear = 0.0
		_evaluate_activities()
	_since_discovery += dt
	if _since_discovery >= discovery_interval:
		_since_discovery = 0.0
		_check_lingering()
		_check_discoveries()
	_emit_quiet(&"ticked", [dt])


func _resolve_knock(p: Dictionary) -> void:
	var door_id: StringName = p["door"]
	var actor: StringName = p["actor"]
	var room: StringName = p["room"]
	var owner: StringName = p["owner"]
	var policy: KnockPolicy = _knock_policies.get(owner, default_knock_policy)
	var adm := admission(actor, room)
	var ctx := {
		"owner_present": owner != &"" and room_of(owner) == room,
		"owner_asleep": owner != &"" and is_sleeping(owner),
		"admission": adm,
		"announce": p["announce"],
		"announce_on_duty": adm == RAD.Admission.ON_DUTY or _duty_window_active(actor, room),
		"hour": clock_hour(),
	}
	var response := policy.decide(ctx)
	if response == RAD.RESPONSE_COME_IN:
		if _doors.has(door_id) and bool(_doors[door_id]["locked"]):
			_unlock_internal(door_id, owner)
		if not _pass_grants.has(actor):
			_pass_grants[actor] = {}
		_pass_grants[actor][door_id] = sim_time + policy.come_in_pass_seconds
		if adm < RAD.Admission.INVITED and adm != RAD.Admission.ON_DUTY:
			set_invitation(actor, room, owner, { "expires_at": -1.0, "until_exit": true })
	elif response == RAD.RESPONSE_WAIT:
		_knock_cooldown["%s|%s" % [actor, door_id]] = sim_time + policy.wait_retry_seconds
	_emit(&"knock_answered", [door_id, actor, response, owner])


func _may_pass_from(character_id: StringName, door_id: StringName, from_room: StringName) -> Dictionary:
	if is_instance_valid(policy_controller):
		var check: Dictionary = policy_controller.check_pass(door_id, character_id, {"from_room": from_room})
		if not bool(check.get("ok", false)):
			return check
	if not _doors.has(door_id):
		return RAD.pass_check(false, RAD.NO_SUCH_DOOR)
	var d: Dictionary = _doors[door_id]
	if character_id == &"@any":
		return RAD.pass_check(true, RAD.OK)
	var to_room := _other_side(door_id, from_room) if from_room in [d["room_a"], d["room_b"]] else StringName(d["room_b"])
	if bool(d["jammed"]) and int(d["state"]) != RAD.DoorState.OPEN:
		return RAD.pass_check(false, RAD.JAMMED)
	if _rooms.has(to_room) and int(_rooms[to_room]["privacy"]) == RAD.Privacy.SEALED \
			and admission(character_id, to_room) == RAD.Admission.NONE:
		return RAD.pass_check(false, RAD.TRESPASS_DENIED)
	if bool(d["locked"]) and not _can_operate_lock(character_id, door_id, from_room):
		return RAD.pass_check(false, RAD.NO_KEY if StringName(d["key_id"]) != &"" else RAD.LOCKED)
	return RAD.pass_check(true, RAD.OK)


func _can_operate_lock(character_id: StringName, door_id: StringName, from_room: StringName) -> bool:
	var d: Dictionary = _doors[door_id]
	var key: StringName = d["key_id"]
	var side: StringName = d["lock_side"]
	if key == &"" and side == &"":
		return false
	if key != &"" and has_key(character_id, key):
		return true
	if side != &"" and from_room == side:
		return true
	if has_pass_grant(character_id, door_id):
		return true
	# Chore key access (§7.3): into the duty room, or out of it to a non-private room.
	var to_room := _other_side(door_id, from_room) if from_room in [d["room_a"], d["room_b"]] else StringName(d["room_b"])
	if _duty_key_access(character_id, to_room):
		return true
	if from_room in [d["room_a"], d["room_b"]] and _duty_key_access(character_id, from_room) 			and effective_privacy(to_room) < RAD.Privacy.PRIVATE:
		return true
	return false


func _duty_key_access(character_id: StringName, room_id: StringName) -> bool:
	var duty: Dictionary = (_duties.get(character_id, {}) as Dictionary).get(room_id, {})
	return not duty.is_empty() and bool(duty["key_access"]) and _duty_window_active(character_id, room_id)


func _duty_window_active(character_id: StringName, room_id: StringName) -> bool:
	var duty: Dictionary = (_duties.get(character_id, {}) as Dictionary).get(room_id, {})
	return not duty.is_empty() and sim_time >= float(duty["start"]) and sim_time <= float(duty["end"])


func _duty_admits(character_id: StringName, room_id: StringName) -> bool:
	if not _duty_window_active(character_id, room_id):
		return false
	var duty: Dictionary = _duties[character_id][room_id]
	if bool(duty["lingered"]):
		return false
	if room_of(character_id) == room_id:
		var inside: float = sim_time - float(_chars[character_id]["entered_at"])
		if inside > 2.0 * float(duty["expected"]):
			return false
	return true


func _check_lingering() -> void:
	for cid in _duties:
		var r := room_of(cid)
		var duty: Dictionary = (_duties[cid] as Dictionary).get(r, {})
		if duty.is_empty() or bool(duty["lingered"]) or not _duty_window_active(cid, r):
			continue
		if sim_time - float(_chars[cid]["entered_at"]) > 2.0 * float(duty["expected"]):
			duty["lingered"] = true
			_emit(&"duty_lingered", [cid, r])


func _invitation_active(character_id: StringName, room_id: StringName) -> bool:
	var inv: Dictionary = (_invitations.get(character_id, {}) as Dictionary).get(room_id, {})
	if inv.is_empty():
		return false
	var exp: float = inv["expires_at"]
	return exp < 0.0 or sim_time <= exp


func _expire_until_exit_invitations(character_id: StringName, room_id: StringName) -> void:
	var inv: Dictionary = (_invitations.get(character_id, {}) as Dictionary).get(room_id, {})
	if not inv.is_empty() and bool(inv["until_exit"]):
		(_invitations[character_id] as Dictionary).erase(room_id)


func _check_trespass(character_id: StringName, room_id: StringName) -> void:
	if effective_privacy(room_id) < RAD.Privacy.PRIVATE:
		return
	if admission(character_id, room_id) != RAD.Admission.NONE:
		return
	var lk: Dictionary = _last_knock.get(character_id, {})
	var knocked: bool = not lk.is_empty() and lk["room"] == room_id and sim_time - float(lk["time"]) <= trespass_knock_window
	var entry := {
		"character": String(character_id), "room": String(room_id), "time": sim_time,
		"knocked": knocked, "privacy": effective_privacy(room_id), "doors": _door_context(room_id),
	}
	_trespass_log.append(entry)
	_emit(&"trespass_committed", [character_id, room_id, entry])


func _check_discoveries() -> void:
	for room_id in _rooms:
		var occ: Array = _rooms[room_id]["occupants"]
		if occ.is_empty() or effective_privacy(room_id) < RAD.Privacy.PRIVATE:
			continue
		var suspects: Array = []
		for a in occ:
			if admission(a, room_id) == RAD.Admission.NONE:
				suspects.append(a)
		if suspects.is_empty():
			continue
		var space := _visual_space(room_id)
		for a in suspects:
			for r in space:
				for b in _rooms[r]["occupants"]:
					if b == a or is_sleeping(b):
						continue
					var key := "%s|%s|%s" % [a, b, room_id]
					if _discovered.has(key):
						continue
					_discovered[key] = true
					var ctx := {
						"privacy": effective_privacy(room_id),
						"admission": RAD.Admission.NONE,
						"finder_room": String(r),
						"via": "same_room" if r == room_id else "open_door",
						"doors": _door_context(room_id),
						"time": sim_time,
						"night": is_night(),
					}
					_emit(&"discovery", [a, b, room_id, ctx])


func _clear_discoveries_for(character_id: StringName) -> void:
	var prefix := String(character_id) + "|"
	var mid := "|" + String(character_id) + "|"
	for k in _discovered.keys():
		var s: String = k
		if s.begins_with(prefix) or s.contains(mid):
			_discovered.erase(k)


func _door_context(room_id: StringName) -> Dictionary:
	var out := {}
	for d in doors_of_room(room_id):
		out[String(d)] = {
			"state": String(RAD.door_state_name(int(_doors[d]["state"]))),
			"locked": bool(_doors[d]["locked"]),
			"held_by": String(_doors[d]["held_by"]),
		}
	return out


## Rooms joined to room_id by OPEN doors (transitively).
func _visual_space(room_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = [room_id]
	var i := 0
	while i < out.size():
		for d in _room_doors.get(out[i], []):
			if int(_doors[d]["state"]) == RAD.DoorState.OPEN:
				var o := _other_side(d, out[i])
				if not out.has(o):
					out.append(o)
		i += 1
	return out


## Shortest door path (cap hearing_depth_cap); among equal-length paths, the loudest.
## Returns {factor, hops_closed, arrival_door} or {} if unreachable.
func _sound_path(from: StringName, to: StringName) -> Dictionary:
	if from == to:
		return { "factor": 1.0, "hops_closed": 0, "arrival_door": &"" }
	var best := { from: { "factor": 1.0, "closed": 0, "door": &"" } }
	var frontier: Array[StringName] = [from]
	for depth in range(hearing_depth_cap):
		var layer := {}
		for r in frontier:
			var cur: Dictionary = best[r]
			for d in _room_doors.get(r, []):
				var nxt := _other_side(d, r)
				if best.has(nxt):
					continue
				var f: float = float(cur["factor"]) * _door_hearing(d)
				var closed: int = int(cur["closed"]) + (0 if int(_doors[d]["state"]) == RAD.DoorState.OPEN else 1)
				if not layer.has(nxt) or f > float(layer[nxt]["factor"]):
					layer[nxt] = { "factor": f, "closed": closed, "door": d }
		if layer.is_empty():
			break
		frontier = []
		for k in layer:
			best[k] = layer[k]
			frontier.append(k)
		if layer.has(to):
			var hit: Dictionary = layer[to]
			return { "factor": hit["factor"], "hops_closed": hit["closed"], "arrival_door": hit["door"] }
	return {}


func _door_hearing(door_id: StringName) -> float:
	var d: Dictionary = _doors[door_id]
	match int(d["state"]):
		RAD.DoorState.OPEN: return 1.0
		RAD.DoorState.AJAR: return minf(1.0, float(d["hearing_factor"]) + float(d["ajar_hearing_bonus"]))
	return float(d["hearing_factor"])


func _ajar_cone(door_id: StringName, target_room: StringName, inside: Array[StringName]) -> Array[StringName]:
	var node: Node3D = _door_nodes.get(door_id) as Node3D
	var out: Array[StringName] = []
	if node == null or not node.is_inside_tree():
		# No spatial data (abstract door): the gap shows whoever is in the room.
		return inside.duplicate()
	var axis: Vector3 = node.global_basis.z.normalized()
	if StringName(_doors[door_id]["room_a"]) == target_room:
		axis = -axis
	var origin := node.global_position
	var cos_half := cos(deg_to_rad(ajar_cone_half_angle_deg))
	for cid in inside:
		var body: Node3D = _chars.get(cid, {}).get("body") as Node3D
		if body == null or not body.is_inside_tree():
			continue
		var to_body := body.global_position - origin
		to_body.y = 0.0
		var dist := to_body.length()
		if dist < 0.01 or dist > ajar_cone_range:
			continue
		var flat_axis := Vector3(axis.x, 0.0, axis.z).normalized()
		if to_body.normalized().dot(flat_axis) >= cos_half and _clear_line(origin, body):
			out.append(cid)
	return out


func _clear_line(origin: Vector3, body: Node3D) -> bool:
	var world := body.get_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(origin + Vector3.UP, body.global_position + Vector3.UP)
	var exclude: Array[RID] = []
	if body is CollisionObject3D:
		exclude.append((body as CollisionObject3D).get_rid())
	for n in _door_nodes.values():
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	q.exclude = exclude
	return space.intersect_ray(q).is_empty()


func _begin_posture(character_id: StringName, door_id: StringName, posture: int) -> bool:
	var c := _char(character_id)
	if not _doors.has(door_id):
		return false
	var d: Dictionary = _doors[door_id]
	var room: StringName = c["room"]
	if room != d["room_a"] and room != d["room_b"]:
		return false
	if int(c["posture"]) != RAD.Posture.NORMAL:
		_end_posture(character_id)
	c["posture"] = posture
	c["posture_door"] = door_id
	c["posture_since"] = sim_time
	if posture == RAD.Posture.LISTEN:
		_emit(&"listening_started", [character_id, door_id, room])
	else:
		_emit(&"peeking_started", [character_id, door_id])
	_evaluate_activities()
	return true


func _end_posture(character_id: StringName) -> void:
	var c := _char(character_id)
	var p := int(c["posture"])
	var door: StringName = c["posture_door"]
	c["posture"] = RAD.Posture.NORMAL
	c["posture_door"] = &""
	if p == RAD.Posture.LISTEN:
		_emit(&"listening_stopped", [character_id, door])
	elif p == RAD.Posture.PEEK:
		_emit(&"peeking_stopped", [character_id, door])


func _use(door_id: StringName, actor_id: StringName, action: StringName, opts: Dictionary) -> void:
	var noise := door_noise(door_id, opts)
	_emit(&"door_used", [door_id, actor_id, action, noise])
	_emit_noise(door_id, actor_id, noise, action)


func _emit_noise(door_id: StringName, actor_id: StringName, noise: float, kind: StringName) -> void:
	var d: Dictionary = _doors[door_id]
	var rooms := [d["room_a"], d["room_b"]]
	_emit(&"noise_emitted", [door_id, rooms, noise, kind])
	if noise <= 0.0:
		return
	for cid in _chars:
		if cid == actor_id or StringName(_chars[cid]["room"]) == &"":
			continue
		var best: Dictionary = {}
		for r in rooms:
			var h := _hear_noise(cid, r, noise)
			if best.is_empty() or float(h["effective"]) > float(best["effective"]) or (bool(h["heard"]) and not bool(best["heard"])):
				best = h
		if bool(best["heard"]):
			_emit(&"noise_heard", [cid, door_id, best["effective"], kind])
			if is_sleeping(cid):
				_chars[cid]["sleeping"] = false
				_emit(&"character_woken", [cid, kind])
				_check_discoveries()


## Noise is not "presence": even same-room listeners use thresholds.
func _hear_noise(listener_id: StringName, source_room: StringName, loudness: float) -> Dictionary:
	var c: Dictionary = _chars[listener_id]
	var lroom: StringName = c["room"]
	var path := _sound_path(source_room, lroom)
	if path.is_empty():
		return { "heard": false, "effective": -1.0 }
	var scale: float = float(c["hear_threshold_scale"]) * (sleep_threshold_scale if bool(c["sleeping"]) else 1.0)
	var eff: float = loudness * float(path["factor"]) - float(_rooms[lroom]["ambient_noise"])
	return { "heard": eff > hear_threshold * scale, "effective": eff }


func _set_state(door_id: StringName, state: int) -> void:
	var d: Dictionary = _doors[door_id]
	if int(d["state"]) == state:
		return
	d["state"] = state
	if state == RAD.DoorState.CLOSED:
		d["auto_close_at"] = -1.0
		d["ajar_left_by"] = &""
	else:
		_schedule_auto_close(door_id)
	_notify_door(door_id)
	_evaluate_activities()
	_check_discoveries()


func _finish_close(door_id: StringName) -> void:
	if bool(_doors[door_id]["blocked"]):
		_set_state(door_id, RAD.DoorState.AJAR)
		_emit(&"door_blocked", [door_id])
	else:
		_set_state(door_id, RAD.DoorState.CLOSED)


func _schedule_auto_close(door_id: StringName) -> void:
	var d: Dictionary = _doors[door_id]
	if not auto_close_intimate or StringName(d["held_by"]) != &"" or int(d["state"]) == RAD.DoorState.CLOSED:
		return
	var intimate := false
	for r in [d["room_a"], d["room_b"]]:
		if effective_privacy(r) == RAD.Privacy.INTIMATE:
			intimate = true
	if intimate and float(d["auto_close_at"]) < 0.0:
		d["auto_close_at"] = sim_time + intimate_auto_close_seconds


func _unlock_internal(door_id: StringName, actor_id: StringName) -> void:
	_doors[door_id]["locked"] = false
	_use(door_id, actor_id, &"unlock", { "scale": lock_noise_scale })
	_emit(&"door_unlocked", [door_id, actor_id])
	_notify_door(door_id)


func _apply_saved_door(rec: Dictionary, sd: Dictionary) -> void:
	rec["state"] = int(sd.get("state", rec["state"]))
	rec["locked"] = bool(sd.get("locked", rec["locked"]))
	rec["held_by"] = StringName(sd.get("held_by", ""))
	rec["sound_level"] = float(sd.get("sound_level", rec["sound_level"]))
	rec["jammed"] = bool(sd.get("jammed", rec.get("jammed", false)))
	rec["ajar_left_by"] = StringName(sd.get("ajar_left_by", ""))
	rec["auto_close_at"] = float(sd.get("auto_close_at", -1.0))
	rec["blocked"] = false


func _notify_door(door_id: StringName) -> void:
	_emit_quiet(&"door_state_changed", [door_id, get_door(door_id)])


func _public_door(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["swinging"] = _pending_swings.has(d["id"])
	return out


func _other_side(door_id: StringName, room_id: StringName) -> StringName:
	var d: Dictionary = _doors[door_id]
	return StringName(d["room_b"]) if StringName(d["room_a"]) == room_id else StringName(d["room_a"])


func _far_side(door_id: StringName, actor_id: StringName) -> StringName:
	var d: Dictionary = _doors[door_id]
	var r := room_of(actor_id)
	if r == d["room_a"]:
		return d["room_b"]
	if r == d["room_b"]:
		return d["room_a"]
	return d["room_b"]


func _has_open_door_between(a: StringName, b: StringName) -> bool:
	for d in doors_between(a, b):
		if int(_doors[d]["state"]) == RAD.DoorState.OPEN:
			return true
	return false


func _unlink_door(door_id: StringName) -> void:
	for r in _room_doors:
		(_room_doors[r] as Array).erase(door_id)


func _recompute_tiers() -> void:
	var dist := {}
	var origin := room_of(_player_id) if _player_id != &"" else &""
	var origins: Array[StringName] = []
	if origin != &"":
		origins.append(origin)
	for actor in _local_players:
		var player_room := room_of(actor)
		if player_room != &"" and not origins.has(player_room):
			origins.append(player_room)
	if not origins.is_empty():
		var queue: Array[StringName] = []
		for player_room in origins:
			if _rooms.has(player_room):
				dist[player_room] = 0
				queue.append(player_room)
		while not queue.is_empty():
			var r: StringName = queue.pop_front()
			if int(dist[r]) >= tier_cap:
				continue
			for d in _room_doors.get(r, []):
				var o := _other_side(d, r)
				if not dist.has(o):
					dist[o] = int(dist[r]) + 1
					queue.append(o)
	for r in _rooms:
		var t: int = RAD.Tier.PLAYER
		if not origins.is_empty():
			t = mini(int(dist.get(r, tier_cap)), tier_cap)
		if int(_tiers.get(r, -1)) != t:
			_tiers[r] = t
			_emit(&"room_tier_changed", [r, t])


func _join_activities(character_id: StringName, room_id: StringName) -> void:
	for id in _activities:
		var a: Dictionary = _activities[id]
		if not bool(a["active"]) or a["room"] != room_id:
			continue
		if (a["participants"] as Array).has(character_id) or (a["joined"] as Array).has(character_id):
			continue
		(a["joined"] as Array).append(character_id)
		_emit(&"activity_joined", [id, character_id, sim_time - float(a["start"])])


func _evaluate_activities() -> void:
	for id in _activities:
		var a: Dictionary = _activities[id]
		if bool(a["active"]):
			_evaluate_activity(a)


## Tiers 0-2 resolve listeners; Tier 3 is abstract (clock only) per §4.4.
func _evaluate_activity(a: Dictionary) -> void:
	if simulation_tier(a["room"]) >= RAD.Tier.ABSTRACT:
		return
	var parts: Array = a["participants"]
	for cid in _chars:
		if parts.has(cid) or StringName(_chars[cid]["room"]) == &"":
			continue
		var h := hear_check(cid, a["room"], float(a["loudness"]), parts)
		if not bool(h["heard"]):
			continue
		var prev = (a["heard"] as Dictionary).get(cid)
		if prev == null or (bool(h["identified"]) and not bool(prev)):
			a["heard"][cid] = bool(h["identified"])
			if prev == null:
				if not _witnessed.has(a["id"]):
					_witnessed[a["id"]] = {}
				_witnessed[a["id"]][cid] = true
				_emit(&"witness_gained", [a["id"], cid])
			_emit(&"activity_overheard", [a["id"], cid, h])


func _finish_activity(a: Dictionary) -> void:
	a["active"] = false
	var out := a.duplicate(true)
	out["finished_at"] = float(a["start"]) + float(a["duration"])
	_emit(&"activity_finished", [a["id"], out])


func _char(character_id: StringName) -> Dictionary:
	if not _chars.has(character_id):
		register_character(character_id, null)
	return _chars[character_id]


func _emit(sig: StringName, args: Array) -> void:
	_log("%7.2f %s %s" % [sim_time, sig, str(args.slice(0, 3))])
	_emit_quiet(sig, args)


func _emit_quiet(sig: StringName, args: Array) -> void:
	callv(&"emit_signal", [sig] + args)


func _log(text: String) -> void:
	_event_log.append(text)
	if _event_log.size() > MAX_LOG:
		_event_log.remove_at(0)
	emit_signal(&"event_logged", text)


static func _to_sn_array(a) -> Array:
	var out: Array = []
	if a is Array or a is PackedStringArray:
		for x in a:
			out.append(StringName(x))
	return out


static func _to_str_array(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(String(x))
	return out


static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out


## Deep copy with StringName keys/values turned into Strings (JSON-safe).
static func _nested_str(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[String(k)] = _nested_str(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_nested_str(x))
		return arr
	if v is StringName:
		return String(v)
	return v


static func _load_sn_lists(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[StringName(k)] = _to_sn_array(d[k])
	return out


## { char: { room_or_door: record_or_float } } with StringName keys and
## the listed string fields converted back to StringName.
static func _load_nested(d: Dictionary, sn_fields: Array) -> Dictionary:
	var out := {}
	for k in d:
		var inner := {}
		for k2 in d[k]:
			var v = d[k][k2]
			if v is Dictionary:
				var rec: Dictionary = (v as Dictionary).duplicate(true)
				for f in sn_fields:
					if rec.has(f):
						rec[f] = StringName(rec[f])
				inner[StringName(k2)] = rec
			else:
				inner[StringName(k2)] = float(v)
		out[StringName(k)] = inner
	return out
