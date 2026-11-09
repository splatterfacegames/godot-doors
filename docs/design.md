# Rooms and Doors — design

Status: implemented in this repository (`addons/rooms_and_doors`). Godot 4.7 / GDScript. No external addons.

This is the design the addon was built from. Section numbers are referenced from the code. Where the implementation had to choose, the choice is listed in the README under "Choices made where the design was open".

## 1. Why this system exists

In social-stealth and manor games a door is not level dressing. It is simultaneously:

- a **movement gate** (who may pass, when, how loudly);
- an **information gate** (what can be heard/seen through it — secrets are core content);
- a **social instrument** (knocking, announcing, being admitted, being discovered);
- a **content gate** (private conversations, restricted scenes, and distribution-cut
  fade-to-black all trigger on door state).

A single source of truth for door/room state is therefore mandatory. No script may
track "is this door open" locally; everything queries the `RoomsAndDoors` autoload.

## 2. Terminology

- **Room**: a named, bounded space with privacy and access rules. A corridor, a garden,
  and "outside the manor" are also rooms (privacy differs; the abstraction must not).
- **Door**: a connection between exactly two rooms (or a room and `null` for exit-to-
  exterior doors that despawn/zone-transition; treat exterior as a room named `@outside`).
- **Occupant**: a character node currently registered inside a room.
- **Witness**: a character who can hear or see an event, computed per §8 — never
  hand-authored per scene.
- **Admission**: the social state of being expected in a room (invited, on duty,
  resident) vs. merely physically present. Presence without admission is trespass.

## 3. Data model

All state lives in the autoload as Dictionaries keyed by StringName ids, mirrored to
save data (§12). Scenes declare static configuration via exported properties; runtime
state is never stored on the scene as the authority (scenes read it back from the
autoload on `_ready`).

### 3.1 Room record

```gdscript
{
  "id": StringName,              # "manor/study"
  "display_name": String,
  "privacy": int,                # Privacy enum, §4.1
  "owner_id": StringName,        # character id with authority here, "" if none
  "ambient_noise": float,        # 0.0 silent .. 1.0 masked (kitchen, ballroom)
  "occupants": Array[StringName] # maintained by autoload only
}
```

### 3.2 Door record

```gdscript
{
  "id": StringName,              # "manor/study_hall_door"
  "room_a": StringName, "room_b": StringName,
  "state": int,                  # DoorState enum, §6.1
  "locked": bool,                # lock engaged (independent of open/closed)
  "key_id": StringName,          # "" = no lock / lock not keyed
  "sound_level": float,          # noise this door emits on use (creaky > oiled)
  "hearing_factor": float,       # 0.0 soundproof .. 1.0 paper wall, when CLOSED
  "sight_factor": float,         # keyhole/gap sight when CLOSED (usually ~0)
  "ajar_hearing_bonus": float,   # added hearing_factor while AJAR
  "held_by": StringName          # character holding it open, "" if none
}
```

## 4. Rooms

### 4.1 Privacy levels (enum `Privacy`)

`PUBLIC` (hall, shop) · `HOUSEHOLD` (servants' hall, kitchen — staff expected, family
by right) · `FAMILY` (drawing room, dining room) · `PRIVATE` (bedrooms, study — knock
required) · `INTIMATE` (bedroom at night, bath, small private booth — discovery here
is an event, not an inconvenience) · `SEALED` (vault, shrine — nobody is ever admitted
casually; used for hard gating).

Privacy is *contextual*: a room's effective privacy may be raised by one level at night
or while occupied by its owner (`PER-GAME` table; implement as
`effective_privacy(room, ctx)` with `ctx = { "night": bool }`, default rules shipped:
PRIVATE→INTIMATE at night when occupied).

### 4.2 Room nodes in scenes

A `RoomArea` (Area3D or Area2D, `PER-GAME` per project dimensionality — implement the
3D variant first; keep logic dimension-agnostic) with exported `room_id`. On body
entered/exited of a registered character it calls
`RoomsAndDoors.set_occupant_room(character_id, room_id_or_empty)`. Characters also
register a fallback room on teleport/zone load. Stairwells and multi-floor spaces are
separate rooms joined by doors (including "door" = stair opening; a stair door may be
modelled with `sight_factor > 0`).

### 4.3 Room queries the games will make

`occupants(room)`, `is_alone(char)`, `others_present(char)`,
`can_witness(event_room, event) -> Array[witness ids]` (§8), `rooms_adjacent(room)`,
`path_exists(from, to, for_character)` respecting doors that character may pass.

### 4.4 Simulation residency (do not aggressively cull)

A manor game will be tempted to simulate only the room the player character is
in and freeze or unload everything else. **Do not do this here.** Secrets, schedules,
private scenes, and discovery all depend on the house continuing to live around the
player. Residency is tiered by door-graph distance from the player's current room:

- **Tier 0 — player room:** full simulation (physics, animation, AI, audio).
- **Tier 1 — every room adjoining the player room (one door away):** fully resident
  and running. NPCs continue conversations, activities, timers, and movement; they
  may knock, enter, leave, discover ajar doors, and finish private scenes on schedule.
  *This ring is mandatory, not optional.* Most discovery and overhearing in these
  games happens across exactly one door.
- **Tier 2 — two doors away:** simulated at reduced fidelity. NPC logic, schedules,
  conversations (as loudness/participant events, §8), and scene timers continue;
  physics and per-frame animation may sleep. Occupancy and witness resolution stay
  exact — a Tier 2 event must still produce correct `witnesses_of` results if a door
  opens toward Tier 1/0.
- **Tier 3 — three or more doors away:** abstract. Clocks, schedules, and long timers
  advance; no per-agent logic. Rooms promote instantly when the player (or a Tier 1
  door opening) brings them closer. Promotion must be seamless: an NPC mid-conversation
  in Tier 3 resumes in Tier 2/1 with correct participants, room, and elapsed time.

Rules that follow from this:

- Door state changes are simulation events at every tier. An NPC in Tier 1 opening a
  door is audible in Tier 0 per §8 even if the player never sees it.
- A private scene in Tier 1/2 runs to its scheduled end whether or not the player is
  present; if the player arrives mid-scene, the scene is *joined in progress* with
  correct elapsed state, never restarted.
- Witness and gossip systems consume Tier 1–2 events identically to Tier 0 events.
  "The player was not there" must never mean "it did not happen".
- Performance budget is spent by reducing Tier 2 fidelity and Tier 3 abstraction —
  never by shrinking the Tier 1 ring. If profiling forces a choice, shrink Tier 2.

Autoload additions: `simulation_tier(room_id) -> int`,
`resident_rooms() -> Array[StringName]` (Tiers 0–1), and signal
`room_tier_changed(room_id, tier)`.

## 5. Autoload API (`RoomsAndDoors`)

Required public surface (implement all; names are contractual):

```gdscript
register_room(cfg: Dictionary) -> void
register_door(cfg: Dictionary) -> void
register_character(character_id: StringName, body: Node) -> void
set_occupant_room(character_id: StringName, room_id: StringName) -> void

get_door(door_id) -> Dictionary            # copy; mutate only via methods below
try_open(door_id, actor_id, opts := {}) -> Result   # opts: {quiet: bool, force: bool}
try_close(door_id, actor_id, opts := {}) -> Result
set_ajar(door_id, actor_id) -> Result
try_lock(door_id, actor_id) -> Result      # requires key or being on the locking side
try_unlock(door_id, actor_id) -> Result
knock(door_id, actor_id) -> void           # emits; response policy per §9
hold_open(door_id, actor_id) / release_hold(door_id, actor_id)

has_key(character_id, key_id) -> bool
grant_key(character_id, key_id) / revoke_key(character_id, key_id)
may_pass(character_id, door_id) -> PassCheck   # {ok, reason} — pure, no side effects
admission(character_id, room_id) -> Admission  # RESIDENT/INVITED/ON_DUTY/NONE (§7.2)

hear_check(listener_id, source_room, loudness: float) -> HearResult  # §8
sight_check(viewer_id, target_room, through_door_id) -> SightResult  # §8
witnesses_of(room_id, loudness) -> Array[StringName]

request_fade_to_black(reason: StringName, payload := {}) -> void  # §11
save_state() -> Dictionary
load_state(data: Dictionary) -> void
```

`Result` = `{ "ok": bool, "reason": StringName, "door": Dictionary }` with reason in
`OK, LOCKED, BLOCKED, NO_KEY, TRESPASS_DENIED, HELD, JAMMED, NO_SUCH_DOOR`.

## 6. Doors

### 6.1 States (enum `DoorState`)

`CLOSED` · `AJAR` · `OPEN` · plus flags rather than states: `locked`, `held`,
`blocked` (body/object in the swing — never allow close to complete into a body;
auto-revert to AJAR and emit `door_blocked`).

Transition rules:

- CLOSED →(open)→ OPEN, passing through an AJAR instant for audio/anim hooks
  (implement as immediate AJAR event then OPEN after `swing_time`, default 0.35s,
  skippable in tests with `instant=true`).
- Any state →(set_ajar)→ AJAR: the eavesdropper's state. Hearing uses
  `hearing_factor + ajar_hearing_bonus`; sight uses keyhole rules (§8.2).
- OPEN doors transmit sound/sight fully between their two rooms (treat the pair as
  one acoustic space for `witnesses_of`).
- Locking requires CLOSED. Unlocking does not open. A locked door's `try_open` fails
  `LOCKED` unless `force` (force emits high noise and `door_forced`).
- Doors auto-close: `PER-GAME` (manor doors close behind family, servants close all
  doors; default: doors stay as left, except INTIMATE rooms' doors auto-close after
  4s unheld — the house protects its secrets).

### 6.2 Door scene

`Door.tscn`: StaticBody (blocking when CLOSED/AJAR — AJAR blocks bodies but not
sound/sight), an `Interactable` prompt, AnimationPlayer with `open/close/ajar/knock`
animations (placeholder clips acceptable), AudioStreamPlayer3D for creak/knock/latch.
The script is a thin view: it renders state from the autoload and forwards interactions
to it. It must work with placeholder art (a labelled box) — no art dependency.

### 6.3 Noise

Every door action emits noise into both adjacent rooms:
`noise = sound_level * (quiet ? 0.25 : 1.0) * (force ? 3.0 : 1.0)`. Noise is consumed
by §8 (who heard that?) and by NPC alertness (§10). Oiling/maintenance may lower a
door's `sound_level` (`PER-GAME` hook: `set_door_sound_level`).

## 7. Keys, locks, admission

### 7.1 Keys

Keys are ids, not physics items by default. Characters hold key ids in the autoload
keyring. Key *items* in the world (the steward's keyring object) are interactables
that grant ids on pickup and revoke on put-down (`PER-GAME` whether putting down is
modelled; default: pickup only). Master keys: a key id may be registered with
`opens: Array[StringName]` of key_ids it substitutes for (housekeeper's passkey opens
all `manor/*` locks — implement via prefix or explicit list; explicit list required,
no magic matching).

### 7.2 Admission (social access, separate from physical access)

A character may physically enter many rooms they are not admitted to. Admission is
computed, in priority order: room owner → RESIDENT; invited-by-owner flag (set via
`set_invitation(character, room, by_whom)`, expires `PER-GAME`, default: until dawn) →
INVITED; role-based duty table (a servant is ON_DUTY in all HOUSEHOLD rooms + rooms on their
chore list; the whole point of chores is they manufacture ON_DUTY in PRIVATE rooms for
bounded windows) → ON_DUTY during duty window; else NONE.

Consequences hang off admission, not presence: being *found* present with admission
NONE in PRIVATE+ is a discovery event (§10); with ON_DUTY it is invisible — the house
does not see its staff. This single rule powers servant-protagonist games; implement it carefully.

### 7.3 Chores as access

`set_duty(character, room, window)` grants ON_DUTY for a time/task window. Duty also
sets an expected-duration; lingering `> 2x` expected duration decays admission to NONE
(the other servants notice). Expose `duty_remaining(character, room)`.

## 8. Hearing, sight, witnesses

### 8.1 Hearing

An event has `loudness` 0..1 (whisper 0.15, conversation 0.4, argument 0.7, scream 1.0;
multi-occupant room activity: `PER-GAME` table, default conversation-to-argument
band) and a source room.

Effective loudness at a listener =
`loudness * product(hearing_factors along the door path) - ambient_noise(listener_room)`,
where the path is the shortest door path between rooms (BFS over the door graph, cap
depth 3; OPEN doors factor 1.0, AJAR uses boosted factor, CLOSED uses base factor).
If effective > `hear_threshold` (default 0.08, per-character alertness modifier),
the listener *hears something*; above `identify_threshold` (default 0.35) they can
identify participants/activity class. `HearResult = {heard, identified, participants}`.

Eavesdropping is the deliberate version: a character in `LISTEN` state at a CLOSED/AJAR
door gets threshold × 0.4 and identified participants on success. Listening is itself
detectable from the corridor side (posture) — emit `listening_started/stopped` for NPC
suspicion systems.

### 8.2 Sight

Through CLOSED doors: only if `sight_factor > 0` (keyhole/gap) and viewer is in PEEK
state: returns `GLIMPSE` (activity class, no identities unless prolonged — accumulate
peek time; identity at > 2.5s, `PER-GAME`). Through AJAR: partial view cone — implement
as a narrow RayCast/shape from the door gap; success returns occupants in cone.
Through OPEN: normal game visibility (this system only reports room-level presence).

### 8.3 Witness resolution

`witnesses_of(room, loudness)` = all characters for whom `hear_check` succeeds, plus
occupants of the room itself. Content scripts must call this instead of inventing
witnesses. Every discovery, gossip, and social-proof system downstream consumes this
list. Emit `witness_gained(event_id, witness_id)` for logging/debug.

## 9. Knocking and announcement

`knock(door, actor)` emits `door_knocked(door_id, actor_id, room_id)`. Response is
policy, not hardcode — implement `KnockPolicy` resource per room owner character:

- Default NPC policy: if room occupied by owner and actor admission ≥ INVITED or the
  hour is social → after 0.8–2s, a voice response (`"Come in"` → door unlocks if locked
  and actor may pass for 10s; `"Wait"` → nothing, retry allowed after 5s; silence if
  owner absent/asleep/`PER-GAME`).
- Player knocking always waits for a response state; never auto-open a PRIVATE+ door.
- Not knocking and entering PRIVATE+ with admission NONE is trespass and is logged
  (`trespass_committed`) even if unseen — saves may be examined by in-fiction inquiry.
- Servants announce: an ON_DUTY character may `announce` (name + errand) which counts
  as a knock that owners almost always admit during duty windows (policy default).

## 10. NPC behaviour rules

- NPCs pathfind through doors using `may_pass`; if it fails they knock (if they have
  business) or reroute/wait. NPCs never force doors except in scripted events.
- NPCs close doors behind them according to their role's manners (family: PRIVATE+;
  servants: all). NPCs do not walk through AJAR doors without opening them fully
  (and thereby being heard — discovering an AJAR door emits `ajar_discovered(door,
  finder)`, a suspicion hook: *someone left this listening*).
- Discovery: if character A is found by B in a room where A's admission is NONE and
  effective privacy ≥ PRIVATE, emit `discovery(discovered_id, finder_id, room_id,
  context)` where context includes door states used. Games decide consequences;
  this system guarantees the event and its data.
- Sleep: sleeping occupants have hear/identify thresholds × 2.5. Closed INTIMATE room
  + sleeping owner + quiet entry is the system's hardest stealth case and must be
  covered by a test.

## 11. Content hooks (fade-to-black, scene gating)

- `request_fade_to_black(reason, payload)`: the autoload arbitrates — only one fade at
  a time; emits `fade_started/fade_ended`. Restricted scenes declare their door
  preconditions instead of checking manually: scene definitions carry
  `requires = { door_state: CLOSED, locked: true, room_privacy_min: PRIVATE }` and call
  `RoomsAndDoors.scene_preconditions_met(scene_id, room_id) -> {ok, unmet: Array}`.
- Cut and full builds share this surface: in fade builds, a met-precondition
  scene request resolves to fade + summary state changes; in full builds it resolves
  to the scene. Door logic is identical in both — build flag
  `ProjectSettings "rooms_and_doors/content/fade_to_black"` selects the resolver.
- XP/stat hooks stay out of this system: games subscribe to `door_used`,
  `discovery`, `witness_gained`, and scene-resolution signals and award their own
  stats (e.g. a private-scene risk score computed from privacy level + witness count +
  door state at scene start — all available from this API).

## 12. Save/load

`save_state()` returns versioned data: door states/locks, keyrings, invitations,
duty windows, occupant rooms, trespass log, and per-door sound levels. `load_state`
must tolerate missing keys (forward-compat) and rebind scene Door/Room nodes by id on
registration (scenes re-register on load, then autoload pushes state into them).
Save version constant `SAVE_VERSION = 1`; bump on schema change with a migration note.

## 13. Debug and acceptance

Debug overlay (toggle `rooms_and_doors/debug/overlay`): draws room graph, door states, current
witnesses-of-player-room, and a live event log (last 20 system signals).

Acceptance test scene (`tests/doors_test.tscn`) must demonstrate, scripted end-to-end:

1. Locked study door denies the son (NO_KEY), admits the housekeeper (passkey),
   admits the maid only during her chore duty window, denies her after it expires.
2. Conversation in the study is heard-but-not-identified in the corridor through the
   CLOSED door, identified when the door is AJAR, and identified by a LISTEN-state
   eavesdropper at the closed door.
3. Keyhole peek returns GLIMPSE, and identity after prolonged peek.
4. Knock protocol: owner answers INVITED guest, ignores/silences an uninvited one,
   and a servant's announce is admitted during duty.
5. Discovery fires with correct context when the maid is found in the INTIMATE room
   with admission NONE, and does **not** fire while she is ON_DUTY.
6. Fade-to-black precondition check fails on an AJAR door and passes when CLOSED+locked.
7. Save → quit → load reproduces all door states, keyrings, and an active invitation.
8. NPC pathing: an NPC reroutes or knocks at a locked door, never clips through it,
   and discovers (event, not collision) an AJAR door left by the player.
9. Residency: with the player in the corridor, an NPC conversation in the adjoining
   room (Tier 1) starts, is overheard per §8, and finishes on schedule; a private
   scene two rooms away (Tier 2) advances and, when the player enters mid-scene, is
   found in progress with correct elapsed state. `resident_rooms()` always includes
   the full Tier 1 ring.

## 14. Genre notes

- **Servant protagonists** are the reference consumer: chores-as-access (§7.3), listening,
  discovery, the most private rooms, and content gating. If a feature seems over-built,
  it is load-bearing here.
- **Court and fantasy**: dais and bolted-door scenes, watchers at ajar doors; admission
  maps to rank; SEALED for shrine and vault content.
- **Patrons and city games**: doors are wealth theatre: who knocks, who is announced,
  who walks in. A visitor's problem is the inverse of a servant's: being *seen* entering.
  Use witness resolution for reputation meters.

## 15. Implementation order

1. Autoload + records + save/load (no visuals).
2. Door scene (placeholder art) + interact + states/noise.
3. Room areas + occupancy + witness resolution + debug overlay.
4. Keys/admission/duty + knock policy.
5. NPC door behaviour + discovery events.
6. Content hooks + test scene; pass §13.
