@tool
class_name TypesetterStyleSheet
extends Resource
## A table of named styles for `<style="name">` (TMP_StyleSheet).
## TMP: TMP_StyleSheet

## TMP: styles
@export var styles: Array[TypesetterStyle] = []:
	set(v):
		styles = v
		_lookup.clear()
		emit_changed()

var _lookup := {}


## The style named `style_name` (case-insensitive), or null. Accepts a hash code too.
## TMP: GetStyle(int hashCode), GetStyle(string name)
func get_style(key: Variant) -> TypesetterStyle:
	if _lookup.is_empty():
		refresh_style_dictionary()
	var h: int = key if key is int else TypesetterStyle.get_hash_code(str(key))
	return _lookup.get(h)


## TMP: RefreshStyles
func refresh_style_dictionary() -> void:
	_lookup.clear()
	for s in styles:
		if s != null:
			_lookup[s.hash_code] = s


## name (lower case) → PackedStringArray([opening, closing]) for TypesetterTextCore.style_lookup.
func to_lookup() -> Dictionary:
	var d := {}
	for s in styles:
		if s != null and not s.name.is_empty():
			d[s.name.to_lower()] = PackedStringArray([s.opening_definition, s.closing_definition])
	return d


## A style sheet with the common presets (Normal, H1–H6, Quote, Link, Title, Note…),
## written for Typesetter.
static func create_default() -> TypesetterStyleSheet:
	var sheet := TypesetterStyleSheet.new()
	var defs := [
		["Normal", "", ""],
		["H1", "<size=2em><b>", "</b></size>"],
		["H2", "<size=1.5em><b>", "</b></size>"],
		["H3", "<size=1.17em><b>", "</b></size>"],
		["H4", "<size=1em><b>", "</b></size>"],
		["H5", "<size=0.83em><b>", "</b></size>"],
		["H6", "<size=0.67em><b>", "</b></size>"],
		["Title", "<size=125%><b><align=center>", "</align></b></size>"],
		["Quote", "<i><margin=5%><color=#A0A0A0>", "</color></margin></i>"],
		["Link", "<u><color=#4080FF>", "</color></u>"],
		["Note", "<size=80%><color=#808080>", "</color></size>"],
		["C1", "<color=#FFD040>", "</color>"],
		["C2", "<color=#40A0FF>", "</color>"],
		["C3", "<color=#60E060>", "</color>"],
	]
	var arr: Array[TypesetterStyle] = []
	for d in defs:
		arr.append(TypesetterStyle.create(d[0], d[1], d[2]))
	sheet.styles = arr
	return sheet
