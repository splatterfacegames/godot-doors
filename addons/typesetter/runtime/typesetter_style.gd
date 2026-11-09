@tool
class_name TypesetterStyle
extends Resource
## A named pair of opening and closing markup used by `<style="name">` and
## `text_style` (TMP_Style).
## TMP: TMP_Style

## TMP: name
@export var name: String = "":
	set(v):
		name = v
		emit_changed()
## TMP: styleOpeningDefinition
@export_multiline var opening_definition: String = "":
	set(v):
		opening_definition = v
		emit_changed()
## TMP: styleClosingDefinition
@export_multiline var closing_definition: String = "":
	set(v):
		closing_definition = v
		emit_changed()

## TMP: hashCode
var hash_code: int:
	get:
		return TypesetterStyle.get_hash_code(name)


static func create(style_name: String, opening: String, closing: String) -> TypesetterStyle:
	var s := TypesetterStyle.new()
	s.name = style_name
	s.opening_definition = opening
	s.closing_definition = closing
	return s


## Case-insensitive name hash used for style lookups (TMP_TextUtilities.GetHashCode-style:
## h = ((h << 5) + h) ^ upper(c)).
static func get_hash_code(s: String) -> int:
	var h := 0
	for i in s.length():
		h = (((h << 5) + h) ^ s.to_upper().unicode_at(i)) & 0xFFFFFFFF
	return h


## The "Normal" style (no markup), TMP's default text style.
static func normal() -> TypesetterStyle:
	return create("Normal", "", "")
