@tool
class_name TypesetterVertexGradient
extends Resource
## Four corner colours applied to every character (TMP VertexGradient).
## TMP: VertexGradient

@export var top_left: Color = Color.WHITE:
	set(v):
		top_left = v
		emit_changed()
@export var top_right: Color = Color.WHITE:
	set(v):
		top_right = v
		emit_changed()
@export var bottom_left: Color = Color.WHITE:
	set(v):
		bottom_left = v
		emit_changed()
@export var bottom_right: Color = Color.WHITE:
	set(v):
		bottom_right = v
		emit_changed()


static func create(tl: Color, tr: Color = tl, bl: Color = tl, br: Color = tl) -> TypesetterVertexGradient:
	var g := TypesetterVertexGradient.new()
	g.top_left = tl
	g.top_right = tr
	g.bottom_left = bl
	g.bottom_right = br
	return g


## [top_left, top_right, bottom_left, bottom_right].
func to_colors() -> PackedColorArray:
	return PackedColorArray([top_left, top_right, bottom_left, bottom_right])
