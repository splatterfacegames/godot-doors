class_name RoomArea
extends Area3D
## Room marker/volume (§4.2). Registers its room and reports occupancy of registered
## characters to RoomsAndDoors. Logic shared with RoomArea2D via RoomAreaLogic.

@export var room_id: StringName = &""
@export var display_name: String = ""
@export var privacy: RAD.Privacy = RAD.Privacy.PUBLIC
@export var owner_id: StringName = &""
@export var residents: PackedStringArray = []
@export_range(0.0, 1.0) var ambient_noise: float = 0.0
## Clear the character's room when they leave this volume (see RoomAreaLogic.on_exit).
@export var clear_on_exit: bool = false
## Spawn / fallback position for characters teleported into this room.
@export var anchor: Vector3 = Vector3.ZERO


func _ready() -> void:
	monitoring = true
	body_entered.connect(func(b: Node) -> void: RoomAreaLogic.on_enter(room_id, b))
	body_exited.connect(func(b: Node) -> void: RoomAreaLogic.on_exit(room_id, b, clear_on_exit))
	register_with_system()


func register_with_system() -> void:
	RoomsAndDoors.register_room(RoomAreaLogic.cfg(room_id, display_name, privacy, owner_id, residents, ambient_noise))


func anchor_global() -> Vector3:
	return global_transform * anchor
