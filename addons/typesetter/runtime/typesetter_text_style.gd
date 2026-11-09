@tool
class_name TypesetterTextStyle
extends Resource
## Everything that decides how a TypesetterTextLayout looks, in one object.
##
## Fields match TypesetterLabel's so a style can be filled from CSS-like text
## properties (godot-uxml's USS, for example).

@export var font: TypesetterFontAsset
@export var font_size: float = 36.0
@export var color: Color = Color.WHITE
## TypesetterLabel.FontStyles flags.
@export var font_style: int = 0
@export var font_weight: int = 400
## TypesetterLabel.HorizontalAlignmentOptions | VerticalAlignmentOptions.
@export var alignment: int = 0x101
## TypesetterLabel.TextWrappingModes value (1 = Normal).
@export var text_wrapping_mode: int = 1
## TypesetterLabel.TextOverflowModes value (0 = Overflow).
@export var overflow_mode: int = 0
@export var character_spacing: float = 0.0
@export var word_spacing: float = 0.0
@export var line_spacing: float = 0.0
@export var paragraph_spacing: float = 0.0
## Left, top, right, bottom.
@export var margin: Vector4 = Vector4.ZERO
@export var rich_text: bool = true
@export var enable_kerning: bool = true
@export var extra_padding: bool = false

@export_group("Outline")
## In the shader's normalized units (0..1), as `outline_width` on a material.
@export_range(0.0, 1.0) var outline_width: float = 0.0
@export var outline_color: Color = Color.BLACK

@export_group("Underlay")
@export var underlay_enabled: bool = false
@export var underlay_color: Color = Color(0, 0, 0, 0.5)
@export_range(-1.0, 1.0) var underlay_offset_x: float = 0.0
@export_range(-1.0, 1.0) var underlay_offset_y: float = 0.0
@export_range(-1.0, 1.0) var underlay_dilate: float = 0.0
@export_range(0.0, 1.0) var underlay_softness: float = 0.0

@export_group("Material")
## Used as is when set; the outline and underlay fields above are then ignored.
@export var material: Material


## True when the style needs its own copy of the font's default material.
func needs_own_material() -> bool:
	return material == null and (outline_width > 0.0 or underlay_enabled)
