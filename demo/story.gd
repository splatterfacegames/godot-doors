class_name ManorStory
extends Node
## One night at Ashcombe House. Drives NPC schedules, the study conversation, the
## letter, suspicion and the endings. Everything it knows about who heard, saw or
## found whom comes from RoomsAndDoors signals and queries.

signal ended(won: bool)

const NIGHT_LENGTH := 540.0
const CONVERSATION := [
	# [offset s, speaker, loudness, text, key]
	[4.0, &"crane", 0.4, "You know why I've come, Ashcombe.", false],
	[12.0, &"lord", 0.4, "Keep your voice down. The servants hear everything in this house.", false],
	[21.0, &"crane", 0.45, "Then they'll hear it from someone soon enough.", false],
	[31.0, &"lord", 0.2, "The east fields are already pledged. I cannot pledge them twice.", true],
	[40.0, &"crane", 0.75, "You pledged them twice in March!", true],
	[48.0, &"lord", 0.7, "And you took the money gladly!", false],
	[60.0, &"crane", 0.4, "Then I'll have the deed to the house itself by Michaelmas.", true],
	[71.0, &"lord", 0.35, "She must not know. Not until it is done.", true],
	[82.0, &"crane", 0.4, "Your wife is not a fool, Ashcombe.", false],
	[92.0, &"lord", 0.18, "No. That is exactly the trouble.", false],
	[104.0, &"crane", 0.4, "Michaelmas. Not a day later.", false],
]
const LETTER := "“Dearest Tom — I found the second pledge in his desk. He thinks I do not know. I mean to be gone before Michaelmas, and the deed goes with me. Burn this. — M.”"

var main: Node
var hud: ManorHud
var player: ManorPlayer
var npcs: Dictionary = {}
var builder: ManorBuilder

var suspicion: float = 0.0
var clue_fields := false
var clue_letter := false
var key_lines_identified: Dictionary = {}
var chores_done: Dictionary = {}
var ajar_left_count := 0
var _conv_id: StringName = &""
var _conv_started_at: float = -1.0
var _conv_next: int = 0
var _beats: Array = []
var _caught_listening := false
var _check_t := 0.0
var _over := false


func begin() -> void:
	var R := RoomsAndDoors
	R.discovery.connect(_on_discovery)
	R.ajar_discovered.connect(_on_ajar_discovered)
	R.character_woken.connect(_on_woken)
	R.knock_answered.connect(_on_knock_answered)
	R.activity_finished.connect(_on_activity_finished)
	player.prop_used.connect(_on_prop_used)
	player.message.connect(func(t): hud.toast(t, 2.2))
	player.chore_progress.connect(func(_id, p): hud.set_chore(p))
	R.set_duty(&"maid", &"library", { "start": 0.0, "end": 400.0, "expected": 60.0 })
	R.set_duty(&"maid", &"bedchamber", { "start": 0.0, "end": 180.0, "expected": 45.0 })
	R.set_invitation(&"crane", &"study", &"lord", { "expires_at": -1.0 })
	_schedule()
	hud.push_log("The house is quiet. Somewhere a clock ticks.", "muffled")
	_refresh_objectives()


func _schedule() -> void:
	var lord: ManorNpc = npcs[&"lord"]
	var lady: ManorNpc = npcs[&"lady"]
	var pell: ManorNpc = npcs[&"housekeeper"]
	var cook: ManorNpc = npcs[&"cook"]
	var crane: ManorNpc = npcs[&"crane"]
	lord.push({ "kind": "door", "door": &"study_door", "op": "lock" })
	lord.push({ "kind": "sit", "spot": &"lord_desk" })
	lady.push({ "kind": "sit", "spot": &"lady_desk" })
	cook.push({ "kind": "pose", "pose": Mannequin.Pose.WORK })
	_patrol(pell)
	_at(14.0, func():
		crane.push({ "kind": "go", "spot": &"hall_mid" })
		crane.push({ "kind": "say", "text": "Mr Crane, to see his lordship." })
		crane.push({ "kind": "go", "spot": &"crane_chair" })
		crane.push({ "kind": "call", "fn": _crane_arrived }))
	_at(205.0, func():
		lady.clear_tasks()
		lady.push({ "kind": "say", "text": "Enough. Bed." })
		lady.push({ "kind": "go", "spot": &"lady_bedside" })
		lady.push({ "kind": "door", "door": &"bed_door", "op": "close" })
		lady.push({ "kind": "wait", "seconds": 0.6 })
		lady.push({ "kind": "door", "door": &"bed_door", "op": "lock" })
		lady.push({ "kind": "sleep", "spot": &"lady_bed" }))


func _patrol(pell: ManorNpc) -> void:
	for spot in [&"hall_mid", &"gallery_west", &"library_mid", &"backstair_mid", &"gallery_east", &"hall_east", &"cook_table"]:
		pell.push({ "kind": "go", "spot": spot })
		pell.push({ "kind": "wait", "seconds": 6.0 })
	pell.push({ "kind": "call", "fn": func(): _patrol(pell) })


func _crane_arrived() -> void:
	var lord: ManorNpc = npcs[&"lord"]
	lord.push({ "kind": "door", "door": &"study_door", "op": "close" })
	lord.push({ "kind": "wait", "seconds": 0.6 })
	lord.push({ "kind": "door", "door": &"study_door", "op": "lock" })
	npcs[&"crane"].push({ "kind": "pose", "pose": Mannequin.Pose.SIT })
	_conv_id = RoomsAndDoors.start_activity({
		"id": &"study_conversation", "room": &"study", "participants": [&"lord", &"crane"],
		"loudness": RAD.LOUD_CONVERSATION, "duration": 115.0, "activity_class": &"conversation",
	})
	_conv_started_at = RoomsAndDoors.sim_time
	_conv_next = 0


func _on_activity_finished(id: StringName, _a: Dictionary) -> void:
	if id != _conv_id:
		return
	var lord: ManorNpc = npcs[&"lord"]
	var crane: ManorNpc = npcs[&"crane"]
	lord.push({ "kind": "door", "door": &"study_door", "op": "unlock" })
	lord.push({ "kind": "say", "text": "Good night, Crane." })
	crane.push({ "kind": "wait", "seconds": 1.0 })
	crane.push({ "kind": "go", "spot": &"drive" })
	lord.push({ "kind": "wait", "seconds": 6.0 })
	lord.push({ "kind": "read", "spot": &"library_chair" })


func _at(t: float, fn: Callable) -> void:
	_beats.append([t, fn])


func _process(delta: float) -> void:
	if _over or not player.enabled:
		return
	var R := RoomsAndDoors
	for b in _beats.duplicate():
		if R.sim_time >= float(b[0]):
			_beats.erase(b)
			(b[1] as Callable).call()
	_conversation()
	_check_t += delta
	if _check_t >= 0.25:
		_check_t = 0.0
		_check_posture_seen()
	_update_hud()
	if R.sim_time >= NIGHT_LENGTH:
		_end(false, "The house sleeps")


func _conversation() -> void:
	if _conv_started_at < 0.0 or _conv_next >= CONVERSATION.size():
		return
	var line: Array = CONVERSATION[_conv_next]
	if RoomsAndDoors.sim_time - _conv_started_at < float(line[0]):
		return
	_conv_next += 1
	var speaker: ManorNpc = npcs[line[1]]
	var h := RoomsAndDoors.hear_check(&"maid", &"study", float(line[2]), [&"lord", &"crane"])
	if bool(h["identified"]):
		hud.push_log("%s: %s" % [speaker.display_name, line[3]], "clue" if line[4] else "")
		speaker.say(line[3], 4.5)
		if line[4]:
			key_lines_identified[_conv_next] = true
			if key_lines_identified.size() >= 2 and not clue_fields:
				clue_fields = true
				hud.toast("You have it: the east fields are pledged twice, and Crane wants the house.", 5.0)
				_refresh_objectives()
				_check_win()
	elif bool(h["heard"]):
		var who := "a man" if float(line[2]) < 0.6 else "a man, raising his voice"
		hud.push_log("(%s) %s" % [who, _muffle(line[3])], "muffled")
		speaker.say(_muffle(line[3]), 3.0)


static func _muffle(text: String) -> String:
	var out := PackedStringArray()
	for w in text.split(" "):
		out.append("·".repeat(clampi(w.length() / 2, 1, 5)))
	return " ".join(out)


func _check_posture_seen() -> void:
	if player.posture == RAD.Posture.NORMAL:
		_caught_listening = false
		return
	if _caught_listening:
		return
	var room := RoomsAndDoors.room_of(&"maid")
	for id in npcs:
		if RoomsAndDoors.room_of(id) == room and not RoomsAndDoors.is_sleeping(id):
			_caught_listening = true
			var n: ManorNpc = npcs[id]
			n.say("Listening at doors, are we?" if player.posture == RAD.Posture.LISTEN else "Peeping at keyholes now?")
			_add_suspicion(22.0, "%s saw you at the door." % n.display_name)
			return


func _on_discovery(discovered: StringName, finder: StringName, room: StringName, _ctx: Dictionary) -> void:
	if discovered != &"maid" or not npcs.has(finder):
		return
	var n: ManorNpc = npcs[finder]
	var line := "What are you doing in here?"
	if finder == &"lady":
		line = "Who's there? What do you want?"
	elif finder == &"lord":
		line = "Out! This room is not for you."
	n.say(line)
	_add_suspicion(40.0, "%s found you in the %s." % [n.display_name, ManorLayout.room(room)["name"]])


func _on_ajar_discovered(door_id: StringName, finder: StringName) -> void:
	if not npcs.has(finder):
		return
	if StringName(RoomsAndDoors.get_door(door_id).get("ajar_left_by", &"")) != &"maid":
		return
	ajar_left_count += 1
	var n: ManorNpc = npcs[finder]
	n.say("Who left this standing open?")
	_add_suspicion(12.0, "%s noticed a door you left ajar." % n.display_name)


func _on_woken(id: StringName, cause: StringName) -> void:
	if id == &"lady" and cause != &"script":
		npcs[&"lady"].say("…Who's there?")
		hud.push_log("The mistress stirs.", "muffled")


func _on_knock_answered(door_id: StringName, actor: StringName, response: StringName, owner: StringName) -> void:
	if actor != &"maid" or not npcs.has(owner):
		return
	var n: ManorNpc = npcs[owner]
	match response:
		RAD.RESPONSE_COME_IN: n.say("Come in.")
		RAD.RESPONSE_WAIT: n.say("Not now.")
		_: hud.push_log("No answer from behind the %s door." % ManorLayout.room(RoomsAndDoors._far_side(door_id, actor))["name"].to_lower(), "muffled")


func _on_prop_used(id: StringName) -> void:
	match id:
		&"hearth":
			chores_done[id] = true
			builder.props[&"hearth_light"].light_energy = 2.2
			hud.toast("The library fire is laid and lit.")
		&"bed":
			chores_done[id] = true
			hud.toast("The bed is turned down. Don't linger.")
		&"jib_key":
			RoomsAndDoors.grant_key(&"maid", &"jib_key")
			builder.props[id].visible = false
			hud.toast("An old key, for the jib door on the back stair.")
		&"letter":
			if not clue_letter:
				clue_letter = true
				hud.push_log(LETTER, "clue")
				hud.toast("A letter in the mistress's hand.", 4.0)
				_check_win()
	_refresh_objectives()


func _add_suspicion(amount: float, why: String) -> void:
	suspicion = minf(100.0, suspicion + amount)
	hud.toast(why, 3.0)
	hud.push_log(why, "")
	if suspicion >= 100.0:
		_end(false, "Dismissed")


func _check_win() -> void:
	if clue_fields and clue_letter:
		_end(true, "You know what the house knows")


func _end(won: bool, title: String) -> void:
	if _over:
		return
	_over = true
	player.enabled = false
	var lines := PackedStringArray()
	if title == "Dismissed":
		lines.append("Mrs Pell has your box packed and you on the drive before midnight. Nobody believes a maid who listens at doors.")
	elif won:
		lines.append("The master has pledged the east fields twice and owes Crane the house by Michaelmas. The mistress knows, and means to be gone first, with the deed.")
	else:
		lines.append("The clocks strike, the lamps go out, and the doors keep what they heard.")
	lines.append("")
	lines.append("What you learned: %s, %s." % [
		"the double pledge" if clue_fields else "not the master's secret",
		"the mistress's letter" if clue_letter else "not the mistress's plan"])
	lines.append("Suspicion: %d / 100.   Doors you left ajar that others found: %d." % [int(suspicion), ajar_left_count])
	var tres := PackedStringArray()
	for e in RoomsAndDoors.trespass_log():
		if e["character"] == "maid":
			var nm: String = ManorLayout.room(StringName(e["room"])).get("name", e["room"])
			if not tres.has(nm):
				tres.append(nm)
	lines.append("Rooms you entered with no business there: %s." % (", ".join(tres) if not tres.is_empty() else "none"))
	hud.show_end(title, "\n".join(lines))
	ended.emit(won)


func _refresh_objectives() -> void:
	var items := []
	items.append(["Lay the library fire" + ("" if not chores_done.has(&"hearth") else " ✓"), "done" if chores_done.has(&"hearth") else ""])
	items.append(["Turn down the mistress's bed" + ("" if not chores_done.has(&"bed") else " ✓"), "done" if chores_done.has(&"bed") else ""])
	items.append(["The master's secret: " + ("pledged twice ✓" if clue_fields else "listen at his study"), "done" if clue_fields else "secret"])
	items.append(["The mistress's plan: " + ("her letter ✓" if clue_letter else "she keeps letters in her dressing room"), "done" if clue_letter else "secret"])
	hud.set_objectives(items)


func _update_hud() -> void:
	var R := RoomsAndDoors
	var h := R.clock_hour()
	var room := R.room_of(&"maid")
	var info: Dictionary = ManorLayout.room(room)
	hud.set_clock("%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)], String(info.get("name", "")))
	var adm := R.admission(&"maid", room)
	var priv := R.effective_privacy(room)
	var text := ""
	match adm:
		RAD.Admission.ON_DUTY:
			var left := R.duty_remaining(&"maid", room)
			text = "On duty here" + (" (%ds left)" % int(left) if left > 0.0 else "")
		RAD.Admission.RESIDENT, RAD.Admission.INVITED:
			text = "You belong here"
		_:
			text = "No business here — don't be found" if priv >= RAD.Privacy.PRIVATE else "Passing through"
	hud.set_suspicion(suspicion, text)
	hud.set_prompt(player.prompt_text())
