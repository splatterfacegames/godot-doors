@tool
class_name TypesetterColorGradient
extends Resource
## A reusable colour gradient preset, used by `color_gradient_preset` and the
## `<gradient="name">` tag (TMP_ColorGradient).
## TMP: TMP_ColorGradient

enum ColorMode { SINGLE, HORIZONTAL_GRADIENT, VERTICAL_GRADIENT, FOUR_CORNERS_GRADIENT }

## TMP: colorMode
@export var color_mode: ColorMode = ColorMode.FOUR_CORNERS_GRADIENT:
	set(v):
		color_mode = v
		emit_changed()
		notify_property_list_changed()
## TMP: topLeft
@export var top_left: Color = Color.WHITE:
	set(v):
		top_left = v
		emit_changed()
## TMP: topRight
@export var top_right: Color = Color.WHITE:
	set(v):
		top_right = v
		emit_changed()
## TMP: bottomLeft
@export var bottom_left: Color = Color.WHITE:
	set(v):
		bottom_left = v
		emit_changed()
## TMP: bottomRight
@export var bottom_right: Color = Color.WHITE:
	set(v):
		bottom_right = v
		emit_changed()


static func create(mode: ColorMode, tl: Color, tr: Color = Color.WHITE, bl: Color = Color.WHITE, br: Color = Color.WHITE) -> TypesetterColorGradient:
	var g := TypesetterColorGradient.new()
	g.color_mode = mode
	g.top_left = tl
	g.top_right = tr
	g.bottom_left = bl
	g.bottom_right = br
	return g


## The effective corners for the colour mode: [top_left, top_right, bottom_left, bottom_right].
func to_colors() -> PackedColorArray:
	match color_mode:
		ColorMode.SINGLE:
			return PackedColorArray([top_left, top_left, top_left, top_left])
		ColorMode.HORIZONTAL_GRADIENT:
			return PackedColorArray([top_left, top_right, top_left, top_right])
		ColorMode.VERTICAL_GRADIENT:
			return PackedColorArray([top_left, top_left, bottom_left, bottom_left])
	return PackedColorArray([top_left, top_right, bottom_left, bottom_right])


func _validate_property(p: Dictionary) -> void:
	var hide := false
	match p.name:
		"top_right":
			hide = color_mode in [ColorMode.SINGLE, ColorMode.VERTICAL_GRADIENT]
		"bottom_left":
			hide = color_mode in [ColorMode.SINGLE, ColorMode.HORIZONTAL_GRADIENT]
		"bottom_right":
			hide = color_mode != ColorMode.FOUR_CORNERS_GRADIENT
	if hide:
		p.usage = PROPERTY_USAGE_STORAGE
