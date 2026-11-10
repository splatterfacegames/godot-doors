class_name DoorPolicies
extends Node
## Optional gameplay policies layered on RoomsAndDoors. Add one to the game scene.
## Configuration describes gameplay; all mutable policy data is saved by the autoload.
## Actor arguments accept character IDs or registered bodies. Dimensions are metres.

signal transition_requested(actor: StringName, destination: StringName)
signal feedback(text: String)
signal reinforcement_requested(door_id: StringName, room_id: StringName)
signal objective_changed(door_id: StringName, active: bool)
signal progress_changed(actor: StringName, progress: Dictionary)

var _configs: Dictionary = {}
var _thresholds: Dictionary = {}
var _queues: Dictionary = {}
var _reservations: Dictionary = {}
var _players: Array[StringName] = []
var _waiting: Dictionary = {}
var _pending_close: Dictionary = {}
var _locale := "en"
var _translations: Dictionary = {
	"en": {"open": "Open", "proximity": "Approach to open", "sealed": "Permanently sealed", "decorative": "Decoration", "visual_only": "Visual door: no passage", "wrong_side": "Opens from the other side", "clearance": "Too large for this doorway", "gate": "Complete the objective to unlock", "locked": "A key is required", "waiting": "Waiting for the group", "queue": "Wait for the doorway to clear", "access": "Earn gold to purchase temporary access", "objective": "Objective entrance", "closed": "Closed"},
	"ja": {"open": "開ける", "proximity": "近づくと開く", "sealed": "永久に封鎖されています", "decorative": "装飾", "visual_only": "通路", "wrong_side": "反対側から開きます", "clearance": "この出入口は狭すぎます", "gate": "目標を達成して解錠", "locked": "鍵が必要です", "waiting": "仲間を待っています", "queue": "出入口が空くまで待つ", "access": "獲得したゴールドで一時通行権を購入", "objective": "目標の入口", "closed": "閉まっています"}
}


func _ready() -> void:
	RoomsAndDoors.policy_controller = self
	RoomsAndDoors.door_state_changed.connect(_on_door_state_changed)
	RoomsAndDoors.occupant_changed.connect(_on_occupant_changed)


func _exit_tree() -> void:
	if RoomsAndDoors.policy_controller == self:
		RoomsAndDoors.policy_controller = null


func _server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _actor(value) -> StringName:
	if value is Node:
		return RoomsAndDoors.character_id_for_body(value)
	return StringName(value)


func _data(section: String) -> Dictionary:
	if not RoomsAndDoors.policy_state.has(section):
		RoomsAndDoors.policy_state[section] = {}
	return RoomsAndDoors.policy_state[section]


func _record(id: StringName) -> Dictionary:
	var records := _data("doors")
	var key := String(id)
	if not records.has(key):
		records[key] = {"gate_unlocked": false, "objective": false, "access": {}, "claimed": []}
	return records[key]


func configure_door(id: StringName, config: Dictionary) -> void:
	_configs[id] = config.duplicate(true)
	var view := RoomsAndDoors.door_view(id)
	if view is Door:
		(view as Door).apply_policy_geometry(config)
	if not _server():
		return
	var state := _record(id)
	if not bool(state.get("configured", false)):
		state["objective"] = bool(config.get("objective", false))
		state["configured"] = true
	var mode := StringName(config.get("mode", "interactive"))
	if mode in [&"open_only", &"visual_only"]:
		RoomsAndDoors.set_policy_door_state(id, RAD.DoorState.OPEN, false)
	elif mode in [&"decorative", &"sealed"]:
		RoomsAndDoors.set_policy_door_state(id, RAD.DoorState.CLOSED, true)
	if config.has("key_id"):
		RoomsAndDoors.set_policy_key(id, StringName(config["key_id"]))
	if view is Door:
		(view as Door)._render(RoomsAndDoors.get_door(id), true)


func check_open(id: StringName, actor: StringName, opts: Dictionary = {}) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	var pass_check := check_pass(id, actor, opts)
	if not bool(pass_check["ok"]):
		return pass_check
	var cfg: Dictionary = _configs.get(id, {})
	if StringName(cfg.get("trigger", "manual")) != StringName(opts.get("trigger", "manual")):
		return _result(false, &"wrong_trigger")
	return _result(true)


func can_close(id: StringName) -> bool:
	return StringName((_configs.get(id, {}) as Dictionary).get("mode", "interactive")) not in [&"open_only", &"visual_only"]


func trigger_for(id: StringName) -> StringName:
	return StringName((_configs.get(id, {}) as Dictionary).get("trigger", "manual"))


func can_unlock(id: StringName) -> bool:
	return StringName((_configs.get(id, {}) as Dictionary).get("mode", "interactive")) not in [&"decorative", &"sealed", &"visual_only"]


func check_pass(id: StringName, actor: StringName, opts: Dictionary = {}) -> Dictionary:
	if not _configs.has(id):
		return _result(true)
	var cfg: Dictionary = _configs[id]
	var mode := StringName(cfg.get("mode", "interactive"))
	if mode in [&"decorative", &"sealed", &"visual_only"]:
		return _result(false, mode)
	var door: Dictionary = RoomsAndDoors.get_door(id)
	if door.is_empty():
		return _result(false, &"no_such_door")
	var from_room := StringName(opts.get("from_room", RoomsAndDoors.room_of(actor)))
	if actor != RoomsAndDoors.HOUSE_ACTOR and from_room not in [StringName(door["room_a"]), StringName(door["room_b"])]:
		return _result(false, &"not_adjacent")
	var allowed := StringName(cfg.get("allowed_from", ""))
	if allowed != &"" and from_room != allowed:
		return _result(false, &"wrong_side")
	var dimensions := _body_dimensions(actor)
	var body_width := float(opts.get("width", dimensions.x))
	var body_height := float(opts.get("height", dimensions.y))
	if body_width > float(cfg.get("width", INF)) or body_height > float(cfg.get("height", INF)):
		return _result(false, &"clearance")
	var gate := StringName(cfg.get("gate_kind", ""))
	if gate != &"" and not bool(_record(id).get("gate_unlocked", false)):
		return _result(false, &"gate", {"kind": gate})
	if int(cfg.get("access_cost", 0)) > 0:
		var until := float((_record(id).get("access", {}) as Dictionary).get(String(actor), -1.0))
		if until <= RoomsAndDoors.sim_time:
			return _result(false, &"access_expired")
	var holder := StringName(_reservations.get(id, ""))
	if holder != &"" and holder != actor:
		return _result(false, &"queue")
	return _result(true)


func request_open(id: StringName, actor, opts: Dictionary = {}) -> Dictionary:
	var who := _actor(actor)
	var check := check_open(id, who, opts)
	if not bool(check["ok"]):
		feedback.emit(get_hint(id, who))
		return check
	var door: Dictionary = RoomsAndDoors.get_door(id)
	if bool(door.get("locked", false)):
		var unlocked: Dictionary = RoomsAndDoors.try_unlock(id, who)
		if not bool(unlocked["ok"]):
			return unlocked
	# No force override: policy callers cannot bypass key/admission/geometry checks.
	var safe_opts := opts.duplicate()
	safe_opts.erase("force")
	return RoomsAndDoors.try_open(id, who, safe_opts)


func register_player(actor) -> void:
	if not _server():
		return
	var who := _actor(actor)
	if who != &"" and not _players.has(who):
		_players.append(who)
		_data("players")[String(who)] = true
		RoomsAndDoors.register_local_player(who)


func set_player_room(actor, room: StringName) -> void:
	if _server():
		var who := _actor(actor)
		var from := RoomsAndDoors.room_of(who)
		if from == &"" or from == room or authorize_room_entry(who, from, room):
			RoomsAndDoors.set_occupant_room(who, room, true)


func authorize_room_entry(actor: StringName, from: StringName, destination: StringName) -> bool:
	var doors := RoomsAndDoors.doors_between(from, destination)
	var configured := false
	for id in doors:
		if not _configs.has(id):
			return true
		configured = true
		var check := check_pass(id, actor, {"from_room": from})
		if bool(check["ok"]) and int(RoomsAndDoors.get_door(id).get("state", RAD.DoorState.CLOSED)) == RAD.DoorState.OPEN:
			return true
	if not configured:
		return true
	feedback.emit(get_hint(doors[0], actor))
	# A one-way or logical gate must also reject a body walking through an already
	# open portal. Put it back on its original side; sealed doors remain solid.
	var view := RoomsAndDoors.door_view(doors[0]) as Node3D
	var body := RoomsAndDoors.character_body(actor) as Node3D
	if view != null and body != null:
		var local := view.to_local(body.global_position)
		var door: Dictionary = RoomsAndDoors.get_door(doors[0])
		local.z = -0.7 if from == StringName(door.get("room_a", "")) else 0.7
		body.global_position = view.to_global(local)
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
	return false


func can_unload_room(room: StringName) -> bool:
	# NPCs and players both retain their room; threshold occupants retain both sides.
	if not RoomsAndDoors.occupants(room).is_empty():
		return false
	for id in _thresholds:
		var door: Dictionary = RoomsAndDoors.get_door(id)
		if not (_thresholds[id] as Array).is_empty() and room in [StringName(door.get("room_a", "")), StringName(door.get("room_b", ""))]:
			return false
	return true


func enter_threshold(id: StringName, actor) -> void:
	if not _server():
		return
	var who := _actor(actor)
	if not _thresholds.has(id):
		_thresholds[id] = []
	if not (_thresholds[id] as Array).has(who):
		(_thresholds[id] as Array).append(who)
	RoomsAndDoors.set_door_blocked(id, true, &"policy")
	var cfg: Dictionary = _configs.get(id, {})
	if StringName(cfg.get("trigger", "manual")) == &"proximity":
		request_open(id, who, {"trigger": &"proximity"})
	_check_waiting(id)


func exit_threshold(id: StringName, actor) -> void:
	if not _server():
		return
	var who := _actor(actor)
	if _thresholds.has(id):
		(_thresholds[id] as Array).erase(who)
	release_threshold(id, who)
	if (_thresholds.get(id, []) as Array).is_empty():
		RoomsAndDoors.set_door_blocked(id, false, &"policy")
		var cfg: Dictionary = _configs.get(id, {})
		if bool(cfg.get("close_after_clear", false)) or bool(cfg.get("lock_after_clear", false)):
			_pending_close[id] = true
			_close_after_clear(id)


func reserve_threshold(id: StringName, actor) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	var who := _actor(actor)
	if not _queues.has(id):
		_queues[id] = []
	var queue: Array = _queues[id]
	if not queue.has(who):
		queue.append(who)
	if not _reservations.has(id) and queue[0] == who and (_thresholds.get(id, []) as Array).is_empty():
		_reservations[id] = who
	return _result(StringName(_reservations.get(id, "")) == who, &"ok" if StringName(_reservations.get(id, "")) == who else &"queue", {"position": queue.find(who)})


func release_threshold(id: StringName, actor) -> void:
	if not _server():
		return
	var who := _actor(actor)
	if _queues.has(id):
		(_queues[id] as Array).erase(who)
	if StringName(_reservations.get(id, "")) == who:
		_reservations.erase(id)
	if (_thresholds.get(id, []) as Array).is_empty() and not (_queues.get(id, []) as Array).is_empty():
		_reservations[id] = (_queues[id] as Array)[0]


func request_group_transition(id: StringName, actors: Array, destination: StringName, policy: StringName) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	if policy not in [&"wait", &"teleport", &"split"] or actors.is_empty():
		return _result(false, &"invalid_group_policy")
	var door: Dictionary = RoomsAndDoors.get_door(id)
	if destination not in [StringName(door.get("room_a", "")), StringName(door.get("room_b", ""))]:
		return _result(false, &"invalid_destination")
	var members: Array[StringName] = []
	for actor in actors:
		var who := _actor(actor)
		if who == &"" or not RoomsAndDoors.character_ids().has(who):
			return _result(false, &"unknown_actor")
		if not members.has(who):
			members.append(who)
	if policy == &"wait":
		_waiting[id] = {"actors": members, "destination": destination}
		if not _group_ready(id, members):
			feedback.emit(get_text("waiting"))
			return _result(false, &"waiting", {"pending": true})
	return _transition_group(id, members, destination, policy)


func _group_ready(id: StringName, actors: Array) -> bool:
	for actor in actors:
		if not (_thresholds.get(id, []) as Array).has(actor):
			return false
	return true


func _check_waiting(id: StringName) -> void:
	if not _waiting.has(id):
		return
	var pending: Dictionary = _waiting[id]
	if _group_ready(id, pending["actors"]):
		_transition_group(id, pending["actors"], StringName(pending["destination"]), &"wait")


func _transition_group(id: StringName, members: Array, destination: StringName, policy: StringName) -> Dictionary:
	# Validate every member before mutating anyone, so a denied member leaves the group intact.
	var first: StringName = members[0]
	var leader_room := RoomsAndDoors.room_of(first)
	for actor in members:
		var source := leader_room if policy == &"teleport" else RoomsAndDoors.room_of(actor)
		var check := check_pass(id, actor, {"from_room": source})
		if not bool(check["ok"]):
			return check
		var admission: Dictionary = RoomsAndDoors.may_pass_from(actor, id, source)
		if not bool(admission["ok"]):
			return admission
	var trigger := StringName((_configs.get(id, {}) as Dictionary).get("trigger", "manual"))
	var opened := request_open(id, first, {"instant": true, "trigger": trigger})
	if not bool(opened["ok"]):
		return opened
	_waiting.erase(id)
	for actor in members:
		if policy == &"split" and not (_thresholds.get(id, []) as Array).has(actor):
			continue
		RoomsAndDoors.set_occupant_room(actor, destination, true)
		_claim_reward(id, actor)
		transition_requested.emit(actor, destination)
		if _thresholds.has(id):
			(_thresholds[id] as Array).erase(actor)
		# Release each reservation; the next queued NPC is promoted once everyone clears.
		release_threshold(id, actor)
	RoomsAndDoors.set_door_blocked(id, not (_thresholds.get(id, []) as Array).is_empty(), &"policy")
	var cfg: Dictionary = _configs.get(id, {})
	if bool(cfg.get("close_after_clear", false)) or bool(cfg.get("lock_after_clear", false)):
		_pending_close[id] = true
		_close_after_clear(id)
	return _result(true, &"ok", {"actors": members, "destination": destination, "policy": policy})


func set_objective(id: StringName, active: bool) -> void:
	if not _server():
		return
	_record(id)["objective"] = active
	objective_changed.emit(id, active)


func unlock_gate(id: StringName, kind: StringName, token: StringName) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	if not _configs.has(id):
		return _result(false, &"no_such_door")
	var cfg: Dictionary = _configs[id]
	if kind != StringName(cfg.get("gate_kind", "")) or token == &"" or token != StringName(cfg.get("gate_token", "")):
		return _result(false, &"wrong_solution")
	_record(id)["gate_unlocked"] = true
	feedback.emit(String(cfg.get("unlock_text", "Gate unlocked")))
	return _result(true)


func get_hint(id: StringName, actor) -> String:
	var cfg: Dictionary = _configs.get(id, {})
	var check := check_pass(id, _actor(actor))
	var reason := String(check.get("reason", "ok"))
	if reason != "ok":
		if reason == "gate":
			return get_text(String(cfg["hint_key"])) if cfg.has("hint_key") else String(cfg.get("hint", get_text("gate")))
		return get_text("access") if reason == "access_expired" else get_text(reason)
	if bool(_record(id).get("objective", false)):
		return get_text("objective")
	if bool(RoomsAndDoors.get_door(id).get("locked", false)):
		return get_text("locked")
	return get_text("proximity") if StringName(cfg.get("trigger", "manual")) == &"proximity" else get_text("open")


func get_progress(actor) -> Dictionary:
	var key := String(_actor(actor))
	var progress := _data("progress")
	return (progress.get(key, {"xp": 0, "gold": 0, "items": []}) as Dictionary).duplicate(true)


func earn_currency(actor, amount: int) -> Dictionary:
	if not _server() or amount <= 0:
		return _result(false, &"invalid_award")
	var who := _actor(actor)
	var progress := get_progress(who)
	progress["gold"] = int(progress["gold"]) + amount
	_data("progress")[String(who)] = progress
	progress_changed.emit(who, progress.duplicate(true))
	return _result(true, &"ok", progress)


func purchase_access(id: StringName, actor) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	var cfg: Dictionary = _configs.get(id, {})
	var cost := int(cfg.get("access_cost", 0))
	if cost <= 0:
		return _result(false, &"not_for_sale")
	var who := _actor(actor)
	var progress := get_progress(who)
	if int(progress["gold"]) < cost:
		return _result(false, &"insufficient_gold")
	progress["gold"] = int(progress["gold"]) - cost
	_data("progress")[String(who)] = progress
	var access: Dictionary = _record(id)["access"]
	var expires := maxf(RoomsAndDoors.sim_time, float(access.get(String(who), 0.0))) + maxf(0.1, float(cfg.get("access_seconds", 30.0)))
	access[String(who)] = expires
	progress_changed.emit(who, progress.duplicate(true))
	return _result(true, &"ok", {"expires_at": expires, "gold": progress["gold"]})


func _claim_reward(id: StringName, actor: StringName) -> void:
	var cfg: Dictionary = _configs.get(id, {})
	var reward: Dictionary = cfg.get("reward", {})
	var record := _record(id)
	var claimed: Array = record["claimed"]
	if reward.is_empty() or claimed.has(String(actor)):
		return
	claimed.append(String(actor))
	var progress := get_progress(actor)
	progress["xp"] = int(progress["xp"]) + maxi(0, int(reward.get("xp", 0)))
	progress["gold"] = int(progress["gold"]) + maxi(0, int(reward.get("gold", 0)))
	for item in reward.get("items", []):
		(progress["items"] as Array).append(String(item))
	_data("progress")[String(actor)] = progress
	progress_changed.emit(actor, progress.duplicate(true))


func select_reinforcement(candidates: Array, visible_doors: Array = []) -> Dictionary:
	if not _server():
		return _result(false, &"server_authority")
	for candidate in candidates:
		var id := StringName(candidate.get("door_id", "")) if candidate is Dictionary else StringName(candidate)
		var door: Dictionary = RoomsAndDoors.get_door(id)
		var cfg: Dictionary = _configs.get(id, {})
		if door.is_empty() or visible_doors.has(id) or visible_doors.has(String(id)) or StringName(cfg.get("mode", "interactive")) in [&"decorative", &"sealed"]:
			continue
		var visible := false
		var view := RoomsAndDoors.door_view(id) as Node3D
		if view != null:
			var camera := view.get_viewport().get_camera_3d()
			if camera != null:
				var point := view.global_position + Vector3.UP
				if not camera.is_position_behind(point) and view.get_viewport().get_visible_rect().has_point(camera.unproject_position(point)):
					var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point)
					var hit := view.get_world_3d().direct_space_state.intersect_ray(ray)
					visible = hit.is_empty() or hit.get("collider") == view
		if visible:
			continue
		var room := StringName(candidate.get("room_id", door["room_b"])) if candidate is Dictionary else StringName(door["room_b"])
		if not RoomsAndDoors.occupants(room).is_empty() or not (_thresholds.get(id, []) as Array).is_empty():
			continue
		reinforcement_requested.emit(id, room)
		return _result(true, &"ok", {"door_id": id, "room_id": room})
	return _result(false, &"no_hidden_entrance")


func set_locale(locale: String) -> void:
	_locale = locale if _translations.has(locale) else "en"


func add_translations(locale: String, entries: Dictionary) -> void:
	if not _translations.has(locale):
		_translations[locale] = {}
	(_translations[locale] as Dictionary).merge(entries, true)


func get_text(key: String) -> String:
	return String((_translations.get(_locale, {}) as Dictionary).get(key, (_translations["en"] as Dictionary).get(key, key)))


func _close_after_clear(id: StringName) -> void:
	if not (_thresholds.get(id, []) as Array).is_empty():
		return
	var cfg: Dictionary = _configs.get(id, {})
	var destination := StringName(cfg.get("group_destination", ""))
	if destination != &"":
		for actor in cfg.get("group_members", []):
			if RoomsAndDoors.room_of(_actor(actor)) != destination:
				return
	var door: Dictionary = RoomsAndDoors.get_door(id)
	if bool(door.get("blocked", false)):
		return
	if int(door.get("state", -1)) != RAD.DoorState.CLOSED:
		RoomsAndDoors.try_close(id, RoomsAndDoors.HOUSE_ACTOR, {"instant": true})
		return
	_pending_close.erase(id)
	if bool((_configs.get(id, {}) as Dictionary).get("lock_after_clear", false)):
		RoomsAndDoors.set_policy_door_state(id, RAD.DoorState.CLOSED, true)


func _on_door_state_changed(id: StringName, _door: Dictionary) -> void:
	if _server() and _pending_close.has(id):
		_close_after_clear(id)


func _on_occupant_changed(actor: StringName, from: StringName, destination: StringName) -> void:
	if not _server():
		return
	for id in RoomsAndDoors.doors_between(from, destination):
		if _configs.has(id):
			_claim_reward(id, actor)
	for id in _pending_close.keys():
		_close_after_clear(id)


func _body_dimensions(actor: StringName) -> Vector2:
	var body := RoomsAndDoors.character_body(actor)
	if body == null:
		return Vector2(0.6, 1.8)
	if body.has_meta(&"body_width") and body.has_meta(&"body_height"):
		return Vector2(float(body.get_meta(&"body_width")), float(body.get_meta(&"body_height")))
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = (child as CollisionShape3D).shape
			var world_scale: Vector3 = (child as CollisionShape3D).global_basis.get_scale().abs()
			if shape is CapsuleShape3D:
				return Vector2((shape as CapsuleShape3D).radius * 2.0 * maxf(world_scale.x, world_scale.z), (shape as CapsuleShape3D).height * world_scale.y)
			if shape is BoxShape3D:
				var size := (shape as BoxShape3D).size * world_scale
				return Vector2(maxf(size.x, size.z), size.y)
	return Vector2(0.6, 1.8)


func _result(ok: bool, reason: StringName = &"ok", extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": ok, "reason": reason}
	result.merge(extra)
	return result
