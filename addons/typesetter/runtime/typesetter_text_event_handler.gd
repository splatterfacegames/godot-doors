@tool
class_name TypesetterTextEventHandler
extends Node
## Reports which character, word, line or link of its parent text node the
## mouse is over (TMP_TextEventHandler). Add it as a child of a TypesetterLabel
## or TypesetterText3D and connect its signals.
## TMP: TMP_TextEventHandler

## TMP: onCharacterSelection
signal character_selection(character: String, index: int)
## TMP: onSpriteSelection
signal sprite_selection(character: String, index: int)
## TMP: onWordSelection
signal word_selection(word: String, first_character_index: int, length: int)
## TMP: onLineSelection
signal line_selection(line: String, first_character_index: int, length: int)
## TMP: onLinkSelection
signal link_selection(link_id: String, link_text: String, link_index: int)

## Camera used for 3D text (null: the viewport's camera).
@export var camera: Camera3D

var _last_char := -1
var _last_word := -1
var _last_line := -1
var _last_link := -1


func _ready() -> void:
	set_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	var host := get_parent()
	if host == null or not host.has_method(&"get_text_core"):
		return
	var mp := host.get_viewport().get_mouse_position()
	var info: TypesetterTextInfo = host.text_info
	if not TypesetterTextUtilities.is_intersecting_rect(host, mp, camera):
		_last_char = -1
		_last_word = -1
		_last_line = -1
		_last_link = -1
		return
	var ci := TypesetterTextUtilities.find_intersecting_character(host, mp, camera, true)
	if ci != -1 and ci != _last_char:
		_last_char = ci
		var c: TypesetterCharacterInfo = info.character_info[ci]
		if c.element_type == 1:
			sprite_selection.emit(c.character, ci)
		else:
			character_selection.emit(c.character, ci)
	var wi := TypesetterTextUtilities.find_intersecting_word(host, mp, camera)
	if wi != -1 and wi != _last_word:
		_last_word = wi
		var w: TypesetterWordInfo = info.word_info[wi]
		word_selection.emit(w.text, w.first_character_index, w.character_count)
	var li := TypesetterTextUtilities.find_intersecting_line(host, mp, camera)
	if li != -1 and li != _last_line:
		_last_line = li
		var l: TypesetterLineInfo = info.line_info[li]
		var s := ""
		for k in range(l.first_character_index, l.last_character_index + 1):
			s += info.character_info[k].character
		line_selection.emit(s, l.first_character_index, l.character_count)
	var ki := TypesetterTextUtilities.find_intersecting_link(host, mp, camera)
	if ki != -1 and ki != _last_link:
		_last_link = ki
		var k: TypesetterLinkInfo = info.link_info[ki]
		link_selection.emit(k.link_id, k.link_text, ki)
	elif ki == -1:
		_last_link = -1
