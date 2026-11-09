class_name RAD
extends RefCounted
## Shared enums, reason codes and record helpers for the rooms & doors system.
## The autoload (`RoomsAndDoors`) is the only authority on state; this file only
## holds types so scenes and game code can reference them without the autoload.

enum Privacy { PUBLIC, HOUSEHOLD, FAMILY, PRIVATE, INTIMATE, SEALED }
enum DoorState { CLOSED, AJAR, OPEN }
## Ordered: higher value = stronger social claim to be in a room.
enum Admission { NONE, ON_DUTY, INVITED, RESIDENT }
## Character posture relevant to this system.
enum Posture { NORMAL, LISTEN, PEEK }
enum Tier { PLAYER = 0, ADJACENT = 1, REDUCED = 2, ABSTRACT = 3 }

## Result reasons (§5). BLOCKED is also returned by try_lock when the door is not CLOSED.
const OK := &"OK"
const LOCKED := &"LOCKED"
const BLOCKED := &"BLOCKED"
const NO_KEY := &"NO_KEY"
const TRESPASS_DENIED := &"TRESPASS_DENIED"
const HELD := &"HELD"
const JAMMED := &"JAMMED"
const NO_SUCH_DOOR := &"NO_SUCH_DOOR"

## Sight levels (§8.2).
const SIGHT_NONE := &"NONE"
const SIGHT_GLIMPSE := &"GLIMPSE"
const SIGHT_PARTIAL := &"PARTIAL"
const SIGHT_FULL := &"FULL"

## Knock responses (§9).
const RESPONSE_COME_IN := &"come_in"
const RESPONSE_WAIT := &"wait"
const RESPONSE_SILENCE := &"silence"

## Reference loudness values (§8.1).
const LOUD_WHISPER := 0.15
const LOUD_CONVERSATION := 0.4
const LOUD_ARGUMENT := 0.7
const LOUD_SCREAM := 1.0

const OUTSIDE := &"@outside"


static func result(ok: bool, reason: StringName, door: Dictionary = {}) -> Dictionary:
	return { "ok": ok, "reason": reason, "door": door }


static func pass_check(ok: bool, reason: StringName) -> Dictionary:
	return { "ok": ok, "reason": reason }


static func door_state_name(state: int) -> StringName:
	match state:
		DoorState.CLOSED: return &"CLOSED"
		DoorState.AJAR: return &"AJAR"
		DoorState.OPEN: return &"OPEN"
	return &"?"


static func privacy_name(p: int) -> StringName:
	return StringName(Privacy.keys()[clampi(p, 0, Privacy.size() - 1)])


static func admission_name(a: int) -> StringName:
	return StringName(Admission.keys()[clampi(a, 0, Admission.size() - 1)])
