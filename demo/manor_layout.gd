class_name ManorLayout
extends RefCounted
## Data for the demo manor ("Ashcombe House", one night). Metres; x east, z south.
## Every door is on a room boundary; rot is the door's yaw so that local +Z
## points into room_b.

const ROOMS := [
	{ "id": &"@outside", "name": "The Drive", "rect": Rect2(-4, -11, 8, 5), "privacy": RAD.Privacy.PUBLIC, "ambient": 0.15, "floor": Color(0.34, 0.36, 0.31), "exterior": true },
	{ "id": &"hall", "name": "Hall", "rect": Rect2(-4, -6, 8, 6), "privacy": RAD.Privacy.PUBLIC, "ambient": 0.05, "floor": Color(0.61, 0.55, 0.49) },
	{ "id": &"kitchen", "name": "Kitchen", "rect": Rect2(-12, -6, 8, 6), "privacy": RAD.Privacy.HOUSEHOLD, "ambient": 0.3, "owner": &"cook", "floor": Color(0.55, 0.49, 0.40) },
	{ "id": &"study", "name": "Study", "rect": Rect2(4, -6, 8, 6), "privacy": RAD.Privacy.PRIVATE, "ambient": 0.0, "owner": &"lord", "floor": Color(0.45, 0.31, 0.24) },
	{ "id": &"gallery", "name": "Gallery", "rect": Rect2(-12, 0, 25, 3), "privacy": RAD.Privacy.FAMILY, "ambient": 0.0, "floor": Color(0.51, 0.40, 0.34) },
	{ "id": &"library", "name": "Library", "rect": Rect2(-12, 3, 10, 7), "privacy": RAD.Privacy.FAMILY, "ambient": 0.0, "owner": &"lord", "floor": Color(0.40, 0.34, 0.31) },
	{ "id": &"backstair", "name": "Back Stair", "rect": Rect2(-2, 3, 4, 7), "privacy": RAD.Privacy.HOUSEHOLD, "ambient": 0.0, "floor": Color(0.45, 0.43, 0.40) },
	{ "id": &"bedchamber", "name": "Bedchamber", "rect": Rect2(2, 3, 8, 7), "privacy": RAD.Privacy.PRIVATE, "ambient": 0.0, "owner": &"lady", "floor": Color(0.49, 0.36, 0.40) },
	{ "id": &"dressing", "name": "Dressing Room", "rect": Rect2(10, 3, 3, 7), "privacy": RAD.Privacy.PRIVATE, "ambient": 0.0, "owner": &"lady", "floor": Color(0.53, 0.42, 0.45) },
]

## pos is the centre of the opening on the boundary.
const DOORS := [
	{ "id": &"front_door", "a": &"@outside", "b": &"hall", "pos": Vector2(0, -6), "rot": 0.0, "sound": 0.7, "hearing": 0.2, "width": 1.4 },
	{ "id": &"kitchen_hall", "a": &"kitchen", "b": &"hall", "pos": Vector2(-4, -3), "rot": 90.0, "sound": 0.5 },
	{ "id": &"hall_gallery", "a": &"hall", "b": &"gallery", "pos": Vector2(0, 0), "rot": 0.0, "sound": 0.35, "width": 1.4 },
	{ "id": &"kitchen_gallery", "a": &"kitchen", "b": &"gallery", "pos": Vector2(-8, 0), "rot": 0.0, "sound": 0.6, "hearing": 0.35 },
	{ "id": &"study_door", "a": &"study", "b": &"gallery", "pos": Vector2(8, 0), "rot": 0.0, "sound": 0.45, "hearing": 0.3, "sight": 0.2, "key": &"study_key", "locked": false },
	{ "id": &"library_door", "a": &"gallery", "b": &"library", "pos": Vector2(-7, 3), "rot": 0.0, "sound": 0.4 },
	{ "id": &"backstair_door", "a": &"gallery", "b": &"backstair", "pos": Vector2(0, 3), "rot": 0.0, "sound": 0.2 },
	{ "id": &"library_backstair", "a": &"library", "b": &"backstair", "pos": Vector2(-2, 8), "rot": 90.0, "sound": 0.3 },
	{ "id": &"bed_door", "a": &"gallery", "b": &"bedchamber", "pos": Vector2(6, 3), "rot": 0.0, "sound": 0.55, "hearing": 0.3, "sight": 0.15, "key": &"bed_key", "lock_side": &"bedchamber" },
	{ "id": &"jib_door", "a": &"backstair", "b": &"bedchamber", "pos": Vector2(2, 8.5), "rot": 90.0, "sound": 0.35, "hearing": 0.45, "key": &"jib_key", "locked": true },
	{ "id": &"dressing_door", "a": &"bedchamber", "b": &"dressing", "pos": Vector2(10, 6.5), "rot": 90.0, "sound": 0.4, "hearing": 0.35 },
]

## Furniture boxes: room, centre (x, z), size (x, y, z), colour, optional tag.
const FURNITURE := [
	{ "pos": Vector2(8, -4.2), "size": Vector3(2.2, 0.8, 1.0), "color": Color(0.35, 0.2, 0.12), "tag": &"desk" },
	{ "pos": Vector2(11.6, -3), "size": Vector3(0.6, 2.4, 5.0), "color": Color(0.28, 0.17, 0.1) },
	{ "pos": Vector2(-11.6, 6.5), "size": Vector3(0.6, 2.6, 6.0), "color": Color(0.25, 0.15, 0.1) },
	{ "pos": Vector2(-7, 9.6), "size": Vector3(5.0, 2.6, 0.6), "color": Color(0.25, 0.15, 0.1) },
	{ "pos": Vector2(-5, 3.6), "size": Vector3(1.8, 1.2, 0.5), "color": Color(0.3, 0.3, 0.32), "tag": &"hearth" },
	{ "pos": Vector2(-7.5, 6.5), "size": Vector3(1.0, 0.5, 1.0), "color": Color(0.4, 0.15, 0.15), "tag": &"armchair" },
	{ "pos": Vector2(6.5, 7.5), "size": Vector3(2.4, 0.6, 3.0), "color": Color(0.85, 0.82, 0.75), "tag": &"bed" },
	{ "pos": Vector2(3.0, 4.2), "size": Vector3(1.2, 0.8, 0.7), "color": Color(0.4, 0.25, 0.2), "tag": &"writing_desk" },
	{ "pos": Vector2(12.4, 4.8), "size": Vector3(0.9, 2.2, 1.6), "color": Color(0.32, 0.2, 0.18), "tag": &"wardrobe" },
	{ "pos": Vector2(11.5, 8.6), "size": Vector3(1.0, 0.8, 0.6), "color": Color(0.4, 0.28, 0.24), "tag": &"dressing_table" },
	{ "pos": Vector2(-8, -3), "size": Vector3(3.0, 0.9, 1.4), "color": Color(0.55, 0.45, 0.32), "tag": &"kitchen_table" },
	{ "pos": Vector2(-11.5, -4.5), "size": Vector3(0.8, 1.0, 2.5), "color": Color(0.2, 0.2, 0.2), "tag": &"range" },
	{ "pos": Vector2(-4.6, -5.5), "size": Vector3(1.0, 1.9, 0.6), "color": Color(0.45, 0.35, 0.25), "tag": &"dresser" },
	{ "pos": Vector2(-3, -5.5), "size": Vector3(1.2, 2.0, 0.5), "color": Color(0.3, 0.22, 0.15) },
	{ "pos": Vector2(3, -5.5), "size": Vector3(1.2, 2.0, 0.5), "color": Color(0.3, 0.22, 0.15) },
]

## Warm lamps: (x, z), energy.
const LAMPS := [
	[Vector2(0, -3), 1.6], [Vector2(-8, -3), 1.8], [Vector2(8, -3), 1.3], [Vector2(-6, 1.5), 1.0],
	[Vector2(6, 1.5), 1.0], [Vector2(-7, 6.5), 1.2], [Vector2(0, 6.5), 0.4], [Vector2(5, 5), 0.9],
	[Vector2(11.5, 6.5), 0.7], [Vector2(0, -8.5), 0.6],
]

## Named points NPCs walk to: room, (x, z), facing yaw (deg).
const SPOTS := {
	&"lord_desk": [&"study", Vector2(8, -5.3), 180.0],
	&"crane_chair": [&"study", Vector2(7.6, -2.8), 0.0],
	&"study_mid": [&"study", Vector2(6, -2.0), 0.0],
	&"lady_desk": [&"bedchamber", Vector2(3.0, 5.0), 0.0],
	&"lady_bed": [&"bedchamber", Vector2(6.5, 7.5), 0.0],
	&"lady_bedside": [&"bedchamber", Vector2(4.7, 7.5), 90.0],
	&"cook_range": [&"kitchen", Vector2(-10.6, -4.5), 90.0],
	&"cook_table": [&"kitchen", Vector2(-8, -1.8), 180.0],
	&"hall_mid": [&"hall", Vector2(0, -2.5), 0.0],
	&"hall_east": [&"hall", Vector2(2.5, -1.5), 90.0],
	&"gallery_east": [&"gallery", Vector2(10, 1.5), 90.0],
	&"gallery_west": [&"gallery", Vector2(-10, 1.5), 270.0],
	&"gallery_mid": [&"gallery", Vector2(2.5, 1.5), 0.0],
	&"library_chair": [&"library", Vector2(-7.5, 6.5), 0.0],
	&"library_mid": [&"library", Vector2(-6, 6.5), 0.0],
	&"backstair_mid": [&"backstair", Vector2(0, 5.5), 0.0],
	&"drive": [&"@outside", Vector2(0, -9.5), 0.0],
	&"player_start": [&"kitchen", Vector2(-6, -1.5), 0.0],
}

## Interactive props: id, room, (x, z), prompt.
const PROPS := [
	{ "id": &"hearth", "room": &"library", "pos": Vector2(-5, 4.3), "prompt": "Lay the fire", "chore": true },
	{ "id": &"bed", "room": &"bedchamber", "pos": Vector2(6.5, 5.8), "prompt": "Turn down the bed", "chore": true },
	{ "id": &"letter", "room": &"dressing", "pos": Vector2(11.5, 8.0), "prompt": "Read the letter" },
	{ "id": &"jib_key", "room": &"kitchen", "pos": Vector2(-4.9, -4.9), "prompt": "Take the old jib key" },
]


static func spot_position(spot: StringName) -> Vector3:
	var s: Array = SPOTS[spot]
	return Vector3((s[1] as Vector2).x, 0.0, (s[1] as Vector2).y)


static func spot_room(spot: StringName) -> StringName:
	return SPOTS[spot][0]


static func room(id: StringName) -> Dictionary:
	for r in ROOMS:
		if r["id"] == id:
			return r
	return {}


static func door(id: StringName) -> Dictionary:
	for d in DOORS:
		if d["id"] == id:
			return d
	return {}
