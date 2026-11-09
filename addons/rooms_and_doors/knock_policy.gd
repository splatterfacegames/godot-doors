class_name KnockPolicy
extends Resource
## How a room owner answers knocks and announcements (§9). Assign per owner with
## `RoomsAndDoors.set_knock_policy(owner_id, policy)`; owners without one use the default.

## Response delay range, seconds of simulation time.
@export var response_delay_min: float = 0.8
@export var response_delay_max: float = 2.0
## Social hours (clock hours, [start, end)). Outside them uninvited knocks get silence.
@export var social_hour_start: float = 10.0
@export var social_hour_end: float = 20.0
## Minimum admission (RAD.Admission) that earns "come in".
@export var admit_min_admission: int = RAD.Admission.INVITED
## Servants announcing while ON_DUTY are admitted (§9 default).
@export var admit_announce_on_duty: bool = true
## Response to an uninvited knock during social hours.
@export var uninvited_social_response: StringName = RAD.RESPONSE_WAIT
## How long a "come in" lets the actor pass the door, seconds.
@export var come_in_pass_seconds: float = 10.0
## After "wait", knocks before this many seconds get no response.
@export var wait_retry_seconds: float = 5.0
## Owners answer only while awake. Turn off for a light sleeper who calls out.
@export var silent_when_asleep: bool = true


## Pure decision. `ctx` = { owner_present, owner_asleep, admission, announce,
## announce_on_duty, hour }. Returns a RAD.RESPONSE_* StringName.
func decide(ctx: Dictionary) -> StringName:
	if not ctx.get("owner_present", false):
		return RAD.RESPONSE_SILENCE
	if ctx.get("owner_asleep", false) and silent_when_asleep:
		return RAD.RESPONSE_SILENCE
	if ctx.get("announce", false) and ctx.get("announce_on_duty", false) and admit_announce_on_duty:
		return RAD.RESPONSE_COME_IN
	if int(ctx.get("admission", RAD.Admission.NONE)) >= admit_min_admission:
		return RAD.RESPONSE_COME_IN
	if is_social_hour(float(ctx.get("hour", 12.0))):
		return uninvited_social_response
	return RAD.RESPONSE_SILENCE


func is_social_hour(hour: float) -> bool:
	if social_hour_start <= social_hour_end:
		return hour >= social_hour_start and hour < social_hour_end
	return hour >= social_hour_start or hour < social_hour_end


func pick_delay(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(response_delay_min, response_delay_max)
