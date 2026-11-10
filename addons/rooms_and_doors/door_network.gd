class_name DoorNetwork
extends Node
## Optional ENet/MultiplayerAPI adapter. Use the same scene path on every peer.
## The host binds authenticated peers to character IDs. Clients request actions;
## only the server changes RoomsAndDoors and sends reliable state snapshots.

signal request_result(result: Dictionary)
signal snapshot_applied()

@export var interaction_distance: float = 3.0
@export var minimum_request_interval: float = 0.08
var _peer_actors: Dictionary = {}
var _last_request: Dictionary = {}
var _snapshot_queued := false
var _since_snapshot := 0.0


func _ready() -> void:
	RoomsAndDoors.door_state_changed.connect(_door_changed)
	RoomsAndDoors.occupant_changed.connect(_occupant_changed)
	RoomsAndDoors.key_granted.connect(_key_changed)
	RoomsAndDoors.key_revoked.connect(_key_changed)
	if not multiplayer.peer_disconnected.is_connected(_peer_disconnected):
		multiplayer.peer_disconnected.connect(_peer_disconnected)
	_connect_policy_signals.call_deferred()


func _connect_policy_signals() -> void:
	var policies := RoomsAndDoors.policy_controller as DoorPolicies
	if policies == null:
		return
	if not policies.progress_changed.is_connected(_progress_changed):
		policies.progress_changed.connect(_progress_changed)
	if not policies.objective_changed.is_connected(_objective_changed):
		policies.objective_changed.connect(_objective_changed)
	if not policies.feedback.is_connected(_feedback):
		policies.feedback.connect(_feedback)


func _process(delta: float) -> void:
	_since_snapshot += delta
	if _since_snapshot >= 1.0:
		_since_snapshot = 0.0
		queue_snapshot()


func bind_peer_actor(peer_id: int, actor: StringName) -> void:
	if not RoomsAndDoors.is_authoritative() or actor == &"":
		return
	for existing_peer in _peer_actors.keys():
		if _peer_actors[existing_peer] == actor and int(existing_peer) != peer_id:
			return
	_peer_actors[peer_id] = actor
	queue_snapshot()


func request_open(id: StringName) -> void:
	_send(&"open", id, &"")


func request_cross(id: StringName, destination: StringName) -> void:
	_send(&"cross", id, destination)


func request_purchase(id: StringName) -> void:
	_send(&"purchase", id, &"")


func request_sync() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		queue_snapshot()
	else:
		_request_sync.rpc_id(1)


func _send(action: StringName, id: StringName, destination: StringName) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var peer := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		request_result.emit(_perform(peer, action, id, destination))
	else:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_request_action.rpc_id(1, action, id, destination)
		else:
			request_result.emit({"ok": false, "reason": &"not_connected"})


@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: StringName, id: StringName, destination: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var result := _perform(sender, action, id, destination)
	_action_result.rpc_id(sender, result)
	queue_snapshot()


func _perform(peer: int, action: StringName, id: StringName, destination: StringName) -> Dictionary:
	if not RoomsAndDoors.is_authoritative():
		return {"ok": false, "reason": &"server_authority"}
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_request.get(peer, -INF)) < minimum_request_interval:
		return {"ok": false, "reason": &"rate_limited"}
	_last_request[peer] = now
	var actor := StringName(_peer_actors.get(peer, ""))
	if actor == &"" or not RoomsAndDoors.character_ids().has(actor):
		return {"ok": false, "reason": &"unbound_peer"}
	var door: Dictionary = RoomsAndDoors.get_door(id)
	if door.is_empty():
		return {"ok": false, "reason": &"no_such_door"}
	if RoomsAndDoors.room_of(actor) not in [StringName(door["room_a"]), StringName(door["room_b"])]:
		return {"ok": false, "reason": &"not_adjacent"}
	var body := RoomsAndDoors.character_body(actor) as Node3D
	var view := RoomsAndDoors.door_view(id) as Node3D
	# Network actions require authoritative physical positions, not client distances.
	if body == null or view == null or body.global_position.distance_to(view.global_position) > interaction_distance:
		return {"ok": false, "reason": &"out_of_range"}
	var policies := RoomsAndDoors.policy_controller as DoorPolicies
	if policies == null:
		return {"ok": false, "reason": &"missing_policies"}
	match action:
		&"open":
			return policies.request_open(id, actor, {"trigger": policies.trigger_for(id)})
		&"purchase":
			return policies.purchase_access(id, actor)
		&"cross":
			if destination == RoomsAndDoors.room_of(actor) or destination not in [StringName(door["room_a"]), StringName(door["room_b"])]:
				return {"ok": false, "reason": &"invalid_destination"}
			if int(door["state"]) != RAD.DoorState.OPEN or bool(door.get("swinging", false)):
				return {"ok": false, "reason": &"closed"}
			var check := policies.check_pass(id, actor)
			if not bool(check["ok"]):
				return check
			RoomsAndDoors.set_occupant_room(actor, destination)
			policies.transition_requested.emit(actor, destination)
			return {"ok": true, "reason": &"ok", "destination": destination}
	return {"ok": false, "reason": &"unsupported_action"}


@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peer_actors.has(sender):
		_apply_snapshot.rpc_id(sender, RoomsAndDoors.save_state())


@rpc("authority", "call_remote", "reliable")
func _apply_snapshot(state: Dictionary) -> void:
	if multiplayer.is_server() or multiplayer.get_remote_sender_id() != 1:
		return
	RoomsAndDoors.load_state(state)
	snapshot_applied.emit()


@rpc("authority", "call_remote", "reliable")
func _action_result(result: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		request_result.emit(result)


func queue_snapshot() -> void:
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or _snapshot_queued:
		return
	_snapshot_queued = true
	_flush_snapshot.call_deferred()


func _flush_snapshot() -> void:
	_snapshot_queued = false
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var state: Dictionary = RoomsAndDoors.save_state()
	for id in RoomsAndDoors.door_ids():
		var door: Dictionary = RoomsAndDoors.get_door(id)
		(state["doors"][String(id)] as Dictionary)["state"] = int(door["state"])
	for peer in _peer_actors:
		if int(peer) != multiplayer.get_unique_id() and multiplayer.get_peers().has(int(peer)):
			_apply_snapshot.rpc_id(int(peer), state)


func _peer_disconnected(peer: int) -> void:
	if not RoomsAndDoors.is_authoritative():
		return
	var actor := StringName(_peer_actors.get(peer, ""))
	_peer_actors.erase(peer)
	_last_request.erase(peer)
	if actor != &"":
		RoomsAndDoors.set_occupant_room(actor, &"", true)
	queue_snapshot()


func _door_changed(_id: StringName, _door: Dictionary) -> void:
	queue_snapshot()


func _occupant_changed(_actor: StringName, _from: StringName, _to: StringName) -> void:
	queue_snapshot()


func _key_changed(_actor: StringName, _key: StringName) -> void:
	queue_snapshot()


func _progress_changed(_actor: StringName, _progress: Dictionary) -> void:
	queue_snapshot()


func _objective_changed(_id: StringName, _active: bool) -> void:
	queue_snapshot()


func _feedback(_text: String) -> void:
	queue_snapshot()
