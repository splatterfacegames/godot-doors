class_name ManorHud
extends CanvasLayer
## The demo HUD: one UXML document (demo/ui/hud.uxml + hud.uss) loaded by godot-uxml.

signal start_pressed
signal restart_pressed
signal lab_pressed

const LOG_LINES := 7

var doc: UxmlDocument
var _log: Array = []   # [text, class]
var _toast_left: float = 0.0
var _in_help_from_title: bool = false


func _ready() -> void:
	layer = 10
	doc = UxmlDocument.new()
	doc.set_anchors_preset(Control.PRESET_FULL_RECT)
	doc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(doc)
	var err := doc.load_document("hud.uxml", "res://demo/ui")
	if err != OK:
		for d in doc.diagnostics:
			push_error(UxmlDiagnostic.format(d))
	doc.button_pressed.connect(_on_button)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			doc.set_class("toast", "toast")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).physical_keycode == KEY_ESCAPE and get_tree().paused:
		_show("help_screen", false)
		get_tree().paused = false
		get_viewport().set_input_as_handled()


func _on_button(element_name: String) -> void:
	match element_name:
		"start":
			_show("title_screen", false)
			start_pressed.emit()
		"door_lab":
			lab_pressed.emit()
		"controls":
			_in_help_from_title = true
			_show("title_screen", false)
			_show("help_screen", true)
		"resume":
			_show("help_screen", false)
			if _in_help_from_title:
				_in_help_from_title = false
				_show("title_screen", true)
			else:
				get_tree().paused = false
		"restart":
			restart_pressed.emit()


func show_help(on: bool) -> void:
	_in_help_from_title = false
	_show("help_screen", on)


func help_visible() -> bool:
	return not _has_class("help_screen", "hidden")


func show_end(title: String, body: String) -> void:
	doc.set_text("end_title", title)
	doc.set_text("end_body", body)
	_show("end_screen", true)


func set_clock(text: String, place: String) -> void:
	doc.set_text("clock", text)
	doc.set_text("place", place)


func set_objectives(items: Array) -> void:
	for i in 4:
		if i < items.size():
			doc.set_text("obj%d" % i, items[i][0])
			doc.set_class("obj%d" % i, "obj " + String(items[i][1]))
		else:
			doc.set_text("obj%d" % i, "")


func set_suspicion(v: float, admission_text: String) -> void:
	_style("sus_fill", "width: %d%%;" % int(clampf(v, 0.0, 100.0)))
	doc.set_class("sus_fill", "fill hot" if v >= 60.0 else "fill")
	doc.set_text("admission", admission_text)


func set_prompt(text: String) -> void:
	doc.set_text("prompt", text)
	doc.set_class("prompt", "prompt" if text != "" else "prompt hidden")


func set_chore(progress: float) -> void:
	if progress < 0.0:
		doc.set_class("chore_track", "chore-track hidden")
		return
	doc.set_class("chore_track", "chore-track")
	_style("chore_fill", "width: %d%%;" % int(clampf(progress, 0.0, 1.0) * 100.0))


func push_log(text: String, kind: String = "") -> void:
	_log.append([text, kind])
	while _log.size() > LOG_LINES:
		_log.pop_front()
	for i in LOG_LINES:
		if i < _log.size():
			doc.set_text("log%d" % i, _log[i][0])
			doc.set_class("log%d" % i, "line " + String(_log[i][1]))
		else:
			doc.set_text("log%d" % i, "")


func clear_log() -> void:
	_log.clear()
	push_log("", "")
	_log.clear()


func toast(text: String, seconds: float = 3.0) -> void:
	doc.set_text("toast", text)
	doc.set_class("toast", "toast show")
	_toast_left = seconds


func show_title(on: bool) -> void:
	_show("title_screen", on)
	if on:
		_show("end_screen", false)


func _show(element: String, on: bool) -> void:
	var el := doc.get_element_model(element)
	if el == null:
		return
	var cls := "overlay" if not on else "overlay"
	doc.set_class(element, cls if on else cls + " hidden")


func _has_class(element: String, cls: String) -> bool:
	var el := doc.get_element_model(element)
	return el != null and String(el.get_attribute("class")).split(" ").has(cls)


func _style(element: String, css: String) -> void:
	var el := doc.get_element_model(element)
	if el != null:
		el.set_attribute("style", css)
