extends Node3D
## Acceptance tests (§13). Run headless:
##   godot --headless --path . res://tests/doors_test.tscn
## Exit code = number of failed checks.

const CORRIDOR := &"manor/corridor"
const STUDY := &"manor/study"
const BEDROOM := &"manor/bedroom"
const OUTSIDE := &"@outside"
const STUDY_DOOR := &"manor/study_door"
const BEDROOM_DOOR := &"manor/bedroom_door"
const FRONT_DOOR := &"manor/front_door"

@onready var R = RoomsAndDoors
@onready var _player_body: CharacterBody3D = $Characters/Player
@onready var _son_body: CharacterBody3D = $Characters/Son
@onready var _hk_body: CharacterBody3D = $Characters/Housekeeper
@onready var _son: NpcDoorAgent = $Characters/Son/Agent
@onready var _hk: NpcDoorAgent = $Characters/Housekeeper/Agent
@onready var _passkey: KeyItem = $Passkey

var _baseline: String = ""
var _events: Array = []
var _fails: int = 0
var _passes: int = 0
var _section: String = ""


func _ready() -> void:
	R.manual_clock = true
	R.instant_doors = false
	_register_characters()
	for sig in [&"door_knocked", &"knock_answered", &"discovery", &"trespass_committed", &"ajar_discovered",
			&"witness_gained", &"activity_overheard", &"activity_finished", &"activity_joined",
			&"fade_started", &"fade_ended", &"fade_rejected", &"scene_resolved", &"door_clip_detected",
			&"character_woken", &"listening_started", &"door_blocked", &"door_forced", &"room_tier_changed",
			&"duty_lingered", &"noise_heard"]:
		R.connect(sig, _recorder(sig))
	_son.crossed.connect(func(_d, to): _place(_son_body, to, 2.0))
	_hk.crossed.connect(func(_d, to): _place(_hk_body, to, 1.0))
	_run.call_deferred()


func _register_characters() -> void:
	R.register_character(&"maid", _player_body, { "role": &"servant" })
	R.register_character(&"son", _son_body, { "role": &"family" })
	R.register_character(&"housekeeper", _hk_body, { "role": &"servant" })
	R.register_character(&"lord", null, { "role": &"family" })
	R.register_character(&"lady", null, { "role": &"family" })
	R.register_character(&"guest", null, { "role": &"guest" })
	R.register_character(&"valet", null, { "role": &"servant" })
	R.set_player(&"maid")
	R.grant_key(&"lord", &"study_key")


func _recorder(sig: StringName) -> Callable:
	return func(a = null, b = null, c = null, d = null) -> void:
		_events.append([sig, a, b, c, d])


func _run() -> void:
	# Let physics settle so RoomAreas report initial overlaps.
	for i in 4:
		await get_tree().physics_frame
	_section = "setup"
	_check("player body detected in corridor by RoomArea", R.room_of(&"maid") == CORRIDOR, R.room_of(&"maid"))
	R.set_occupant_room(&"lord", STUDY, true)
	R.set_occupant_room(&"lady", BEDROOM, true)
	R.set_occupant_room(&"guest", CORRIDOR, true)
	R.set_occupant_room(&"valet", OUTSIDE, true)
	_baseline = JSON.stringify(R.save_state())

	await _t0_physics_and_view()
	_t1_keys_and_duty()
	_t2_hearing()
	_t3_peek()
	_t4_knock()
	_t5_discovery()
	_t6_fade()
	_t7_save_load()
	_t8_npc_pathing()
	_t9_residency()
	_t10_sleep_stealth()
	_t11_house_rules()
	await _t12_debug_overlay()

	print("\n==== doors_test: %d passed, %d failed ====" % [_passes, _fails])
	get_tree().quit(_fails)


# --- helpers ---------------------------------------------------------------------------

func _reset() -> void:
	R.load_state(JSON.parse_string(_baseline))
	ProjectSettings.set_setting(R.SETTING_FADE, false)
	_son.cancel()
	_hk.cancel()
	_passkey.holder = &""
	_events.clear()
	for pair in [[&"maid", _player_body, -5.0], [&"son", _son_body, 2.0], [&"housekeeper", _hk_body, 1.0]]:
		_place(pair[1], R.room_of(pair[0]), pair[2])


func _place(body: Node3D, room: StringName, x_off: float) -> void:
	for area in $Rooms.get_children():
		if (area as RoomArea).room_id == room:
			body.global_position = (area as RoomArea).anchor_global() + Vector3(x_off, 0, 0)


func _advance(seconds: float) -> void:
	R.advance_time(seconds)


func _count(sig: StringName, a = null, b = null) -> int:
	var n := 0
	for e in _events:
		if e[0] == sig and (a == null or e[1] == a) and (b == null or e[2] == b):
			n += 1
	return n


func _last(sig: StringName) -> Array:
	for i in range(_events.size() - 1, -1, -1):
		if _events[i][0] == sig:
			return _events[i]
	return []


func _check(name: String, cond: bool, detail = "") -> void:
	if cond:
		_passes += 1
		print("  PASS [%s] %s" % [_section, name])
	else:
		_fails += 1
		print("  FAIL [%s] %s  -- %s" % [_section, name, str(detail)])


func _begin(name: String) -> void:
	_section = name
	print("\n-- %s" % name)
	_reset()


# --- scenarios ------------------------------------------------------------------------

func _t0_physics_and_view() -> void:
	_begin("0 physics occupancy, clip detection, blocked swing, view")
	var door_node: Door = $Doors/FrontDoor
	var shape: CollisionShape3D = door_node.get_node(^"CollisionShape3D")
	_check("closed door collision enabled", not shape.disabled)
	R.try_open(FRONT_DOOR, &"maid", { "instant": true })
	await get_tree().process_frame
	await get_tree().physics_frame
	_check("open door collision disabled", shape.disabled)
	_player_body.global_position = Vector3(3, 1, -4.5)
	for i in 3:
		await get_tree().physics_frame
	_check("RoomArea moved player outside", R.room_of(&"maid") == OUTSIDE, R.room_of(&"maid"))
	_check("no clip through open door", _count(&"door_clip_detected", &"maid") == 0)
	R.try_close(FRONT_DOOR, &"maid", { "instant": true })
	_player_body.global_position = Vector3(-5, 1, 0)
	for i in 3:
		await get_tree().physics_frame
	_check("walking through a closed door is flagged", _count(&"door_clip_detected", &"maid") == 1, _events)
	# Blocked: a body standing in the swing.
	R.try_open(FRONT_DOOR, &"maid", { "instant": true })
	_player_body.global_position = Vector3(3, 1, -0.95)
	for i in 3:
		await get_tree().physics_frame
	var r: Dictionary = R.try_close(FRONT_DOOR, &"maid", { "instant": true })
	_check("close into a body fails BLOCKED", r["reason"] == RAD.BLOCKED, r)
	_check("door reverts to AJAR", int(R.get_door(FRONT_DOOR)["state"]) == RAD.DoorState.AJAR)
	_check("door_blocked emitted", _count(&"door_blocked") >= 1)
	_player_body.global_position = Vector3(-5, 1, 0)
	for i in 3:
		await get_tree().physics_frame
	_check("close completes once clear", bool(R.try_close(FRONT_DOOR, &"maid", { "instant": true })["ok"]))
	# Swing timing: AJAR instant, OPEN after swing_time.
	R.try_open(FRONT_DOOR, &"maid")
	_check("open passes through AJAR", int(R.get_door(FRONT_DOOR)["state"]) == RAD.DoorState.AJAR)
	_advance(0.4)
	_check("OPEN after swing_time", int(R.get_door(FRONT_DOOR)["state"]) == RAD.DoorState.OPEN)
	R.set_occupant_room(&"maid", CORRIDOR, true)


func _t1_keys_and_duty() -> void:
	_begin("1 locked study: son NO_KEY, housekeeper passkey, maid duty window")
	var son: Dictionary = R.may_pass(&"son", STUDY_DOOR)
	_check("son denied NO_KEY", not bool(son["ok"]) and son["reason"] == RAD.NO_KEY, son)
	_check("son try_open fails LOCKED", R.try_open(STUDY_DOOR, &"son")["reason"] == RAD.LOCKED)
	_check("housekeeper denied before pickup", not bool(R.may_pass(&"housekeeper", STUDY_DOOR)["ok"]))
	_passkey.pick_up(&"housekeeper")
	_check("passkey substitutes for study_key", R.has_key(&"housekeeper", &"study_key"))
	_check("housekeeper admitted with passkey", bool(R.may_pass(&"housekeeper", STUDY_DOOR)["ok"]))
	_check("housekeeper can unlock", bool(R.try_unlock(STUDY_DOOR, &"housekeeper")["ok"]))
	_check("housekeeper can relock", bool(R.try_lock(STUDY_DOOR, &"housekeeper")["ok"]))
	_check("maid denied without duty", R.may_pass(&"maid", STUDY_DOOR)["reason"] == RAD.NO_KEY)
	R.set_duty(&"maid", STUDY, { "duration": 300.0, "expected": 120.0 })
	_check("maid admitted during duty window", bool(R.may_pass(&"maid", STUDY_DOOR)["ok"]))
	_check("maid ON_DUTY in study", R.admission(&"maid", STUDY) == RAD.Admission.ON_DUTY)
	_check("duty_remaining reported", absf(R.duty_remaining(&"maid", STUDY) - 300.0) < 0.01, R.duty_remaining(&"maid", STUDY))
	_advance(301.0)
	var after: Dictionary = R.may_pass(&"maid", STUDY_DOOR)
	_check("maid denied after duty expires", not bool(after["ok"]) and after["reason"] == RAD.NO_KEY, after)
	_check("maid admission NONE after expiry", R.admission(&"maid", STUDY) == RAD.Admission.NONE)


func _t2_hearing() -> void:
	_begin("2 study conversation: closed / ajar / listening")
	R.set_occupant_room(&"guest", STUDY, true)
	var parts := [&"lord", &"guest"]
	var closed: Dictionary = R.hear_check(&"maid", STUDY, RAD.LOUD_CONVERSATION, parts)
	_check("CLOSED: heard", bool(closed["heard"]), closed)
	_check("CLOSED: not identified", not bool(closed["identified"]) and (closed["participants"] as Array).is_empty(), closed)
	R.try_unlock(STUDY_DOOR, &"lord")
	R.set_ajar(STUDY_DOOR, &"maid")
	var ajar: Dictionary = R.hear_check(&"maid", STUDY, RAD.LOUD_CONVERSATION, parts)
	_check("AJAR: identified", bool(ajar["identified"]) and (ajar["participants"] as Array).has(&"lord"), ajar)
	R.try_close(STUDY_DOOR, &"maid", { "instant": true })
	_check("LISTEN posture accepted", R.start_listening(&"maid", STUDY_DOOR))
	_check("listening_started emitted", _count(&"listening_started", &"maid") == 1)
	var listen: Dictionary = R.hear_check(&"maid", STUDY, RAD.LOUD_CONVERSATION, parts)
	_check("LISTEN at CLOSED: identified", bool(listen["identified"]) and (listen["participants"] as Array).has(&"guest"), listen)
	R.stop_listening(&"maid")
	_check("whisper through closed door unheard", not bool(R.hear_check(&"maid", STUDY, RAD.LOUD_WHISPER, parts)["heard"]))
	var w: Array = R.witnesses_of(STUDY, RAD.LOUD_CONVERSATION, &"test_conv")
	_check("witnesses_of includes room occupants and corridor", w.has(&"lord") and w.has(&"maid") and not w.has(&"valet"), w)
	_check("witness_gained emitted per witness", _count(&"witness_gained", &"test_conv") == w.size())


func _t3_peek() -> void:
	_begin("3 keyhole peek")
	_check("no sight through closed door without peeking", R.sight_check(&"maid", STUDY, STUDY_DOOR)["level"] == RAD.SIGHT_NONE)
	R.start_peeking(&"maid", STUDY_DOOR)
	var g: Dictionary = R.sight_check(&"maid", STUDY, STUDY_DOOR)
	_check("peek returns GLIMPSE", g["level"] == RAD.SIGHT_GLIMPSE and bool(g["seen"]), g)
	_check("glimpse: activity class, no identities", g["activity"] == &"occupied" and (g["identities"] as Array).is_empty(), g)
	_advance(2.6)
	var p: Dictionary = R.sight_check(&"maid", STUDY, STUDY_DOOR)
	_check("prolonged peek identifies", (p["identities"] as Array).has(&"lord"), p)
	R.stop_peeking(&"maid")
	_check("bedroom door has no keyhole sight", R.sight_check(&"lord", BEDROOM, BEDROOM_DOOR)["level"] == RAD.SIGHT_NONE)
	# AJAR cone (spatial): son standing in front of the study door gap.
	R.set_occupant_room(&"son", STUDY, true)
	_place(_son_body, STUDY, 0.0)
	R.try_unlock(STUDY_DOOR, &"lord")
	R.set_ajar(STUDY_DOOR, &"lord")
	var cone: Dictionary = R.sight_check(&"maid", STUDY, STUDY_DOOR)
	_check("AJAR cone sees body in the gap", cone["level"] == RAD.SIGHT_PARTIAL and (cone["identities"] as Array).has(&"son"), cone)
	_check("AJAR cone misses bodiless/out-of-cone", not (cone["identities"] as Array).has(&"lord"), cone)
	_son_body.global_position = Vector3(-5.5, 1, 2.0)
	var miss: Dictionary = R.sight_check(&"maid", STUDY, STUDY_DOOR)
	_check("AJAR cone misses body off-axis", not (miss["identities"] as Array).has(&"son"), miss)


func _t4_knock() -> void:
	_begin("4 knock protocol")
	_check("09:00 is not a social hour", not R.default_knock_policy.is_social_hour(R.clock_hour()), R.clock_hour())
	R.knock(STUDY_DOOR, &"son")
	_check("door_knocked emitted", _count(&"door_knocked", STUDY_DOOR, &"son") == 1)
	_advance(2.5)
	var s: Array = _last(&"knock_answered")
	_check("uninvited son gets silence", not s.is_empty() and s[2] == &"son" and s[3] == RAD.RESPONSE_SILENCE, s)
	_check("door still locked", bool(R.get_door(STUDY_DOOR)["locked"]))
	R.set_invitation(&"guest", STUDY, &"lord")
	_check("guest INVITED", R.admission(&"guest", STUDY) == RAD.Admission.INVITED)
	R.knock(STUDY_DOOR, &"guest")
	_advance(0.5)
	_check("no instant response (0.8-2s delay)", _count(&"knock_answered", STUDY_DOOR, &"guest") == 0)
	_advance(2.0)
	var g: Array = _last(&"knock_answered")
	_check("owner answers invited guest: come in", g[2] == &"guest" and g[3] == RAD.RESPONSE_COME_IN, g)
	_check("come in unlocks", not bool(R.get_door(STUDY_DOOR)["locked"]))
	_check("guest may pass", bool(R.may_pass(&"guest", STUDY_DOOR)["ok"]))
	_check("door not auto-opened", int(R.get_door(STUDY_DOOR)["state"]) == RAD.DoorState.CLOSED)
	R.try_lock(STUDY_DOOR, &"lord")
	# Wait response in social hours, then retry cooldown.
	R.set_clock_hour(14.0)
	R.knock(STUDY_DOOR, &"son")
	_advance(2.5)
	_check("social hour uninvited: wait", _last(&"knock_answered")[3] == RAD.RESPONSE_WAIT)
	var n := _count(&"knock_answered", STUDY_DOOR, &"son")
	R.knock(STUDY_DOOR, &"son")
	_advance(2.5)
	_check("retry within 5s gets no response", _count(&"knock_answered", STUDY_DOOR, &"son") == n)
	R.set_clock_hour(9.0)
	# Servant announce.
	R.announce(STUDY_DOOR, &"maid", "fires")
	_advance(2.5)
	_check("announce off duty: not admitted", _last(&"knock_answered")[3] == RAD.RESPONSE_SILENCE)
	R.set_duty(&"maid", STUDY, { "duration": 600.0, "key_access": false })
	R.announce(STUDY_DOOR, &"maid", "fires")
	_advance(2.5)
	_check("announce on duty: come in", _last(&"knock_answered")[3] == RAD.RESPONSE_COME_IN, _last(&"knock_answered"))
	R.set_occupant_room(&"lord", CORRIDOR, true)
	R.try_lock(STUDY_DOOR, &"lord")
	R.knock(STUDY_DOOR, &"guest")
	_advance(2.5)
	_check("owner absent: silence", _last(&"knock_answered")[3] == RAD.RESPONSE_SILENCE)


func _t5_discovery() -> void:
	_begin("5 discovery in the INTIMATE room")
	R.set_occupant_room(&"lord", CORRIDOR, true)
	R.set_occupant_room(&"maid", STUDY, true)
	# Her chore route runs through the study, so she is ON_DUTY there too.
	R.set_duty(&"maid", STUDY, { "duration": 600.0, "expected": 600.0 })
	R.set_duty(&"maid", BEDROOM, { "duration": 300.0, "expected": 120.0 })
	_check("maid may pass bedroom door on duty", bool(R.may_pass(&"maid", BEDROOM_DOOR)["ok"]))
	R.try_open(BEDROOM_DOOR, &"maid", { "instant": true })
	R.set_occupant_room(&"maid", BEDROOM)
	_check("ON_DUTY: no discovery", _count(&"discovery", &"maid") == 0)
	_check("ON_DUTY: no trespass", _count(&"trespass_committed", &"maid", BEDROOM) == 0)
	_advance(1.0)
	_check("still no discovery while on duty", _count(&"discovery", &"maid") == 0)
	R.set_occupant_room(&"maid", STUDY)
	R.clear_duty(&"maid", BEDROOM)
	R.try_open(BEDROOM_DOOR, &"maid", { "instant": true })
	R.set_occupant_room(&"maid", BEDROOM)
	var d: Array = _last(&"discovery")
	_check("admission NONE: discovery fires", not d.is_empty() and d[1] == &"maid" and d[2] == &"lady" and d[3] == BEDROOM, d)
	if not d.is_empty():
		var ctx: Dictionary = d[4]
		_check("context: privacy + door states", int(ctx["privacy"]) == RAD.Privacy.INTIMATE \
				and ctx["doors"].has(String(BEDROOM_DOOR)) and ctx["via"] == "same_room", ctx)
	_check("trespass logged (no knock)", _count(&"trespass_committed", &"maid", BEDROOM) == 1 \
			and not bool(R.trespass_log()[-1]["knocked"]))
	_check("discovery deduplicated", _count(&"discovery", &"maid", &"lady") == 1)
	# Lingering past 2x expected duration decays ON_DUTY to NONE.
	R.set_occupant_room(&"maid", STUDY)
	_events.clear()
	R.set_duty(&"maid", BEDROOM, { "duration": 600.0, "expected": 10.0 })
	R.try_open(BEDROOM_DOOR, &"maid", { "instant": true })
	R.set_occupant_room(&"maid", BEDROOM)
	_advance(15.0)
	_check("within 2x expected: on duty", _count(&"discovery", &"maid") == 0)
	_advance(6.0)
	_check("lingering > 2x: duty_lingered", _count(&"duty_lingered", &"maid") == 1)
	_check("lingering > 2x: discovered", _count(&"discovery", &"maid", &"lady") == 1)


func _t6_fade() -> void:
	_begin("6 fade-to-black preconditions")
	R.register_scene(&"bedroom_scene", { "door_state": RAD.DoorState.CLOSED, "locked": true, "room_privacy_min": RAD.Privacy.PRIVATE })
	R.set_ajar(BEDROOM_DOOR, &"lady")
	var p: Dictionary = R.scene_preconditions_met(&"bedroom_scene", BEDROOM)
	_check("AJAR door fails", not bool(p["ok"]) and (p["unmet"] as Array).any(func(u): return u["key"] == "door_state"), p)
	_check("request_scene refused when unmet", not bool(R.request_scene(&"bedroom_scene", BEDROOM)["ok"]))
	R.try_close(BEDROOM_DOOR, &"lady", { "instant": true })
	_check("CLOSED but unlocked fails", not bool(R.scene_preconditions_met(&"bedroom_scene", BEDROOM)["ok"]))
	_check("lady bolts from inside", bool(R.try_lock(BEDROOM_DOOR, &"lady")["ok"]))
	_check("CLOSED+locked passes", bool(R.scene_preconditions_met(&"bedroom_scene", BEDROOM)["ok"]))
	ProjectSettings.set_setting(R.SETTING_FADE, true)
	var res: Dictionary = R.request_scene(&"bedroom_scene", BEDROOM, { "participants": [&"lady", &"valet"], "summary": { "affection": 1 } })
	_check("fade build resolves to fade", res["mode"] == &"fade" and _count(&"fade_started") == 1, res)
	R.request_fade_to_black(&"other")
	_check("one fade at a time", _count(&"fade_rejected") == 1)
	_advance(2.5)
	_check("fade_ended", _count(&"fade_ended") == 1)
	ProjectSettings.set_setting(R.SETTING_FADE, false)
	var full: Dictionary = R.request_scene(&"bedroom_scene", BEDROOM)
	_check("full build resolves to scene", full["mode"] == &"full" and _count(&"fade_started") == 1, full)
	_check("scene data has risk inputs", full["data"].has("witness_count") and full["data"].has("privacy"), full)


func _t7_save_load() -> void:
	_begin("7 save -> quit -> load")
	_passkey.pick_up(&"housekeeper")
	R.try_unlock(STUDY_DOOR, &"lord")
	R.set_ajar(STUDY_DOOR, &"maid")
	R.try_lock(BEDROOM_DOOR, &"lady")
	R.try_open(FRONT_DOOR, &"valet", { "instant": true })
	R.set_door_sound_level(FRONT_DOOR, 0.2)
	R.set_invitation(&"guest", STUDY, &"lord")
	R.set_duty(&"maid", BEDROOM, { "duration": 900.0 })
	_advance(3.0)
	var before := {}
	for d in R.door_ids():
		var door: Dictionary = R.get_door(d)
		before[d] = [door["state"], door["locked"], door["sound_level"]]
	var t: float = R.sim_time
	var json := JSON.stringify(R.save_state())
	# Quit: forget everything, then the scene re-registers.
	R.reset()
	_check("reset forgets doors", R.get_door(STUDY_DOOR).is_empty())
	for n in $Rooms.get_children():
		n.register_with_system()
	for n in $Doors.get_children():
		n.register_with_system()
	_passkey.register_with_system()
	_register_characters()
	R.load_state(JSON.parse_string(json))
	var same := true
	for d in before:
		var door: Dictionary = R.get_door(d)
		if [door["state"], door["locked"], door["sound_level"]] != before[d]:
			same = false
			print("    mismatch %s: %s vs %s" % [d, [door["state"], door["locked"], door["sound_level"]], before[d]])
	_check("door states, locks, sound levels restored", same)
	_check("keyring restored (passkey opens study)", R.has_key(&"housekeeper", &"study_key"))
	_check("key item stays picked up", _passkey.holder == &"housekeeper" and not _passkey.visible)
	_check("active invitation restored", R.admission(&"guest", STUDY) == RAD.Admission.INVITED)
	_check("duty window restored", absf(R.duty_remaining(&"maid", BEDROOM) - 897.0) < 0.01, R.duty_remaining(&"maid", BEDROOM))
	_check("clock restored", absf(R.sim_time - t) < 0.001)
	_check("occupancy restored", R.room_of(&"lady") == BEDROOM and R.occupants(STUDY).has(&"lord"))
	_check("door view re-rendered", ($Doors/StudyDoor/Label3D as Label3D).text.contains("AJAR"))
	var v1 := JSON.parse_string(json) as Dictionary
	v1.erase("duties")
	v1.erase("trespass_log")
	v1["doors"][String(FRONT_DOOR)].erase("sound_level")
	R.load_state(v1)
	_check("load tolerates missing keys", R.get_door(FRONT_DOOR)["state"] == RAD.DoorState.OPEN)
	_register_characters()


func _t8_npc_pathing() -> void:
	_begin("8 NPC pathing: knock at locked door, AJAR discovery")
	_son.go_to(BEDROOM, true)
	for i in 300:
		_advance(0.1)
	_check("son knocked at the locked study door", _count(&"door_knocked", STUDY_DOOR, &"son") >= 1)
	_check("son never left the corridor", R.room_of(&"son") == CORRIDOR, R.room_of(&"son"))
	_check("son gave up (no route he may pass)", _son.state == NpcDoorAgent.State.FAILED, _son.state_name())
	_check("study door never opened by son", int(R.get_door(STUDY_DOOR)["state"]) == RAD.DoorState.CLOSED)
	# Player leaves the front door ajar; housekeeper heads outside.
	R.set_ajar(FRONT_DOOR, &"maid")
	_hk.go_to(OUTSIDE)
	for i in 50:
		_advance(0.1)
	_check("ajar_discovered by housekeeper", _count(&"ajar_discovered", FRONT_DOOR, &"housekeeper") == 1, _events.filter(func(e): return e[0] == &"ajar_discovered"))
	_check("opening it was audible", _count(&"noise_heard", &"maid", FRONT_DOOR) >= 1)
	_check("housekeeper arrived outside", R.room_of(&"housekeeper") == OUTSIDE)
	_check("servant closed the door behind her", int(R.get_door(FRONT_DOOR)["state"]) == RAD.DoorState.CLOSED)
	_check("no NPC clipped through a door", _count(&"door_clip_detected", &"son") + _count(&"door_clip_detected", &"housekeeper") == 0)
	# Reroute vs. a keyed NPC: housekeeper with passkey reaches the bedroom through the study.
	_events.clear()
	_passkey.pick_up(&"housekeeper")
	R.set_occupant_room(&"housekeeper", CORRIDOR, true)
	_hk.go_to(BEDROOM, true)
	for i in 80:
		_advance(0.1)
	_check("passkey holder pathed corridor -> study -> bedroom", R.room_of(&"housekeeper") == BEDROOM, [R.room_of(&"housekeeper"), _hk.state_name()])
	_check("…without clipping", _count(&"door_clip_detected", &"housekeeper") == 0)


func _t9_residency() -> void:
	_begin("9 residency tiers")
	_check("player room tier 0", R.simulation_tier(CORRIDOR) == RAD.Tier.PLAYER)
	_check("adjoining rooms tier 1", R.simulation_tier(STUDY) == 1 and R.simulation_tier(OUTSIDE) == 1)
	_check("two doors away tier 2", R.simulation_tier(BEDROOM) == 2)
	_check("resident_rooms has full tier-1 ring", _ring_ok())
	R.set_occupant_room(&"guest", STUDY, true)
	var conv: StringName = R.start_activity({ "id": &"study_talk", "room": STUDY, "participants": [&"lord", &"guest"], "loudness": RAD.LOUD_CONVERSATION, "duration": 30.0 })
	var scene: StringName = R.start_activity({ "id": &"bedroom_scene", "room": BEDROOM, "participants": [&"lady", &"valet"], "loudness": RAD.LOUD_WHISPER, "duration": 120.0, "activity_class": &"private_scene" })
	R.set_occupant_room(&"valet", BEDROOM, true)
	var heard := _events.filter(func(e): return e[0] == &"activity_overheard" and e[1] == conv and e[2] == &"maid")
	_check("tier-1 conversation overheard from corridor", heard.size() >= 1 and bool(heard[0][3]["heard"]) and not bool(heard[0][3]["identified"]), heard)
	_advance(31.0)
	var fin: Array = _last(&"activity_finished")
	_check("conversation finished on schedule", not fin.is_empty() and fin[1] == conv and absf(float(fin[2]["finished_at"]) - 30.0 - float(fin[2]["start"])) < 0.001, fin)
	_advance(9.0)
	var st: Dictionary = R.activity_state(scene)
	_check("tier-2 private scene advanced", bool(st["active"]) and absf(float(st["elapsed"]) - 40.0) < 0.2 and int(st["tier"]) == 2, st)
	R.set_occupant_room(&"maid", STUDY, true)
	_check("promotion: bedroom now tier 1", R.simulation_tier(BEDROOM) == 1 and _count(&"room_tier_changed", BEDROOM, 1) == 1)
	_check("ring intact after move", _ring_ok())
	_check("outside demoted to tier 2", R.simulation_tier(OUTSIDE) == 2)
	R.set_occupant_room(&"maid", BEDROOM, true)
	var j: Array = _last(&"activity_joined")
	_check("player joins private scene in progress", not j.is_empty() and j[1] == scene and j[2] == &"maid" and absf(float(j[3]) - 40.0) < 0.2, j)
	_check("scene not restarted", absf(float(R.activity_state(scene)["start"]) - float(st["start"])) < 0.001)
	_check("three doors away is tier 3", R.simulation_tier(OUTSIDE) == RAD.Tier.ABSTRACT)
	_advance(81.0)
	_check("scene finishes at scheduled end", not bool(R.activity_state(scene)["active"]))


func _ring_ok() -> bool:
	var ring := R.rooms_adjacent(R.room_of(&"maid"))
	var res := R.resident_rooms()
	for r in ring:
		if not res.has(r):
			return false
	return res.has(R.room_of(&"maid"))


func _t10_sleep_stealth() -> void:
	_begin("10 sleeping owner, closed INTIMATE room, quiet entry")
	R.set_clock_hour(23.0)
	R.set_sleeping(&"lady", true)
	R.set_occupant_room(&"lord", CORRIDOR, true)
	R.set_occupant_room(&"maid", STUDY, true)
	R.try_open(BEDROOM_DOOR, &"maid", { "quiet": true, "instant": true })
	_check("quiet entry does not wake her", R.is_sleeping(&"lady") and _count(&"character_woken", &"lady") == 0)
	R.set_occupant_room(&"maid", BEDROOM)
	_check("sleeping owner discovers nothing", _count(&"discovery", &"maid") == 0)
	_check("trespass logged even unseen", _count(&"trespass_committed", &"maid", BEDROOM) == 1)
	var w: Array = R.witnesses_of(BEDROOM, RAD.LOUD_WHISPER)
	_check("sleeper is not a witness of a whisper", not w.has(&"lady"), w)
	R.try_close(BEDROOM_DOOR, &"maid", { "instant": true })
	_check("a normal close wakes her", not R.is_sleeping(&"lady") and _count(&"character_woken", &"lady") == 1)
	var d: Array = _last(&"discovery")
	_check("…and she discovers the maid", not d.is_empty() and d[1] == &"maid" and d[2] == &"lady", d)
	R.set_clock_hour(9.0)


func _t11_house_rules() -> void:
	_begin("11 house rules: auto-close, hold, force, sealed")
	R.set_occupant_room(&"maid", STUDY, true)
	R.set_ajar(BEDROOM_DOOR, &"maid")
	_advance(3.5)
	_check("INTIMATE door still ajar at 3.5s", int(R.get_door(BEDROOM_DOOR)["state"]) == RAD.DoorState.AJAR)
	_advance(1.0)
	_check("INTIMATE door auto-closes after 4s", int(R.get_door(BEDROOM_DOOR)["state"]) == RAD.DoorState.CLOSED)
	R.hold_open(BEDROOM_DOOR, &"maid")
	_advance(6.0)
	_check("held door does not auto-close", int(R.get_door(BEDROOM_DOOR)["state"]) == RAD.DoorState.OPEN)
	_check("others cannot close a held door", R.try_close(BEDROOM_DOOR, &"lady")["reason"] == RAD.HELD)
	R.release_hold(BEDROOM_DOOR, &"maid")
	_advance(4.5)
	_check("released door auto-closes", int(R.get_door(BEDROOM_DOOR)["state"]) == RAD.DoorState.CLOSED)
	R.set_occupant_room(&"maid", CORRIDOR, true)
	var f: Dictionary = R.try_open(STUDY_DOOR, &"son", { "force": true, "instant": true })
	_check("force opens a locked door", bool(f["ok"]) and _count(&"door_forced", STUDY_DOOR, &"son") == 1)
	_check("forcing is loud", float(R.door_noise(STUDY_DOOR, { "force": true })) > 1.0)
	R.register_room({ "id": &"manor/vault", "privacy": RAD.Privacy.SEALED })
	R.register_door({ "id": &"manor/vault_door", "room_a": CORRIDOR, "room_b": &"manor/vault" })
	_check("SEALED: TRESPASS_DENIED for the unadmitted", R.may_pass(&"son", &"manor/vault_door")["reason"] == RAD.TRESPASS_DENIED)
	_check("path_exists respects doors", not R.path_exists(CORRIDOR, &"manor/vault", &"son") and R.path_exists(CORRIDOR, STUDY, &"son"))


func _t12_debug_overlay() -> void:
	_begin("12 debug overlay")
	R.set_debug_overlay(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("overlay present", R.get_child_count() > 0)
	_check("event log capped at 20", R.event_log().size() <= 20 and R.event_log().size() > 0)
	R.set_debug_overlay(false)
