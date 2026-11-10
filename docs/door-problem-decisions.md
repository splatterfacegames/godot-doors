# Every doorway needs a decision

This is the implementation companion to [Liz England's original essay](https://lizengland.com/blog/the-door-problem/).
The numbered entries follow the 22 bullets in its first section, in order. They describe
this project's choices and the code that makes them happen. The essay offers alternative
designs; the lab lets you try different policies rather than pretending every game should
choose the same one.

Launch **Door Lab** from the Ashcombe House title screen. It contains twelve interactive
experiments with real bodies, colliders and authoritative door state. The manor remains
the narrative example. `DoorPolicies` is optional: projects copying only the original
addon keep its existing behavior.

## Gameplay decisions

| Original bullet | This project's implementation |
| --- | --- |
| 1 — Presence | The manor generates doors from `demo/manor_layout.gd`; the lab generates the current experiment. Both instantiate `Door.tscn`. |
| 2 — Interaction | `Door.interact` forwards verbs to `RoomsAndDoors`; the manor uses E, and lab controls expose the configured opening policy. |
| 3 — Access | Access varies per door and actor. Core keys, duties and invitations combine with policy gates and body clearance. |
| 4 — Decoration | `mode=decorative` preserves a solid panel and rejects opening. It does not impersonate a locked door that can later be unlocked. |
| 5 — Readability | The lab distinguishes usable, decorative and permanently sealed entrances with panel treatments, framing, status text and hints. |
| 6 — Cues | Green interactive panels, blank decorative insets and braced sealed panels have different silhouettes as well as colors. The UI provides text so color is not the only cue. |
| 7 — Locks | Core `try_lock` / `try_unlock` enforce key ownership, lock side and closed state; the manor demonstrates a passkey and a bolted bedroom. |
| 8 — Permanence | `mode=sealed` stays closed and advertises permanent closure; a locked interactive door retains an unlock hint and a future access path. |
| 9 — Unlocking | The lab supplies a collectable key, a switch-sequence puzzle, a timed hack and a story interaction. Each completes a real gate through `unlock_gate`; it does not merely change a label. |
| 10 — Nontraversable opening | `visual_only` permits a visible opening while retaining a body barrier. `open_only` permits traversal but rejects closing. These are separate policies. |
| 11 — Arrival | The reinforcement director rejects visible or occupied candidate entrances, opens an eligible entrance and spawns an actor. No eligible entrance means no spawn. |
| 12 — Trigger | Manual and proximity variants drive the same hinged door. `trigger` controls which request is accepted. |
| 13 — Closure | The manor's role/privacy rules close doors. Lab policies additionally close and lock after the tracked crossing group clears the threshold. |
| 14 — Group timing | The threshold tracks individual bodies. One participant leaving does not release a group-close action while another is still crossing. |
| 15 — Residency | Multiple registered players seed room residency. `can_unload_room` prevents unloading an occupied player room; the lab shows the split-room result live. The small demo retains its geometry and does not stream chunks out. |
| 16 — Regrouping | The wait policy delays a group transition until the members are ready; the lab displays the pending result. |
| 17 — Catch-up | The teleport alternative emits transitions for the group, and the lab moves the actual bodies and updates each player's room. |
| 18 — Dimensions | `Door.width` and `height` size the panel, blocker and interaction geometry; policy clearance uses matching dimensions in metres. |
| 19 — Player fit | The regular mannequin fits the regular opening. The size experiment changes both the body and the clearance request. |
| 20 — Blocking | Real body collisions prevent participants occupying the same space, and the swing sensor blocks a closing door. The obstruction experiment includes a movable blocking prop. |
| 21 — Followers | A doorway reservation and FIFO queue serialize allies through the threshold; cancellation and completion release reservations. The lab sends three visible allies through. |
| 22 — Large actors | The oversized mannequin fails the narrow entrance and can use a wide variant. Body dimensions are checked independently of access permission. |

## The rest of the team

The second section of the essay assigns work across 36 roles. This table preserves that
order, but records our own artifacts and product decisions rather than reproducing the
essay's jokes. Some decisions deliberately exclude a feature: an MIT example has no
preorder business model, for example. That is a product choice, not an unimplemented
payment backend.

| Role | Concrete answer in this project |
| --- | --- |
| Creative director | A social-stealth manor establishes the purpose: doors control access and information. The lab exposes reusable alternatives. |
| Project manager | The source tree separates addon, demo, site and release workflows; the decision list above defines the functional scope. |
| Designer | Per-door configuration selects interaction, access, traversal, group behavior and rewards. |
| Concept artist | The lab's inset, braced and usable treatments are procedural reference designs that work without external image assets. |
| Art director | Manor amber and muted wood contrast with the lab's teal/orange participants and clear doorway silhouettes. |
| Environment artist | `ManorBuilder` generates frames and openings from layout data; `Door` resizes its own geometry. |
| Animator | Hinge clips and knock motion are procedural; mannequins have walking, knocking, listening, peeking, work and rest poses. |
| Sound designer | Generated creak, knock and latch streams ship with the addon, with exported replacements for authored assets. |
| Audio engineer | `AudioStreamPlayer3D` provides positional playback; the room graph determines gameplay hearing through closed, ajar and open doors. |
| Composer | The satire video ships an original synthesized score. The playable example deliberately uses environmental door sound without a musical theme. |
| FX artist | Live state labels, colored doorway treatments and an objective marker provide the demo's feedback. Sparks and combat explosions are outside this example's art direction. |
| Writer | Ashcombe House's overheard conversation and hidden letter depend on the same access and hearing rules as movement. |
| Lighter | Procedural environment lighting keeps frames and door panels visible; locked and usable conditions also have textual feedback. |
| Legal | The project is MIT; third-party addons and font licenses are credited. No trademarked door textures are supplied. |
| Character artist | Procedural jointed mannequins have role accents and variable scale; the clearance experiment changes the physical body as well as its appearance. |
| Gameplay programmer | `RoomsAndDoors` owns door state; `DoorPolicies` supplies optional gameplay rules; views forward requests. |
| AI programmer | The manor uses room-graph planning and per-room navigation meshes. Threshold reservations handle doorway contention. |
| Network programmer | Optional server authority validates actor-owned requests and replicates door state. Native lab host/join demonstrates the transport; the web lab remains local. |
| Release engineer | GitHub Actions exports web, Linux and Windows on release tags and deploys the website from main. |
| Core engine programmer | Room-door adjacency indexes bound graph traversal; the demo tiers simulation by distance. No unsupported claim of a measured thousand-door budget is made. |
| Tools programmer | Exported door properties and the layout table author rooms; the lab's station/variant controls make policy changes visible immediately. |
| Level designer | Physical openings match configured widths. The manor places alternate routes and connects story events to access. |
| UI designer | Contextual prompts, objective markers, control instructions and a live event log expose why a door accepts or rejects an action. |
| Combat designer | The reinforcement director chooses an unobserved, unoccupied entrance. The lab demonstrates spawning; it does not add a combat game. |
| Systems designer | Crossing can award XP, coins and items exactly once per actor and door. Progress is stored with policy state. |
| Monetization designer | Earned coins can purchase temporary access. This is an in-game economy demonstration; there are no real-money purchases. |
| QA tester | The existing acceptance scene and manor journey remain in the repo. Physical lab experiments expose obstruction, scale, group timing and state restoration to direct play. |
| UX researcher | The lab makes each alternative playable and explains the expected action. No user study is claimed. |
| Localization | The lab's station titles, descriptions, actions and policy hints have English/Japanese catalogs and a live switch. The manor's narrative UI remains English. |
| Producer | Every shipped door policy is included in the MIT project. No preorder-exclusive entrances. |
| Publisher | Browser play, downloadable desktop builds, screenshots and source are available from the public site. |
| CEO | License, ownership and project scope are explicit; no separate executive simulation is part of a door addon. |
| PR | A captioned satire video accompanies real gameplay and labels generated scenes. It makes no claim to solve every possible game's design. |
| Community manager | The public repository provides the issue channel; changes are published through source history and releases. |
| Customer support | The README explains installation and controls; the lab provides immediate feedback and reset for each experiment. |
| Player | The manor gives doors narrative purpose. The lab provides deliberate inspection when the player wants to understand a policy. |

## Integration

Add one `DoorPolicies` node to the scene after registering rooms and doors. Configure
only the doors that need the additional rules. `RoomsAndDoors` remains the state owner:
policy progress is included in its versioned save data, while doorway occupancy and
reservations are transient physical state.

```gdscript
var policies := DoorPolicies.new()
add_child(policies)
policies.register_player(&"player_one")
policies.register_player(&"player_two")
policies.configure_door(&"archive", {
    "gate_kind": "puzzle", "gate_token": "switches_complete",
    "width": 1.4, "height": 2.5,
    "close_after_clear": true, "lock_after_clear": true,
    "reward": {"xp": 25, "gold": 10},
})
policies.unlock_gate(&"archive", &"puzzle", &"switches_complete")
```

Use physical threshold enter/exit notifications and registered character dimensions for
your own locomotion. The lab is the complete scene-side example. A residency result is a
retention contract for a game's streaming manager; it is not an instruction to delete
rooms containing players. Network authority is optional and does not convert arbitrary
game scripts into a multiplayer game automatically.
