godot-doors v0.2.0 adds the twelve-station Door Lab alongside Ashcombe House.

The lab demonstrates manual/proximity doors, decorative and sealed entrances,
key/puzzle/hack/story gates, directional and view-only passages, two local players,
group closure and wait/teleport policies, clearance, queued allies, hidden
reinforcements, objectives, earned rewards and timed access. It includes English
and Japanese experiments and native LAN host/join with authoritative door state.

The optional `DoorPolicies` and `DoorNetwork` nodes extend the dependency-free
addon. Existing projects retain their original behavior without those nodes.
Door geometry now scales its physical sensors, and repeated proximity requests
preserve the opening animation's completion time.

The site also hosts the captioned 78-second satire, with 40 seconds generated using
MiniMax H3 through ai&, plus actual gameplay and an attributed von Neumann quote.

- `rooms_and_doors-addon.zip`: copy `addons/rooms_and_doors` into a project and add the
  `RoomsAndDoors` autoload. It has no dependencies.
- `ashcombe-house-linux-x86_64.zip`, `ashcombe-house-windows-x86_64.zip`: the demo.
- `ashcombe-house-web.zip`: the web build, played at https://doorproblem.splatterfacegames.com/play/

See the README for what the system does and how the demo uses it.
