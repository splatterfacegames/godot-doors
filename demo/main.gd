extends Node3D
## Ashcombe House: the godot-doors demo. Builds the manor, spawns the household,
## and runs the night. F3 toggles the RoomsAndDoors debug overlay.
##
## User args (after `--`):
##   --shots=<dir>   scripted tour that saves screenshots, then quits
##   --smoke         play the night fast with an autopilot, print a summary, quit

const LOOKS := {
	&"lord": { "name": "Lord Ashcombe", "role": &"family", "style": "sash", "accent": Color(0.45, 0.08, 0.1), "body": Color(0.8, 0.72, 0.6), "height": 1.04, "spot": &"lord_desk" },
	&"lady": { "name": "Lady Ashcombe", "role": &"family", "style": "sash", "accent": Color(0.1, 0.38, 0.4), "body": Color(0.9, 0.82, 0.72), "height": 0.96, "spot": &"lady_desk" },
	&"housekeeper": { "name": "Mrs Pell", "role": &"servant", "style": "apron", "accent": Color(0.22, 0.2, 0.24), "body": Color(0.78, 0.7, 0.6), "height": 1.0, "spot": &"hall_mid" },
	&"cook": { "name": "Cook", "role": &"servant", "style": "apron", "accent": Color(0.55, 0.42, 0.25), "body": Color(0.84, 0.74, 0.62), "height": 0.98, "spot": &"cook_range" },
	&"crane": { "name": "Mr Crane", "role": &"guest", "style": "coat", "accent": Color(0.08, 0.08, 0.1), "body": Color(0.76, 0.7, 0.62), "height": 1.02, "spot": &"drive" },
}

var builder := ManorBuilder.new()
var player: ManorPlayer
var hud: ManorHud
var story: ManorStory
var rig: ManorCamera
var npcs: Dictionary = {}
var _args: Dictionary = {}
var _clips: Array = []
var _furniture_frames: int = 0
var _furniture_hits: Dictionary = {}


## Smoke check: an NPC walking (not settling onto a bed or chair at the end of a
## sit/read/sleep task) must never be inside a piece of furniture.
func _count_furniture_walks() -> void:
	for id in npcs:
		var n: ManorNpc = npcs[id]
		if n._waypoints.is_empty():
			continue
		var kind := String(n._task.get("kind", ""))
		if kind in ["sit", "read", "sleep"] and n._waypoints.size() == 1:
			continue
		var p := Vector2(n.global_position.x, n.global_position.z)
		for f in ManorLayout.FURNITURE:
			var half := Vector2((f["size"] as Vector3).x, (f["size"] as Vector3).z) * 0.5 + Vector2(0.12, 0.12)
			var c: Vector2 = f["pos"]
			if absf(p.x - c.x) < half.x and absf(p.y - c.y) < half.y:
				_furniture_frames += 1
				_furniture_hits["%s@%s" % [id, String(f.get("tag", "furniture"))]] = true


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--door-lab") or OS.get_cmdline_user_args().has("--lab-tour"):
		get_tree().change_scene_to_file.call_deferred("res://demo/door_lab.tscn")
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var R := RoomsAndDoors
	R.reset()
	R.manual_clock = false
	R.time_scale = 1.0
	R.start_hour = 21.9
	R.instant_doors = false
	builder.use_navigation = not _args.has("no-nav")
	builder.build(self)
	_spawn_household()
	rig = ManorCamera.new()
	add_child(rig)
	rig.target = player
	rig.walls = builder.walls
	rig.global_position = player.global_position
	hud = ManorHud.new()
	add_child(hud)
	story = ManorStory.new()
	story.main = self
	story.hud = hud
	story.player = player
	story.npcs = npcs
	story.builder = builder
	add_child(story)
	hud.start_pressed.connect(_start)
	hud.restart_pressed.connect(_restart)
	hud.lab_pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://demo/door_lab.tscn"))
	# Hold the clock on the title screen.
	get_tree().paused = false
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	R.manual_clock = true
	if _args.has("reel"):
		_reel.call_deferred()
	elif _args.has("shots"):
		_shots.call_deferred(String(_args["shots"]))
	elif _args.has("smoke"):
		_smoke.call_deferred()


func _spawn_household() -> void:
	var R := RoomsAndDoors
	player = ManorPlayer.new()
	player.setup(builder)
	player.position = ManorLayout.spot_position(&"player_start")
	add_child(player)
	R.register_character(&"maid", player, { "role": &"servant" })
	R.set_occupant_room(&"maid", ManorLayout.spot_room(&"player_start"), true)
	R.set_player(&"maid")
	for id in LOOKS:
		var look: Dictionary = LOOKS[id]
		var n := ManorNpc.new()
		n.setup(id, look["name"], look["role"], look, builder)
		n.position = ManorLayout.spot_position(look["spot"])
		add_child(n)
		R.register_character(id, n, { "role": look["role"] })
		n.place_at_spot(look["spot"])
		npcs[id] = n
	R.grant_key(&"lord", &"study_key")
	R.grant_key(&"lady", &"bed_key")
	R.register_key(&"passkey", [&"study_key", &"bed_key", &"jib_key"])
	R.grant_key(&"housekeeper", &"passkey")


func _start() -> void:
	RoomsAndDoors.manual_clock = false
	player.enabled = true
	story.begin()


func _restart() -> void:
	get_tree().paused = false
	RoomsAndDoors.reset()
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F3:
			RoomsAndDoors.toggle_debug_overlay()
		KEY_ESCAPE:
			if player.enabled and not get_tree().paused:
				get_tree().paused = true
				hud.show_help(true)


func _process(_dt: float) -> void:
	if is_instance_valid(player) and is_instance_valid(rig): player.camera_yaw = rig.yaw


# --- verification modes -------------------------------------------------------------

func _shots(dir: String) -> void:
	player.scripted = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _frames(20)
	await _shot(dir, "00_title")
	hud.show_title(false)
	_start()
	await _wait(3.0)
	await _shot(dir, "01_kitchen")
	# Crane at the study door.
	await _until(func(): return npcs[&"crane"].agent.state == NpcDoorAgent.State.AWAIT_KNOCK, 60.0)
	rig.target = npcs[&"crane"]
	await _wait(1.2)
	await _shot(dir, "01b_crane_knocks")
	rig.target = player
	# Walk the maid to the study door and listen through the conversation.
	_teleport(Vector3(8.6, 0, 1.3), &"gallery")
	await _wait(1.0)
	await _shot(dir, "02_gallery")
	await _until(func(): return story._conv_started_at > 0.0, 120.0)
	RoomsAndDoors.start_listening(&"maid", &"study_door")
	player.posture = RAD.Posture.LISTEN
	await _wait(36.0)
	await _shot(dir, "03_listening")
	RoomsAndDoors.toggle_debug_overlay()
	await _wait(0.5)
	await _shot(dir, "04_overlay")
	RoomsAndDoors.toggle_debug_overlay()
	RoomsAndDoors.stop_listening(&"maid")
	player.posture = RAD.Posture.NORMAL
	_teleport(Vector3(4.5, 0, 6.5), &"bedchamber")
	await _wait(2.0)
	await _shot(dir, "05_bedchamber")
	rig.yaw = 0.8
	rig.distance = 7.0
	await _wait(1.5)
	await _shot(dir, "06_close")
	print("shots written to ", dir)
	get_tree().quit(0)


## A short captioned tour for the README and site. Record with Movie Maker:
##   godot --path . --write-movie reel.avi --fixed-fps 30 res://demo/main.tscn -- --reel
func _reel() -> void:
	player.scripted = true
	rig.distance = 12.5
	await _real(2.5, func(t): rig.yaw = -0.35 + t * 0.12)
	hud.show_title(false)
	_start()
	hud.toast("One night, five people, eleven doors. Every rule here comes from the RoomsAndDoors autoload.", 4.0)
	# Follow the visitor in at speed.
	rig.target = npcs[&"crane"]
	Engine.time_scale = 6.0
	await _until(func(): return npcs[&"crane"].agent.state == NpcDoorAgent.State.AWAIT_KNOCK, 90.0)
	Engine.time_scale = 1.0
	hud.toast("Mr Crane knocks. He was invited, so the master's KnockPolicy answers: come in.", 3.5)
	await _real(3.0)
	await _until(func(): return story._conv_started_at > 0.0, 30.0)
	# The maid at the study door.
	rig.target = player
	_teleport(Vector3(8.6, 0, 1.4), &"gallery")
	hud.toast("Through a closed door the maid hears voices, but not words.", 3.5)
	Engine.time_scale = 3.0
	await _until(func(): return story._conv_next >= 2, 30.0)
	Engine.time_scale = 1.0
	await _real(1.5)
	hud.toast("Pressed against it, listening, she catches every word.", 3.5)
	RoomsAndDoors.start_listening(&"maid", &"study_door")
	player.posture = RAD.Posture.LISTEN
	Engine.time_scale = 3.5
	await _until(func(): return story.clue_fields, 60.0)
	Engine.time_scale = 1.0
	await _real(2.5)
	RoomsAndDoors.toggle_debug_overlay()
	hud.toast("F3: the room graph, door states, witnesses and the last twenty events.", 3.0)
	await _real(3.0)
	RoomsAndDoors.toggle_debug_overlay()
	RoomsAndDoors.stop_listening(&"maid")
	player.posture = RAD.Posture.NORMAL
	# Skip ahead to bedtime.
	rig.target = npcs[&"lady"]
	hud.toast("Later. The mistress bolts her door and goes to sleep.", 3.5)
	Engine.time_scale = 20.0
	await _until(func(): return RoomsAndDoors.is_sleeping(&"lady"), 300.0)
	Engine.time_scale = 1.0
	await _real(1.2)
	# The jib door, quietly.
	RoomsAndDoors.grant_key(&"maid", &"jib_key")
	_teleport(Vector3(-0.5, 0, 6.0), &"backstair")
	rig.target = player
	await _real(1.0)
	hud.toast("The servants' jib door, opened quietly: a sleeper needs 2.5x the noise to wake.", 4.0)
	player.sneaking = true
	player.walk_speed_override = 1.6
	await _walk([Vector3(1.0, 0, 8.5)])
	RoomsAndDoors.try_unlock(&"jib_door", &"maid")
	RoomsAndDoors.try_open(&"jib_door", &"maid", { "quiet": true })
	await _real(0.6)
	await _walk([Vector3(3.4, 0, 8.5), Vector3(4.2, 0, 5.2), Vector3(9.0, 0, 5.2), Vector3(9.1, 0, 6.5)])
	RoomsAndDoors.try_open(&"dressing_door", &"maid", { "quiet": true })
	await _real(0.6)
	await _walk([Vector3(11.4, 0, 6.5), Vector3(11.5, 0, 7.4)])
	await _real(0.6)
	story._on_prop_used(&"letter")
	await _real(3.5)
	print("reel done")
	get_tree().quit(0)


func _walk(points: Array[Vector3]) -> void:
	player.walk_points = points
	var waited := 0.0
	while not player.walk_points.is_empty() and waited < 20.0:
		await _real(0.1)
		waited += 0.1


## Wait `seconds` of wall (movie) time, calling fn(t) every frame.
func _real(seconds: float, fn: Callable = Callable()) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if fn.is_valid():
			fn.call(t)


func _smoke() -> void:
	player.scripted = true
	RoomsAndDoors.door_clip_detected.connect(func(c, a, b): _clips.append([c, a, b]))
	Engine.time_scale = 6.0
	Engine.physics_ticks_per_second = 60
	get_tree().physics_frame.connect(_count_furniture_walks)
	_start()
	var errors := 0
	await _until(func(): return story._conv_started_at > 0.0, 200.0)
	print("[smoke] conversation started at t=%.1f; crane in %s; study door %s" % [
		RoomsAndDoors.sim_time, RoomsAndDoors.room_of(&"crane"), RAD.door_state_name(int(RoomsAndDoors.get_door(&"study_door")["state"]))])
	_teleport(Vector3(8.6, 0, 1.3), &"gallery")
	RoomsAndDoors.start_listening(&"maid", &"study_door")
	player.posture = RAD.Posture.LISTEN
	await _until(func(): return story.clue_fields, 150.0)
	print("[smoke] clue_fields=%s suspicion=%d" % [story.clue_fields, int(story.suspicion)])
	if not story.clue_fields:
		errors += 1
	RoomsAndDoors.stop_listening(&"maid")
	player.posture = RAD.Posture.NORMAL
	await _until(func(): return RoomsAndDoors.is_sleeping(&"lady"), 300.0)
	print("[smoke] lady asleep=%s at t=%.1f; bed_door locked=%s" % [RoomsAndDoors.is_sleeping(&"lady"), RoomsAndDoors.sim_time, RoomsAndDoors.get_door(&"bed_door")["locked"]])
	print("[smoke] lord in %s, crane in %s, pell in %s" % [RoomsAndDoors.room_of(&"lord"), RoomsAndDoors.room_of(&"crane"), RoomsAndDoors.room_of(&"housekeeper")])
	if not RoomsAndDoors.is_sleeping(&"lady"):
		errors += 1
	# Quietly through the jib door, then the dressing room.
	RoomsAndDoors.grant_key(&"maid", &"jib_key")
	_teleport(Vector3(0.8, 0, 8.5), &"backstair")
	RoomsAndDoors.try_unlock(&"jib_door", &"maid")
	RoomsAndDoors.try_open(&"jib_door", &"maid", { "quiet": true })
	await _wait(1.0)
	_walk_room(&"bedchamber", Vector3(9.0, 0, 6.5))
	RoomsAndDoors.try_open(&"dressing_door", &"maid", { "quiet": true })
	await _wait(1.0)
	_walk_room(&"dressing", Vector3(11.5, 0, 7.6))
	story._on_prop_used(&"letter")
	await _wait(0.5)
	print("[smoke] lady still asleep=%s suspicion=%d over=%s" % [RoomsAndDoors.is_sleeping(&"lady"), int(story.suspicion), story._over])
	if not story._over:
		errors += 1
	var clips: int = _clips.size()
	print("[smoke] NPC frames walking inside furniture: %d %s" % [_furniture_frames, str(_furniture_hits.keys())])
	if _furniture_frames > 0 and builder.use_navigation:
		errors += 1
	print("[smoke] door clips flagged: %d %s; trespass entries: %d" % [clips, str(_clips.slice(0, 4)), RoomsAndDoors.trespass_log().size()])
	print("[smoke] %s" % ("OK" if errors == 0 else "FAILED (%d)" % errors))
	get_tree().quit(errors)


func _teleport(at: Vector3, room: StringName) -> void:
	player.global_position = at
	RoomsAndDoors.set_occupant_room(&"maid", room, true)


func _walk_room(room: StringName, at: Vector3) -> void:
	player.global_position = at
	RoomsAndDoors.set_occupant_room(&"maid", room)


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sim_seconds: float) -> void:
	var until := RoomsAndDoors.sim_time + sim_seconds
	while RoomsAndDoors.sim_time < until:
		await get_tree().process_frame


func _until(cond: Callable, timeout: float) -> void:
	var stop := RoomsAndDoors.sim_time + timeout
	while not cond.call() and RoomsAndDoors.sim_time < stop:
		await get_tree().process_frame
