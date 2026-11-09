class_name RoomArea2D
extends Area2D
## 2D variant of RoomArea (§4.2). Same behaviour; see RoomAreaLogic.

@export var room_id: StringName = &""
@export var display_name: String = ""
@export var privacy: RAD.Privacy = RAD.Privacy.PUBLIC
@export var owner_id: StringName = &""
@export var residents: PackedStringArray = []
@export_range(0.0, 1.0) var ambient_noise: float = 0.0
## Clear the character's room when they leave this volume (see RoomAreaLogic.on_exit).
@export var clear_on_exit: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(func(b: Node) -> void: RoomAreaLogic.on_enter(room_id, b))
	body_exited.connect(func(b: Node) -> void: RoomAreaLogic.on_exit(room_id, b, clear_on_exit))
	register_with_system()


func register_with_system() -> void:
	RoomsAndDoors.register_room(RoomAreaLogic.cfg(room_id, display_name, privacy, owner_id, residents, ambient_noise))
