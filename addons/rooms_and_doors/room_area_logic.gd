class_name RoomAreaLogic
extends RefCounted
## Dimension-agnostic occupancy logic for RoomArea / RoomArea2D.


static func cfg(room_id: StringName, display_name: String, privacy: int, owner_id: StringName,
		residents: PackedStringArray, ambient: float) -> Dictionary:
	return {
		"id": room_id,
		"display_name": display_name if display_name != "" else String(room_id),
		"privacy": privacy,
		"owner_id": owner_id,
		"residents": Array(residents),
		"ambient_noise": ambient,
	}


static func on_enter(room_id: StringName, body: Node) -> void:
	var cid: StringName = RoomsAndDoors.character_id_for_body(body)
	if cid != &"":
		RoomsAndDoors.set_occupant_room(cid, room_id)


## Rooms usually tile the walkable space, so leaving one is implied by entering the
## next and a body crossing a seam is never "nowhere". With clear_on_exit (rooms with
## gaps between them), the character is cleared if still recorded here.
static func on_exit(room_id: StringName, body: Node, clear_on_exit: bool = false) -> void:
	if not clear_on_exit:
		return
	var cid: StringName = RoomsAndDoors.character_id_for_body(body)
	if cid != &"" and RoomsAndDoors.room_of(cid) == room_id:
		RoomsAndDoors.set_occupant_room(cid, &"")
