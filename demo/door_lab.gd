extends Node3D
## A hands-on gallery of the design choices behind an ordinary door.
const DOOR_SCENE = preload("res://addons/rooms_and_doors/Door.tscn")
const STATIONS := ["01  Read the doorway", "02  Automatic or deliberate", "03  Key, puzzle, hack, story", "04  Direction and illusion", "05  Two people, one world", "06  Mind the threshold", "07  Last person through", "08  Travel together", "09  Who fits?", "10  Allies take turns", "11  Reinforcements", "12  Rewards and access"]
const DESCRIPTIONS := [
	"Try all three cues. A handle and green light invite use; a blank inset is decoration; cross-braces mean permanently sealed.",
	"Choose manual or proximity. Walk up from either side and watch the same real door respond to the selected trigger.",
	"Access has a cause. Find the brass key, solve the three-switch puzzle, finish a timed hack, or hear the archivist's story.",
	"A one-way door permits the indicated side. A visual portal promises a view, not a walkable connection. Open-only doors stay open.",
	"P1 and P2 have independent input and room residency. Split up, swap positions or let P2 follow. Neither player's room may be unloaded.",
	"Open, stand in the threshold, then close. Bodies stop the close. Move clear and close again; the actual collider protects the doorway.",
	"Both players must cross before the door closes and locks behind the group. One person crossing cannot strand the other.",
	"Wait for both players at the gate, or choose group teleport. Watch room residency update for each player, including the one left behind.",
	"A regular actor fits the narrow opening. The oversized actor does not. Choose the wide opening to let both through.",
	"Send three allies through. Each reserves the doorway, walks through, then releases it for the next ally. Players still collide with the queue.",
	"Request reinforcements. The director selects only an unobserved entrance; occupied or visible entrances are excluded. Turn the camera to change visibility.",
	"Cross to earn XP and coins once. Collect the floor coins, then buy optional timed access. No wallet credit appears unless it was earned."]
const JAPANESE_TITLES := ["01  ドアの見分け方","02  自動と手動","03  鍵・パズル・ハック・物語","04  一方通行と見かけ","05  二人で同じ世界へ","06  出入口の障害物","07  全員が通るまで","08  一緒に移動","09  通れる大きさ","10  仲間の順番待ち","11  増援の出現場所","12  報酬と一時通行権"]
const JAPANESE_DESCRIPTIONS := ["取っ手と緑色は使用可能。装飾のくぼみと、永久封鎖の横木を実際に比べてください。","手動か近接自動を選び、ドアに近づいてください。同じドアが別の操作方法で動きます。","真鍮の鍵を拾う、II・I・IIIの順にスイッチを押す、3秒のハック、または資料係との会話で解錠します。","一方通行は手前からのみ開きます。見かけの通路は通行不可。開け放しのドアは閉じません。","P1とP2は別々に動かせます。別の部屋へ行くと、両方の部屋が保持されます。位置交換と追従も可能です。","開いてから出入口に立ち、閉めてください。障害物や身体がある間は閉まりません。","二人とも向こう側へ渡るまでドアは閉まりません。最後の人が通ると閉まり、施錠されます。","全員がドアに集まるまで待つか、グループ転送を選べます。各人の在室情報が更新されます。","通常サイズは細いドアを通れます。大型の身体には幅広のドアが必要です。","三人の仲間を送ると、一人ずつ通行を予約して歩き、次の仲間に順番を譲ります。","増援は見えていない空の入口からのみ現れます。Qでカメラを回して候補を変えてください。","通過で経験値とコインを一度だけ獲得。床のコインを拾い、5枚で12秒の通行権を購入できます。"]
const JAPANESE_BUTTONS := {"Usable":"使用可","Decor":"装飾","Sealed":"封鎖","Manual":"手動","Proximity":"自動","Key":"鍵","Puzzle":"パズル","Hack":"ハック","Story":"物語","One-way":"一方通行","View":"見かけ","Open-only":"開け放し","Narrow":"細い","Wide":"幅広","Earn":"報酬","Timed gate":"時間制限","P1: use door [E]":"P1：ドアを使う [E]","Close door [C]":"ドアを閉める [C]","P2 follow: toggle":"P2の追従を切替","Swap players' positions":"二人の位置を交換","Move / replace obstruction":"障害物を移動・戻す","Open for group; walk both through":"開けて二人とも通過","Wait for both at gate":"二人が集まるまで待つ","Teleport entire group":"全員を転送","P1: toggle regular / oversized":"P1：通常・大型を切替","Send three allies":"三人の仲間を送る","Call reinforcements":"増援を呼ぶ","Buy 12 seconds of access · 5 coins":"5コインで12秒の通行権","Talk to archivist":"資料係と話す","Start hack / stop at 3 seconds":"ハック開始・3秒で停止"}
var world: Node3D
var policies: Node
var door: Door
var actors: Dictionary = {}
var inside: Dictionary = {}
var station := 0
var variant := 0
var follow := false
var oversized := false
var locale := "en"
var camera: Camera3D
var station_select: OptionButton
var title: Label
var description: Label
var status: Label
var history: RichTextLabel
var options: HBoxContainer
var action_box: VBoxContainer
var objective: Label3D
var coins: Array[Node3D] = []
var queue: Array[StringName] = []
var queue_active: StringName = &""
var gate_solved := false
var puzzle_step := 0
var hack_started := -1.0
var block_prop: StaticBody3D
var spawn_doors: Array = []
var elapsed := 0.0
var camera_angle := 0.0
var welcome: Label
var network: Node
var join_address: LineEdit
var remote_direction := Vector3.ZERO
var remote_peer := 0
var applying_remote := false
var network_clock := 0.0
var tour_targets: Dictionary = {}
var tour_failures := 0

func _ready() -> void:
	_build_ui()
	_select(0)
	network = load("res://addons/rooms_and_doors/door_network.gd").new()
	network.name = "DoorNetwork"
	add_child(network)
	network.request_result.connect(_report)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(func(peer):
		if peer == remote_peer:
			remote_peer = 0
			remote_direction = Vector3.ZERO
			_log("P2 disconnected. Both players can now be controlled locally."))
	multiplayer.connected_to_server.connect(func():
		_log("Connected. You control P2 with WASD or arrows; E uses the door.")
		_request_station.rpc_id(1))
	multiplayer.connection_failed.connect(func(): _log("Connection failed. Check the host IP and UDP port 7077."))
	multiplayer.server_disconnected.connect(func():
		_log("Host disconnected. Returning to local play.")
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new())
	for argument in OS.get_cmdline_user_args():
		if argument == "--host": _host()
		if argument.begins_with("--join="): _join(argument.trim_prefix("--join="))
	if OS.get_cmdline_user_args().has("--lab-tour"): _tour.call_deferred()

func _exit_tree() -> void:
	RoomsAndDoors.reset()

func _select(index: int, choice: int = 0) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and not applying_remote:
		_log("The host selects the experiment.")
		return
	station = index
	variant = choice
	follow = false
	oversized = false
	gate_solved = false
	puzzle_step = 0
	hack_started = -1.0
	inside.clear()
	actors.clear()
	coins.clear()
	queue.clear()
	queue_active = &""
	spawn_doors.clear()
	block_prop = null
	if is_instance_valid(world):
		world.free()
	if is_instance_valid(policies):
		policies.free()
	RoomsAndDoors.reset()
	RoomsAndDoors.manual_clock = false
	RoomsAndDoors.instant_doors = false
	policies = load("res://addons/rooms_and_doors/door_policies.gd").new()
	add_child(policies)
	policies.feedback.connect(_log)
	policies.transition_requested.connect(_transition)
	policies.objective_changed.connect(func(_id,active):
		if is_instance_valid(objective): objective.visible = active)
	world = Node3D.new()
	add_child(world)
	for id in [&"near", &"far", &"alcove"]:
		RoomsAndDoors.register_room({"id":id, "display_name":String(id).capitalize()})
	_build_room()
	_spawn_actor(&"p1", Vector3(-0.65, 0, -3), Color("4edcc8"))
	_spawn_actor(&"p2", Vector3(0.65, 0, -3), Color("ffb75d"))
	for id in actors:
		policies.register_player(id)
		policies.set_player_room(id, &"near")
	RoomsAndDoors.set_player(&"p1")
	var config := {"width":1.4,"height":2.5,"hint":"Use the handle", "objective":true}
	match station:
		0: config["mode"] = ["interactive","decorative","sealed"][variant]
		1: config["trigger"] = ["manual","proximity"][variant]
		2:
			if variant > 0:
				config["gate_kind"] = ["", "puzzle", "hack", "story"][variant]
				config["gate_token"] = "complete"
		3:
			if variant == 0: config["allowed_from"] = &"near"
			else: config["mode"] = ["", "visual_only", "open_only"][variant]
		6:
			config["close_after_clear"] = true
			config["lock_after_clear"] = true
			config["group_members"] = [&"p1",&"p2"]
			config["group_destination"] = &"far"
		8: config["width"] = 1.0 if variant == 0 else 2.6
		11:
			config["reward"] = {"xp":25,"gold":10,"items":["gallery_badge"]}
			if variant == 1:
				config["access_cost"] = 5
				config["access_seconds"] = 12.0
	door = DOOR_SCENE.instantiate()
	door.door_id = &"lab_gate"
	door.room_a = &"near"
	door.room_b = &"far"
	door.width = float(config["width"])
	door.height = 2.5
	if station == 2 and variant == 0:
		door.key_id = &"brass_key"
		door.locked_initially = true
	world.add_child(door)
	policies.configure_door(&"lab_gate", config)
	policies.set_locale(locale)
	policies.set_objective(&"lab_gate", true)
	var color := Color("39c4af")
	if station == 0 and variant == 1: color = Color("526275")
	if station == 0 and variant == 2: color = Color("e86a62")
	(door.get_node("Hinge/Panel") as MeshInstance3D).material_override = _material(color)
	# Fill both sides of the aperture with real collision geometry.
	var opening := door.width
	for side in [-1,1]:
		_box(Vector3(side * (3.5 + opening * 0.25),1.25,0), Vector3(7-opening*0.5,2.5,0.3), Color("26384a"),true)
		_box(Vector3(side * (opening*0.5+0.08),1.3,0),Vector3(0.14,2.6,0.42),color,false)
	if station == 0 and variant == 1:
		_box(Vector3(0,1.2,-0.09),Vector3(opening,2.4,0.08),color,false)
	if station == 0 and variant == 2:
		for y in [0.65,1.65]: _box(Vector3(0,y,-0.13),Vector3(opening+0.3,0.23,0.18),Color("efb66a"),false)
	if station == 3 and variant == 1:
		(door.get_node("Hinge/Panel") as MeshInstance3D).material_override = _material(Color(0.2,0.65,0.9,0.32))
		_label("VIEW ONLY",Vector3(0,1.3,-0.2),26)
	objective = _label("◆",Vector3(0,3.4,0),48)
	objective.modulate = Color("ffda76")
	_label("ASSEMBLY / NEAR",Vector3(-3.7,0.05,-3.8),22)
	_label("DESTINATION / FAR",Vector3(-3.7,0.05,3.8),22)
	if station == 2 and variant == 0:
		var key := _box(Vector3(-2,0.7,-2),Vector3(0.65,0.12,0.16),Color("ffd873"),false)
		key.name = "KeyPickup"
		_label("BRASS KEY",Vector3(-2,1.15,-2),20)
	if station == 5:
		block_prop = _box(Vector3(0,0.6,0.4),Vector3(0.85,1.2,0.8),Color("e37c52"),true) as StaticBody3D
	if station == 11:
		for x in [-2.8,-1.4,1.4,2.8]:
			coins.append(_box(Vector3(x,0.28,-2.0),Vector3(0.3,0.12,0.3),Color("ffce64"),false))
	if station == 10: _build_spawn_entries()
	_update_station_ui()
	_log("Station ready. Walk to the doorway; reset restores this experiment.")
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and remote_peer != 0:
		_receive_station.rpc_id(remote_peer,station,variant)

func _build_room() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b2b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a6c5e5")
	environment.ambient_light_energy = 0.65
	env.environment = environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65,-20,0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	world.add_child(light)
	_box(Vector3(0,-0.15,0),Vector3(14,0.3,12),Color("263343"),true)
	for z in [-4.8,4.8]: _box(Vector3(0,0.02,z),Vector3(12,0.025,0.06),Color("4edcc8"),false)
	for x in [-6.8,6.8]: _box(Vector3(x,0.5,0),Vector3(0.3,1,12),Color("3b5369"),true)
	for z in [-5.8,5.8]: _box(Vector3(0,0.5,z),Vector3(14,1,0.3),Color("3b5369"),true)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	world.add_child(camera)
	_camera_update()
	camera.current = true

func _camera_update() -> void:
	camera.position = Vector3(sin(camera_angle)*11,12,-cos(camera_angle)*12)
	camera.look_at(Vector3(-1.8,0,0))

func _spawn_actor(id: StringName, at: Vector3, color: Color) -> void:
	var body := CharacterBody3D.new()
	body.name = String(id)
	body.collision_layer = 2
	body.collision_mask = 3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	body.add_child(shape)
	var model := Mannequin.new()
	model.name = "Model"
	model.accent_color = color
	model.body_color = color.lightened(0.25)
	body.add_child(model)
	body.position = at
	world.add_child(body)
	var label := _label(String(id).to_upper(),Vector3.ZERO,24)
	label.reparent(body)
	label.position = Vector3(0,2.3,0)
	actors[id] = body
	RoomsAndDoors.register_character(id,body)
	RoomsAndDoors.set_occupant_room(id,&"near",true)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(door): return
	elapsed += dt
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var input_direction := Vector3(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		_remote_movement.rpc_id(1,input_direction)
		_update_status()
		return
	for id in actors.keys():
		var body: CharacterBody3D = actors[id]
		var direction := Vector3.ZERO
		if id == &"p1":
			direction = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		elif id == &"p2":
			direction = Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
			if remote_peer != 0: direction = remote_direction
			if follow and direction.is_zero_approx():
				var target: Vector3 = actors[&"p1"].position + Vector3(0.7,0,-0.8)
				if body.position.distance_to(target)>1.1: direction = (target-body.position).normalized()
		elif id == queue_active:
			var park_x := float(String(id).trim_prefix("ally").to_int()-2)*1.8
			var target := Vector3(park_x,0,3.4) if body.position.z > 1.0 else Vector3(0,0,2)
			if body.position.z < -1: target = Vector3(0,0,-0.75)
			direction = (target-body.position).normalized()
			if body.position.distance_to(Vector3(park_x,0,3.4)) < 0.35:
				policies.release_threshold(&"lab_gate",id)
				queue_active = &""
				direction = Vector3.ZERO
		if tour_targets.has(id):
			direction = (tour_targets[id] - body.position).normalized()
		var previous_position := body.position
		body.velocity = direction.normalized()*2.7
		body.velocity.y = -2
		body.move_and_slide()
		var model := body.get_node("Model") as Mannequin
		model.speed = Vector2(body.velocity.x,body.velocity.z).length()
		if direction.length_squared()>0.05: body.rotation.y = atan2(-direction.x,-direction.z)
		if previous_position.z * body.position.z < 0:
			var permission: Dictionary = policies.check_pass(&"lab_gate",id,_actor_opts(id))
			if not permission.get("ok",false):
				body.position = previous_position
				_report(permission)
		var room: StringName = &"far" if body.position.z > 0.15 else &"near"
		if RoomsAndDoors.room_of(id) != room and absf(body.position.z)>0.2:
			if id in [&"p1",&"p2"]: policies.set_player_room(id,room)
			else: RoomsAndDoors.set_occupant_room(id,room)
			_log("%s entered %s" % [id,room])
			if room == &"far" and id == &"p1": policies.set_objective(&"lab_gate",false)
		if station == 1 and variant == 1 and body.position.distance_to(Vector3.ZERO)<2.2:
			policies.request_open(&"lab_gate",id,_actor_opts(id,&"proximity"))
		if station == 2 and variant == 0 and not gate_solved and body.position.distance_to(Vector3(-2,0,-2))<0.9:
			RoomsAndDoors.grant_key(id,&"brass_key")
			gate_solved = true
			world.get_node("KeyPickup").hide()
			_log("%s picked up the brass key." % id)
		for coin in coins.duplicate():
			if body.position.distance_to(coin.position)<0.75:
				policies.earn_currency(id,2)
				coins.erase(coin)
				coin.queue_free()
				_log("%s earned 2 coins." % id)
	if not queue.is_empty() and queue_active == &"":
		var next: StringName = queue[0]
		var result: Dictionary = policies.reserve_threshold(&"lab_gate",next)
		if result.get("ok",false):
			queue.pop_front()
			queue_active = next
			policies.request_open(&"lab_gate",next,_actor_opts(next))
			_log("%s reserved the doorway." % next)
	objective.position.y = 3.35 + sin(elapsed*2)*0.12
	_update_status()
	if remote_peer != 0:
		network_clock += dt
		if network_clock > 0.05:
			network_clock = 0
			var snapshot := {}
			for actor in actors:
				snapshot[String(actor)] = {"position":actors[actor].position,"rotation":actors[actor].rotation.y}
			_receive_positions.rpc_id(remote_peer,snapshot)

func _actor_opts(id: StringName, trigger: StringName = &"manual") -> Dictionary:
	return {"width":1.8 if id == &"p1" and oversized else 0.6,"height":2.4 if id == &"p1" and oversized else 1.75,"trigger":trigger}

func _interact(id: StringName) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		network.request_open(&"lab_gate")
		return
	if (actors[id] as Node3D).position.distance_to(Vector3.ZERO)>2.5:
		_log("%s: move within reach of the handle." % id)
		return
	if station == 2 and variant == 0 and gate_solved: RoomsAndDoors.try_unlock(&"lab_gate",id)
	var result: Dictionary = policies.request_open(&"lab_gate",id,_actor_opts(id))
	_report(result)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_E: _interact(&"p1")
		KEY_ENTER: _interact(&"p2")
		KEY_C: _report(RoomsAndDoors.try_close(&"lab_gate",&"p1"))
		KEY_R: _select(station,variant)
		KEY_F3: RoomsAndDoors.toggle_debug_overlay()
		KEY_ESCAPE: _return_to_manor()
		KEY_Q:
			camera_angle += PI*0.5
			_camera_update()

func _transition(actor, destination) -> void:
	if not actors.has(actor): return
	var at := Vector3(-0.65 if actor == &"p1" else 0.65,0,3.2 if StringName(destination) == &"far" else -3.2)
	(actors[actor] as Node3D).position = at
	policies.set_player_room(actor,StringName(destination))
	_log("%s travelled to %s." % [actor,destination])

func _report(result: Dictionary) -> void:
	var message = result.get("message",result.get("reason",result.get("code",str(result))))
	_log(String(message))

func _log(text: String) -> void:
	if is_instance_valid(history):
		history.append_text("[color=#6cddca]›[/color] " + text + "\n")
		if history.get_line_count()>45: history.clear()

func _update_status() -> void:
	var d := RoomsAndDoors.get_door(&"lab_gate")
	var lines := "%s   %s\n" % [RAD.door_state_name(int(d.get("state",0))).to_upper(),"LOCKED" if d.get("locked",false) else "UNLOCKED"]
	for id in [&"p1",&"p2"]:
		var progress: Dictionary = policies.get_progress(id)
		lines += "%s · %s · %s\n" % [String(id).to_upper(),RoomsAndDoors.room_of(id),str(progress)]
	lines += "Near room unload: %s  |  Far room unload: %s" % [policies.can_unload_room(&"near"),policies.can_unload_room(&"far")]
	status.text = lines
	if station == 2 and variant == 2 and hack_started >= 0:
		status.text += "\nHACK WINDOW: %.1fs / 3.0s" % ((Time.get_ticks_msec()/1000.0)-hack_started)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = 360
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111f30")
	style.content_margin_left=22
	style.content_margin_right=22
	style.content_margin_top=20
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	panel.add_child(column)
	welcome = _ui_label("THE DOOR LAB",26)
	welcome.add_theme_color_override("font_color",Color("5be0c8"))
	column.add_child(welcome)
	column.add_child(_ui_label("Twelve playable design experiments",14))
	var select := OptionButton.new()
	station_select = select
	for text in STATIONS: select.add_item(text)
	select.item_selected.connect(func(i): _select(i))
	column.add_child(select)
	title = _ui_label("",19)
	column.add_child(title)
	description = _ui_label("",15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	options = HBoxContainer.new()
	column.add_child(options)
	action_box = VBoxContainer.new()
	column.add_child(action_box)
	column.add_child(HSeparator.new())
	status = _ui_label("",13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var controls := _ui_label("P1  WASD + E    P2  Arrows + Enter\nC close · Q orbit · R reset · F3 inspect\nEsc returns to Ashcombe House",13)
	column.add_child(controls)
	if not OS.has_feature("web"):
		var netrow := HBoxContainer.new()
		column.add_child(netrow)
		_button(netrow,"Host LAN",_host)
		join_address = LineEdit.new()
		join_address.placeholder_text = "Host IP"
		join_address.text = "127.0.0.1"
		join_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		netrow.add_child(join_address)
		_button(netrow,"Join",func(): _join(join_address.text))
	else:
		column.add_child(_ui_label("LAN: use the desktop build (UDP 7077)",12))
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row,"Reset",func(): _select(station,variant))
	_button(row,"EN / 日本語",_toggle_locale)
	_button(row,"Manor",_return_to_manor)
	column.add_child(_ui_label("LIVE EVENT JOURNAL",12))
	history = RichTextLabel.new()
	history.bbcode_enabled = true
	history.scroll_following = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.custom_minimum_size.y = 80
	history.add_theme_font_size_override("normal_font_size",13)
	column.add_child(history)
	var banner := Label.new()
	banner.text = "WALK • EXPERIMENT • WATCH THE CONSEQUENCES"
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	banner.offset_left = -210
	banner.offset_right = 550
	banner.offset_top = -40
	banner.add_theme_color_override("font_color",Color("90abbc"))
	root.add_child(banner)

func _update_station_ui() -> void:
	title.text = JAPANESE_TITLES[station] if locale == "ja" else STATIONS[station].substr(4)
	description.text = JAPANESE_DESCRIPTIONS[station] if locale == "ja" else DESCRIPTIONS[station]
	for i in STATIONS.size(): station_select.set_item_text(i,JAPANESE_TITLES[i] if locale == "ja" else STATIONS[i])
	station_select.select(station)
	for child in options.get_children(): child.free()
	for child in action_box.get_children(): child.free()
	var choices: Array = []
	match station:
		0: choices = ["Usable","Decor","Sealed"]
		1: choices = ["Manual","Proximity"]
		2: choices = ["Key","Puzzle","Hack","Story"]
		3: choices = ["One-way","View","Open-only"]
		8: choices = ["Narrow","Wide"]
		11: choices = ["Earn","Timed gate"]
	for i in choices.size():
		var index := i
		var button := _button(options,String(choices[i]),func(): _select(station,index))
		button.disabled = i == variant
	_button(action_box,"P1: use door [E]",func(): _interact(&"p1"))
	_button(action_box,"Close door [C]",func(): _report(RoomsAndDoors.try_close(&"lab_gate",&"p1")))
	match station:
		2:
			match variant:
				1:
					for i in 3:
						var switch_index := i
						_button(action_box,"Switch %d" % (i+1),func(): _puzzle(switch_index))
				2:
					_button(action_box,"Start hack / stop at 3 seconds",_hack)
				3:
					_button(action_box,"Talk to archivist",_story)
		4:
			_button(action_box,"P2 follow: toggle",func():
				follow = not follow
				_log("P2 follow: %s" % follow))
			_button(action_box,"Swap players' positions",_swap)
		5:
			_button(action_box,"Move / replace obstruction",func():
				block_prop.position.x = 2.5 if block_prop.position.x == 0 else 0.0)
		6:
			_button(action_box,"Open for group; walk both through",func(): _report(policies.request_open(&"lab_gate",&"p1",_actor_opts(&"p1"))))
		7:
			_button(action_box,"Wait for both at gate",func(): _report(policies.request_group_transition(&"lab_gate",[&"p1",&"p2"],&"far",&"wait")))
			_button(action_box,"Teleport entire group",func(): _report(policies.request_group_transition(&"lab_gate",[&"p1",&"p2"],&"far",&"teleport")))
		8:
			_button(action_box,"P1: toggle regular / oversized",_size_toggle)
		9:
			_button(action_box,"Send three allies",_send_allies)
		10:
			_button(action_box,"Call reinforcements",_reinforce)
		11:
			if variant == 1:
				_button(action_box,"Buy 12 seconds of access · 5 coins",_purchase)

func _puzzle(index: int) -> void:
	var sequence := [1,0,2]
	if index == sequence[puzzle_step]:
		puzzle_step += 1
		_log("Switch sequence %d/3. Inscription: II · I · III" % puzzle_step)
		if puzzle_step == 3:
			_report(policies.unlock_gate(&"lab_gate",&"puzzle",&"complete"))
			puzzle_step = 0
	else:
		puzzle_step = 0
		_log("Circuit reset. Inscription: II · I · III")

func _hack() -> void:
	var now := Time.get_ticks_msec()/1000.0
	if hack_started < 0:
		hack_started = now
		_log("Hack started. Stop between 2.7 and 3.4 seconds.")
	else:
		var duration := now-hack_started
		hack_started = -1
		if duration >= 2.7 and duration <= 3.4: _report(policies.unlock_gate(&"lab_gate",&"hack",&"complete"))
		else: _log("Timing missed: %.2fs. Try again." % duration)

func _story() -> void:
	if not gate_solved:
		gate_solved = true
		_log("Archivist: These doors once protected the collection. Will you carry its memory? Speak again to accept.")
	else:
		_report(policies.unlock_gate(&"lab_gate",&"story",&"complete"))
		_log("Archivist: Then the gallery is yours. The story gate is released.")

func _swap() -> void:
	var a: Vector3 = actors[&"p1"].position
	actors[&"p1"].position = actors[&"p2"].position
	actors[&"p2"].position = a
	_log("Players swapped; their room residency follows their bodies.")

func _size_toggle() -> void:
	oversized = not oversized
	var body: CharacterBody3D = actors[&"p1"]
	(body.get_node("Model") as Node3D).scale = Vector3(2.2,1.35,2.2) if oversized else Vector3.ONE
	var shape: CapsuleShape3D = (body.get_node("CollisionShape3D") as CollisionShape3D).shape
	shape.radius = 0.9 if oversized else 0.28
	shape.height = 2.4 if oversized else 1.75
	(body.get_node("CollisionShape3D") as CollisionShape3D).position.y = 1.2 if oversized else 0.88
	_log("P1 clearance: %s" % ("1.8m × 2.4m" if oversized else "0.6m × 1.75m"))

func _send_allies() -> void:
	if actors.has(&"ally1"): return
	for i in 3:
		var id := StringName("ally%d" % (i+1))
		_spawn_actor(id,Vector3(-2.6-i*0.9,0,-2.5),Color("b99af4"))
		queue.append(id)
	_log("Three allies queued for a reserved passage.")

func _build_spawn_entries() -> void:
	for i in 3:
		var entry: Door = DOOR_SCENE.instantiate()
		entry.door_id = StringName("entry%d" % i)
		entry.room_a = &"far"
		entry.room_b = &"alcove"
		entry.position = Vector3(-4.5+i*4.5,0,4.4)
		world.add_child(entry)
		policies.configure_door(entry.door_id,{"mode":"interactive"})
		spawn_doors.append(entry)
	_box(Vector3(-4.5,1.8,2.9),Vector3(2.8,3.6,0.35),Color("344c63"),true)
	_box(Vector3(4.5,1.8,2.9),Vector3(2.8,3.6,0.35),Color("344c63"),true)

func _reinforce() -> void:
	var candidates: Array = []
	var visible: Array = []
	for entry in spawn_doors:
		var target: Vector3 = entry.position+Vector3(0,1,0)
		var query := PhysicsRayQueryParameters3D.create(camera.position,target)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var observed: bool = hit.is_empty() or hit.get("collider") == entry
		if observed: visible.append(entry.door_id)
		candidates.append({"door_id":entry.door_id,"room_id":&"far","occupied":false,"position":target})
	var selected: Dictionary = policies.select_reinforcement(candidates,visible)
	if selected.is_empty() or not selected.get("ok",true):
		_log("No safe unobserved entrance. Orbit with Q and try again.")
		return
	var id: StringName = StringName(selected.get("door_id",selected.get("door",&"")))
	for entry in spawn_doors:
		if entry.door_id != id: continue
		var actor := StringName("reinforcement%d" % actors.size())
		_spawn_actor(actor,entry.position+Vector3(0,0,-0.75),Color("ec8ea8"))
		RoomsAndDoors.set_occupant_room(actor,&"far",true)
		_log("Reinforcement emerged from hidden %s." % id)

func _toggle_locale() -> void:
	locale = "ja" if locale == "en" else "en"
	policies.set_locale(locale)
	welcome.text = "ドア実験室" if locale == "ja" else "THE DOOR LAB"
	_update_station_ui()
	_log(policies.get_hint(&"lab_gate",&"p1"))
	_log("言語：日本語。ドアの案内とフィードバックを切り替えました。" if locale == "ja" else "Language: English. Door guidance and feedback updated.")

func _return_to_manor() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://demo/main.tscn")

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	if color.a < 1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _box(at: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	node.position = at
	world.add_child(node)
	return node

func _label(text: String, at: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	world.add_child(label)
	return label

func _ui_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("dbe8f1"))
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = JAPANESE_BUTTONS.get(text,text) if locale == "ja" else text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 31
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _host() -> void:
	if OS.has_feature("web"):
		_log("LAN uses the native desktop build.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(7077,1)
	if error != OK:
		_log("Could not host on UDP 7077: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	network.bind_peer_actor(1,&"p1")
	_log("Hosting on UDP 7077. Give your LAN IP to the second player. Host controls P1.")

func _join(address: String) -> void:
	if OS.has_feature("web"):
		_log("LAN uses the native desktop build.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(),7077)
	if error != OK:
		_log("Could not join: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	_log("Connecting to %s:7077…" % address)

func _peer_connected(peer: int) -> void:
	if not multiplayer.is_server(): return
	remote_peer = peer
	remote_direction = Vector3.ZERO
	network.bind_peer_actor(peer,&"p2")
	_log("P2 joined. Door decisions and movement are controlled by the host.")

@rpc("any_peer","call_remote","reliable")
func _request_station() -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if sender != remote_peer: return
	_receive_station.rpc_id(sender,station,variant)

@rpc("authority","call_remote","reliable")
func _receive_station(index: int, choice: int) -> void:
	applying_remote = true
	_select(index,choice)
	applying_remote = false
	for child in action_box.get_children():
		if child is Button:
			child.disabled = not (child.text.begins_with("P1:") or child.text.begins_with("Buy"))
	network.request_sync()

@rpc("any_peer","call_remote","unreliable_ordered")
func _remote_movement(direction: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != remote_peer: return
	remote_direction = Vector3(direction.x,0,direction.z).limit_length(1)

@rpc("authority","call_remote","unreliable_ordered")
func _receive_positions(snapshot: Dictionary) -> void:
	for actor in snapshot:
		var id := StringName(actor)
		var state: Dictionary = snapshot[actor]
		if not actors.has(id): _spawn_actor(id,state["position"],Color("b99af4"))
		var body: CharacterBody3D = actors[id]
		var distance := body.position.distance_to(state["position"])
		body.position = state["position"]
		body.rotation.y = state["rotation"]
		(body.get_node("Model") as Mannequin).speed = distance*20


func _purchase() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): network.request_purchase(&"lab_gate")
	else: _report(policies.purchase_access(&"lab_gate",&"p1"))

func _tour_walk(id: StringName, target: Vector3, seconds: float = 4.0) -> void:
	tour_targets[id] = target
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while (actors[id] as Node3D).position.distance_to(target)>0.3 and Time.get_ticks_msec()<until:
		await get_tree().physics_frame
	tour_targets.erase(id)

func _tour_expect(label: String, condition: bool) -> void:
	print("[lab-tour] ",label," ","OK" if condition else "FAILED")
	if not condition: tour_failures += 1

func _tour() -> void:
	await get_tree().create_timer(1).timeout
	_select(0,2)
	_tour_expect("permanently sealed refuses open",not policies.request_open(&"lab_gate",&"p1").get("ok",false))
	_select(1,1)
	await _tour_walk(&"p1",Vector3(0,0,-1.2))
	await get_tree().create_timer(0.6).timeout
	_tour_expect("proximity opens actual door",RoomsAndDoors.get_door(&"lab_gate")["state"] == RAD.DoorState.OPEN)
	await _tour_walk(&"p1",Vector3(0,0,2.3))
	_tour_expect("body crossed into far room",RoomsAndDoors.room_of(&"p1") == &"far")
	_select(2,0)
	await _tour_walk(&"p1",Vector3(-2,0,-2))
	await _tour_walk(&"p1",Vector3(0,0,-1.5))
	_interact(&"p1")
	await get_tree().create_timer(0.6).timeout
	_tour_expect("picked-up key unlocks door",not RoomsAndDoors.get_door(&"lab_gate")["locked"])
	_select(2,1)
	_puzzle(1)
	_puzzle(0)
	_puzzle(2)
	_tour_expect("puzzle unlocks access",policies.check_pass(&"lab_gate",&"p1").get("ok",false))
	_select(6)
	policies.request_open(&"lab_gate",&"p1",{"instant":true})
	await _tour_walk(&"p1",Vector3(-0.3,0,2.3))
	_tour_expect("first player does not strand second",not RoomsAndDoors.get_door(&"lab_gate")["locked"])
	await _tour_walk(&"p2",Vector3(0.3,0,2.3))
	await get_tree().create_timer(0.4).timeout
	_tour_expect("door locks after both cross",RoomsAndDoors.get_door(&"lab_gate")["locked"])
	_select(7)
	policies.request_group_transition(&"lab_gate",[&"p1",&"p2"],&"far",&"teleport")
	_tour_expect("group teleport updates both residents",RoomsAndDoors.room_of(&"p1") == &"far" and RoomsAndDoors.room_of(&"p2") == &"far")
	_select(8)
	_size_toggle()
	_tour_expect("oversized actor refused narrow door",not policies.request_open(&"lab_gate",&"p1",_actor_opts(&"p1")).get("ok",false))
	_select(9)
	_send_allies()
	await get_tree().create_timer(12).timeout
	_tour_expect("all allies cleared queue",queue.is_empty() and queue_active == &"")
	_select(10)
	_reinforce()
	await get_tree().create_timer(1).timeout
	_tour_expect("hidden entrance spawns reinforcement",actors.size()>2)
	_select(11)
	policies.request_open(&"lab_gate",&"p1",{"instant":true})
	await _tour_walk(&"p1",Vector3(0,0,2.3))
	_tour_expect("crossing awards real progress",int(policies.get_progress(&"p1").get("xp",0))>0)
	_toggle_locale()
	await get_tree().create_timer(1).timeout
	print("[lab-tour] completed; failures=",tour_failures)
	get_tree().quit(0 if tour_failures == 0 else 1)

