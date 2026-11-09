@tool
class_name TypesetterSpriteGlyph
extends Resource
## One sprite's rectangle and metrics in sprite-sheet pixels (TMP_SpriteGlyph).
## TMP: TMP_SpriteGlyph

## TMP: index
@export var index: int = 0
## Rectangle in the sprite sheet (top-left origin). TMP: glyphRect
@export var glyph_rect: Rect2i
## TMP: metrics.width
@export var metrics_width: float = 0.0
## TMP: metrics.height
@export var metrics_height: float = 0.0
## TMP: metrics.horizontalBearingX
@export var bearing_x: float = 0.0
## TMP: metrics.horizontalBearingY
@export var bearing_y: float = 0.0
## TMP: metrics.horizontalAdvance
@export var advance: float = 0.0
## TMP: scale
@export var scale: float = 1.0
## Number of animation frames starting at this glyph when used with `anim`.
@export var atlas_index: int = 0


static func create(glyph_index: int, rect: Rect2i) -> TypesetterSpriteGlyph:
	var g := TypesetterSpriteGlyph.new()
	g.index = glyph_index
	g.glyph_rect = rect
	g.metrics_width = rect.size.x
	g.metrics_height = rect.size.y
	g.bearing_x = 0.0
	g.bearing_y = rect.size.y * 0.8
	g.advance = rect.size.x
	return g
