class_name KeyItem
extends Area3D
## World key / keyring object (§7.1). Grants key ids on pickup. Keys themselves are
## ids in the RoomsAndDoors keyring, not physics items.

signal picked_up(character_id: StringName)
signal put_down(character_id: StringName)

@export var key_id: StringName = &""
## Master key: the key ids this key substitutes for (explicit list, no prefix magic).
@export var opens: PackedStringArray = []
## Additional ids granted together (a steward's ring carries several keys).
@export var extra_keys: PackedStringArray = []
## PER-GAME: model putting the key down (revokes ids). Default: pickup only.
@export var model_put_down: bool = false
@export var label: String = "Key"

var holder: StringName = &""


func _ready() -> void:
	register_with_system()
	if get_child_count() == 0:
		_build_placeholder()
	RoomsAndDoors.state_loaded.connect(_sync_from_system)


func register_with_system() -> void:
	if not opens.is_empty():
		RoomsAndDoors.register_key(key_id, Array(opens))


## After a load the keyring is authoritative: whoever holds key_id holds this item.
func _sync_from_system() -> void:
	holder = &""
	for cid in RoomsAndDoors.character_ids():
		if RoomsAndDoors.keyring(cid).has(key_id):
			holder = cid
			break
	visible = holder == &""
	set_deferred(&"monitorable", holder == &"")


func pick_up(character_id: StringName) -> void:
	if holder != &"":
		return
	holder = character_id
	RoomsAndDoors.grant_key(character_id, key_id)
	for k in extra_keys:
		RoomsAndDoors.grant_key(character_id, StringName(k))
	visible = false
	set_deferred(&"monitorable", false)
	picked_up.emit(character_id)


func drop(at: Vector3 = Vector3.INF) -> void:
	if holder == &"" or not model_put_down:
		return
	var who := holder
	RoomsAndDoors.revoke_key(who, key_id)
	for k in extra_keys:
		RoomsAndDoors.revoke_key(who, StringName(k))
	holder = &""
	if at != Vector3.INF:
		global_position = at
	visible = true
	set_deferred(&"monitorable", true)
	put_down.emit(who)


## Interactable protocol.
func interact(actor_id: StringName, _verb: StringName = &"toggle", _opts: Dictionary = {}) -> Dictionary:
	pick_up(actor_id)
	return { "ok": true, "reason": RAD.OK, "door": {} }


func get_prompt(_actor_id: StringName) -> String:
	return "Take %s" % label if holder == &"" else ""


func _build_placeholder() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.04, 0.06)
	mesh.mesh = box
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.5
	shape.shape = s
	add_child(shape)
	var l := Label3D.new()
	l.text = label
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 0.3
	l.font_size = 20
	add_child(l)
