@tool
@icon("res://addons/typesetter/icons/typesetter_text_3d.svg")
class_name TypesetterText3D
extends GeometryInstance3D
## Signed-distance-field text in 3D space (TextMeshPro).
##
## Lays out rich text inside a `rect_size` rectangle around `pivot`, in units
## where font size 10 is one unit tall (TMP's world-space scale), and draws it
## with Typesetter's distance-field shaders: sharp at any distance, angle or
## perspective. The API follows TextMesh Pro's TMP_Text one-to-one in
## snake_case; see docs/api-map.md.
## TMP: TextMeshPro

@export_group("Container")
## Size of the text container in node units.
## TMP: rectTransform.sizeDelta
@export var rect_size: Vector2 = Vector2(20, 5):
	set(value):
		if rect_size == value:
			return
		rect_size = value
		_ts_on_changed(&"rect_size", 1)
## Point of the container placed at the node origin (0–1).
## TMP: rectTransform.pivot
@export var pivot: Vector2 = Vector2(0.5, 0.5):
	set(value):
		if pivot == value:
			return
		pivot = value
		_ts_on_changed(&"pivot", 1)
@export_group("Rendering")
## Draws on top of other geometry (Overlay shader, no depth test).
## TMP: isOverlay
@export var is_overlay: bool = false:
	set(value):
		if is_overlay == value:
			return
		is_overlay = value
		_ts_on_changed(&"is_overlay", 4)
## Order among transparent objects (maps to `sorting_offset`).
## TMP: sortingOrder
@export var sorting_order: int = 0:
	set(value):
		if sorting_order == value:
			return
		sorting_order = value
		_ts_on_changed(&"sorting_order", 4)
## Accepted for compatibility; text is planar.
## TMP: isVolumetricText
var is_volumetric_text: bool = false:
	set(value):
		if is_volumetric_text == value:
			return
		is_volumetric_text = value
		_ts_on_changed(&"is_volumetric_text", 0)

# ---------------------------------------------------------------------------
# TMP_Text API shared by TypesetterLabel and TypesetterText3D.
# Generated from tools/api/text_common.gd.in by tools/make_api.py; edit there.
# ---------------------------------------------------------------------------

## Emitted after the text is laid out and its geometry built, before it is
## drawn. Edit `text_info.mesh_info` here and call `update_vertex_data()` to
## animate vertices.
## TMP: OnPreRenderText
signal pre_render_text(text_info: TypesetterTextInfo)
## Emitted when `text` changes.
## TMP: TMPro_EventManager.TEXT_CHANGED_EVENT
signal text_changed()

## TMP: FontStyles
enum FontStyles { NORMAL = 0, BOLD = 1, ITALIC = 2, UNDERLINE = 4, LOWER_CASE = 8, UPPER_CASE = 16, SMALL_CAPS = 32, STRIKETHROUGH = 64, SUPERSCRIPT = 128, SUBSCRIPT = 256, HIGHLIGHT = 512 }
## TMP: FontWeight
enum FontWeight { THIN = 100, EXTRA_LIGHT = 200, LIGHT = 300, REGULAR = 400, MEDIUM = 500, SEMI_BOLD = 600, BOLD = 700, HEAVY = 800, BLACK = 900 }
## TMP: HorizontalAlignmentOptions
enum HorizontalAlignmentOptions { LEFT = 0x1, CENTER = 0x2, RIGHT = 0x4, JUSTIFIED = 0x8, FLUSH = 0x10, GEOMETRY = 0x20 }
## TMP: VerticalAlignmentOptions
enum VerticalAlignmentOptions { TOP = 0x100, MIDDLE = 0x200, BOTTOM = 0x400, BASELINE = 0x800, GEOMETRY = 0x1000, CAPLINE = 0x2000 }
## TMP: TextAlignmentOptions
enum TextAlignmentOptions {
	TOP_LEFT = 0x101, TOP = 0x102, TOP_RIGHT = 0x104, TOP_JUSTIFIED = 0x108, TOP_FLUSH = 0x110, TOP_GEO_ALIGNED = 0x120,
	LEFT = 0x201, CENTER = 0x202, RIGHT = 0x204, JUSTIFIED = 0x208, FLUSH = 0x210, CENTER_GEO_ALIGNED = 0x220,
	BOTTOM_LEFT = 0x401, BOTTOM = 0x402, BOTTOM_RIGHT = 0x404, BOTTOM_JUSTIFIED = 0x408, BOTTOM_FLUSH = 0x410, BOTTOM_GEO_ALIGNED = 0x420,
	BASELINE_LEFT = 0x801, BASELINE = 0x802, BASELINE_RIGHT = 0x804, BASELINE_JUSTIFIED = 0x808, BASELINE_FLUSH = 0x810, BASELINE_GEO_ALIGNED = 0x820,
	MIDLINE_LEFT = 0x1001, MIDLINE = 0x1002, MIDLINE_RIGHT = 0x1004, MIDLINE_JUSTIFIED = 0x1008, MIDLINE_FLUSH = 0x1010, MIDLINE_GEO_ALIGNED = 0x1020,
	CAPLINE_LEFT = 0x2001, CAPLINE = 0x2002, CAPLINE_RIGHT = 0x2004, CAPLINE_JUSTIFIED = 0x2008, CAPLINE_FLUSH = 0x2010, CAPLINE_GEO_ALIGNED = 0x2020,
	CONVERTED = 0xFFFF,
}
## TMP: TextWrappingModes
enum TextWrappingModes { NO_WRAP = 0, NORMAL = 1, PRESERVE_WHITESPACE = 2, PRESERVE_WHITESPACE_NO_WRAP = 3 }
## TMP: TextOverflowModes
enum TextOverflowModes { OVERFLOW = 0, ELLIPSIS = 1, MASKING = 2, TRUNCATE = 3, SCROLL_RECT = 4, PAGE = 5, LINKED = 6 }
## TMP: TextureMappingOptions
enum TextureMappingOptions { CHARACTER = 0, LINE = 1, PARAGRAPH = 2, MATCH_ASPECT = 3 }
## TMP: TextRenderFlags
enum TextRenderFlags { DONT_RENDER = 0, RENDER = 255 }
## TMP: VertexSortingOrder
enum VertexSortingOrder { NORMAL = 0, REVERSE = 1 }
## TMP: TMP_VertexDataUpdateFlags
enum VertexDataUpdateFlags { NONE = 0, VERTICES = 1, UV0 = 2, UV2 = 4, UV4 = 8, COLORS32 = 16, ALL = 255 }
## OpenType layout features applied by the layout (TMP OTL_FeatureTag).
## TMP: OTL_FeatureTag
enum FontFeatures { KERN = 1, LIGA = 2, MARK = 4, MKMK = 8 }

@export_group("Text")
## The text to display. Supports rich text tags when `rich_text` is on.
## TMP: text
@export_multiline var text: String = "":
	set(value):
		if text == value:
			return
		text = value
		_ts_on_changed(&"text", 9)
@export_group("Main Settings")
## The font asset. Null uses `TypesetterSettings.get_default_font_asset()`.
## TMP: font
@export var font: TypesetterFontAsset = null:
	set(value):
		if font == value:
			return
		_ts_watch(font, value)
		font = value
		_ts_on_changed(&"font", 5)
## The material shared with other text using it. Null uses the font asset's material.
## TMP: fontSharedMaterial
@export var font_shared_material: Material = null:
	set(value):
		if font_shared_material == value:
			return
		font_shared_material = value
		_ts_on_changed(&"font_shared_material", 4)
## Style flags applied to the whole text (FontStyles).
## TMP: fontStyle
@export_flags("Bold:1", "Italic:2", "Underline:4", "Lower Case:8", "Upper Case:16", "Small Caps:32", "Strikethrough:64", "Superscript:128", "Subscript:256", "Highlight:512") var font_style: int = 0:
	set(value):
		if font_style == value:
			return
		font_style = value
		_ts_on_changed(&"font_style", 1)
## Point size of the text.
## TMP: fontSize
@export_range(0.0, 2000.0, 0.01, "or_greater") var font_size: float = 36.0:
	set(value):
		if font_size == value:
			return
		font_size = value
		_ts_on_changed(&"font_size", 1)
## Picks the largest size between `font_size_min` and `font_size_max` that fits the container.
## TMP: enableAutoSizing
@export var enable_auto_sizing: bool = false:
	set(value):
		if enable_auto_sizing == value:
			return
		enable_auto_sizing = value
		_ts_on_changed(&"enable_auto_sizing", 1)
## Smallest size auto-sizing may pick.
## TMP: fontSizeMin
@export_range(0.0, 2000.0, 0.01, "or_greater") var font_size_min: float = 18.0:
	set(value):
		if font_size_min == value:
			return
		font_size_min = value
		_ts_on_changed(&"font_size_min", 1)
## Largest size auto-sizing may pick.
## TMP: fontSizeMax
@export_range(0.0, 2000.0, 0.01, "or_greater") var font_size_max: float = 72.0:
	set(value):
		if font_size_max == value:
			return
		font_size_max = value
		_ts_on_changed(&"font_size_max", 1)
## Auto-sizing: maximum horizontal compression in percent before the size drops.
## TMP: characterWidthAdjustment
@export_range(0.0, 50.0, 0.01) var character_width_adjustment: float = 0.0:
	set(value):
		if character_width_adjustment == value:
			return
		character_width_adjustment = value
		_ts_on_changed(&"character_width_adjustment", 1)
## Auto-sizing: maximum negative line spacing before the size drops.
## TMP: lineSpacingAdjustment
@export_range(-100.0, 0.0, 0.01) var line_spacing_adjustment: float = 0.0:
	set(value):
		if line_spacing_adjustment == value:
			return
		line_spacing_adjustment = value
		_ts_on_changed(&"line_spacing_adjustment", 1)
## Weight used to pick a face from the font asset's weight table.
## TMP: fontWeight
@export var font_weight: FontWeight = FontWeight.REGULAR:
	set(value):
		if font_weight == value:
			return
		font_weight = value
		_ts_on_changed(&"font_weight", 1)
## Vertex colour of the text.
## TMP: color
@export var color: Color = Color.WHITE:
	set(value):
		if color == value:
			return
		color = value
		_ts_on_changed(&"color", 1)
## Applies `color_gradient` (or `color_gradient_preset`) to every character.
## TMP: enableVertexGradient
@export var enable_vertex_gradient: bool = false:
	set(value):
		if enable_vertex_gradient == value:
			return
		enable_vertex_gradient = value
		_ts_on_changed(&"enable_vertex_gradient", 1)
## Corner colours used when `enable_vertex_gradient` is on.
## TMP: colorGradient
@export var color_gradient: TypesetterVertexGradient = null:
	set(value):
		if color_gradient == value:
			return
		_ts_watch(color_gradient, value)
		color_gradient = value
		_ts_on_changed(&"color_gradient", 1)
## A gradient preset; overrides `color_gradient` when set.
## TMP: colorGradientPreset
@export var color_gradient_preset: TypesetterColorGradient = null:
	set(value):
		if color_gradient_preset == value:
			return
		_ts_watch(color_gradient_preset, value)
		color_gradient_preset = value
		_ts_on_changed(&"color_gradient_preset", 1)
## Ignores `<color>` tags and uses `color`.
## TMP: overrideColorTags
@export var override_color_tags: bool = false:
	set(value):
		if override_color_tags == value:
			return
		override_color_tags = value
		_ts_on_changed(&"override_color_tags", 1)
@export_group("Spacing")
## Extra space between characters, in hundredths of an em.
## TMP: characterSpacing
@export var character_spacing: float = 0.0:
	set(value):
		if character_spacing == value:
			return
		character_spacing = value
		_ts_on_changed(&"character_spacing", 1)
## Extra space between words, in hundredths of an em.
## TMP: wordSpacing
@export var word_spacing: float = 0.0:
	set(value):
		if word_spacing == value:
			return
		word_spacing = value
		_ts_on_changed(&"word_spacing", 1)
## Extra space between lines, in hundredths of an em.
## TMP: lineSpacing
@export var line_spacing: float = 0.0:
	set(value):
		if line_spacing == value:
			return
		line_spacing = value
		_ts_on_changed(&"line_spacing", 1)
## Extra space between paragraphs, in hundredths of an em.
## TMP: paragraphSpacing
@export var paragraph_spacing: float = 0.0:
	set(value):
		if paragraph_spacing == value:
			return
		paragraph_spacing = value
		_ts_on_changed(&"paragraph_spacing", 1)
@export_group("Alignment")
## Horizontal alignment.
## TMP: horizontalAlignment
@export var horizontal_alignment: HorizontalAlignmentOptions = HorizontalAlignmentOptions.LEFT:
	set(value):
		if horizontal_alignment == value:
			return
		horizontal_alignment = value
		_ts_on_changed(&"horizontal_alignment", 1)
## Vertical alignment.
## TMP: verticalAlignment
@export var vertical_alignment: VerticalAlignmentOptions = VerticalAlignmentOptions.TOP:
	set(value):
		if vertical_alignment == value:
			return
		vertical_alignment = value
		_ts_on_changed(&"vertical_alignment", 1)
## Justified text: share of the extra space given to characters (the rest goes to spaces).
## TMP: wordWrappingRatios
@export_range(0.0, 1.0, 0.01) var word_wrapping_ratios: float = 0.4:
	set(value):
		if word_wrapping_ratios == value:
			return
		word_wrapping_ratios = value
		_ts_on_changed(&"word_wrapping_ratios", 1)
@export_group("Wrapping and Overflow")
## How lines wrap and whether white space is preserved.
## TMP: textWrappingMode
@export var text_wrapping_mode: TextWrappingModes = TextWrappingModes.NORMAL:
	set(value):
		if text_wrapping_mode == value:
			return
		text_wrapping_mode = value
		_ts_on_changed(&"text_wrapping_mode", 1)
## What happens to text that does not fit.
## TMP: overflowMode
@export var overflow_mode: TextOverflowModes = TextOverflowModes.OVERFLOW:
	set(value):
		if overflow_mode == value:
			return
		overflow_mode = value
		_ts_on_changed(&"overflow_mode", 5)
## Text node that receives the overflow in Linked mode.
## TMP: linkedTextComponent
@export var linked_text_component: Node = null:
	set(value):
		if linked_text_component == value:
			return
		linked_text_component = value
		_ts_on_changed(&"linked_text_component", 1)
## Page shown in Page overflow mode (1-based).
## TMP: pageToDisplay
@export_range(1, 1000, 1, "or_greater") var page_to_display: int = 1:
	set(value):
		if page_to_display == value:
			return
		page_to_display = value
		_ts_on_changed(&"page_to_display", 1)
@export_group("UV Mapping")
## How the face and outline textures map horizontally.
## TMP: horizontalMapping
@export var horizontal_mapping: TextureMappingOptions = TextureMappingOptions.CHARACTER:
	set(value):
		if horizontal_mapping == value:
			return
		horizontal_mapping = value
		_ts_on_changed(&"horizontal_mapping", 1)
## How the face and outline textures map vertically.
## TMP: verticalMapping
@export var vertical_mapping: TextureMappingOptions = TextureMappingOptions.CHARACTER:
	set(value):
		if vertical_mapping == value:
			return
		vertical_mapping = value
		_ts_on_changed(&"vertical_mapping", 1)
## Horizontal UV offset applied per line with Line or Paragraph mapping.
## TMP: mappingUvLineOffset
@export var mapping_uv_line_offset: float = 0.0:
	set(value):
		if mapping_uv_line_offset == value:
			return
		mapping_uv_line_offset = value
		_ts_on_changed(&"mapping_uv_line_offset", 1)
@export_group("Extra Settings")
## Inset of the text area from the container: left, top, right, bottom.
## TMP: margin
@export var margin: Vector4 = Vector4.ZERO:
	set(value):
		if margin == value:
			return
		margin = value
		_ts_on_changed(&"margin", 1)
## Draw order of the character quads.
## TMP: geometrySortingOrder
@export var geometry_sorting_order: VertexSortingOrder = VertexSortingOrder.NORMAL:
	set(value):
		if geometry_sorting_order == value:
			return
		geometry_sorting_order = value
		_ts_on_changed(&"geometry_sorting_order", 2)
## Skips per-frame scale checks (the scale is folded into the shader by derivatives, so this has no cost either way).
## TMP: isTextObjectScaleStatic
@export var is_text_object_scale_static: bool = false:
	set(value):
		if is_text_object_scale_static == value:
			return
		is_text_object_scale_static = value
		_ts_on_changed(&"is_text_object_scale_static", 0)
## Parses rich text tags.
## TMP: richText
@export var rich_text: bool = true:
	set(value):
		if rich_text == value:
			return
		rich_text = value
		_ts_on_changed(&"rich_text", 1)
## Turns `
## `, `\t` and friends written as two characters into control characters.
## TMP: parseCtrlCharacters
@export var parse_ctrl_characters: bool = true:
	set(value):
		if parse_ctrl_characters == value:
			return
		parse_ctrl_characters = value
		_ts_on_changed(&"parse_ctrl_characters", 1)
## With `max_visible_*`, vertical alignment uses the descender of the visible lines only.
## TMP: useMaxVisibleDescender
@export var use_max_visible_descender: bool = true:
	set(value):
		if use_max_visible_descender == value:
			return
		use_max_visible_descender = value
		_ts_on_changed(&"use_max_visible_descender", 1)
## Sprite asset for `<sprite>` tags. Null uses the project default.
## TMP: spriteAsset
@export var sprite_asset: TypesetterSpriteAsset = null:
	set(value):
		if sprite_asset == value:
			return
		_ts_watch(sprite_asset, value)
		sprite_asset = value
		_ts_on_changed(&"sprite_asset", 1)
## Multiplies sprites by the text colour.
## TMP: tintAllSprites
@export var tint_all_sprites: bool = false:
	set(value):
		if tint_all_sprites == value:
			return
		tint_all_sprites = value
		_ts_on_changed(&"tint_all_sprites", 1)
## Style sheet for `<style>` tags. Null uses the project default.
## TMP: styleSheet
@export var style_sheet: TypesetterStyleSheet = null:
	set(value):
		if style_sheet == value:
			return
		_ts_watch(style_sheet, value)
		style_sheet = value
		_ts_on_changed(&"style_sheet", 1)
## A style applied to the whole text.
## TMP: textStyle
@export var text_style: TypesetterStyle = null:
	set(value):
		if text_style == value:
			return
		_ts_watch(text_style, value)
		text_style = value
		_ts_on_changed(&"text_style", 1)
## OpenType layout features applied (FontFeatures).
## TMP: fontFeatures
@export_flags("kern:1", "liga:2", "mark:4", "mkmk:8") var font_features: int = 3:
	set(value):
		if font_features == value:
			return
		font_features = value
		_ts_on_changed(&"font_features", 1)
## Adds padding around each character's quad for effects that extend beyond it.
## TMP: extraPadding
@export var extra_padding: bool = false:
	set(value):
		if extra_padding == value:
			return
		extra_padding = value
		_ts_on_changed(&"extra_padding", 1)
## Looks up emoji in the emoji fallback assets first.
## TMP: emojiFallbackSupport
@export var emoji_fallback_support: bool = true:
	set(value):
		if emoji_fallback_support == value:
			return
		emoji_fallback_support = value
		_ts_on_changed(&"emoji_fallback_support", 1)
## Lays the text out right to left.
## TMP: isRightToLeftText
@export var is_right_to_left_text: bool = false:
	set(value):
		if is_right_to_left_text == value:
			return
		is_right_to_left_text = value
		_ts_on_changed(&"is_right_to_left_text", 1)
## Hint for orthographic projection; the shaders derive anti-aliasing from screen derivatives, so it only affects `perspective_filter`.
## TMP: isOrthographic
@export var is_orthographic: bool = false:
	set(value):
		if is_orthographic == value:
			return
		is_orthographic = value
		_ts_on_changed(&"is_orthographic", 4)
## Skips drawing when the text is outside the view.
## TMP: enableCulling
@export var enable_culling: bool = false:
	set(value):
		if enable_culling == value:
			return
		enable_culling = value
		_ts_on_changed(&"enable_culling", 0)
## Keeps updating geometry while hidden.
## TMP: ignoreVisibility
@export var ignore_visibility: bool = false:
	set(value):
		if ignore_visibility == value:
			return
		ignore_visibility = value
		_ts_on_changed(&"ignore_visibility", 0)
## Set to DONT_RENDER to lay out text without drawing it.
## TMP: renderMode
@export var render_mode: TextRenderFlags = TextRenderFlags.RENDER:
	set(value):
		if render_mode == value:
			return
		render_mode = value
		_ts_on_changed(&"render_mode", 2)
## Shrinks vertex buffers when the text gets shorter (always on: buffers are rebuilt to size).
## TMP: vertexBufferAutoSizeReduction
@export var vertex_buffer_auto_size_reduction: bool = false:
	set(value):
		if vertex_buffer_auto_size_reduction == value:
			return
		vertex_buffer_auto_size_reduction = value
		_ts_on_changed(&"vertex_buffer_auto_size_reduction", 0)
## Accepted for compatibility; has no effect.
## TMP: isUsingLegacyAnimationComponent
var is_using_legacy_animation_component: bool = false:
	set(value):
		if is_using_legacy_animation_component == value:
			return
		is_using_legacy_animation_component = value
		_ts_on_changed(&"is_using_legacy_animation_component", 0)
## Resizes the container to the text's preferred size.
## TMP: autoSizeTextContainer
@export var auto_size_text_container: bool = false:
	set(value):
		if auto_size_text_container == value:
			return
		auto_size_text_container = value
		_ts_on_changed(&"auto_size_text_container", 1)
@export_group("Visibility")
## First character shown (used by Linked overflow).
## TMP: firstVisibleCharacter
@export_range(0, 99999, 1, "or_greater") var first_visible_character: int = 0:
	set(value):
		if first_visible_character == value:
			return
		first_visible_character = value
		_ts_on_changed(&"first_visible_character", 1)
## Number of characters shown (typewriter effects).
## TMP: maxVisibleCharacters
@export_range(0, 99999, 1, "or_greater") var max_visible_characters: int = 99999:
	set(value):
		if max_visible_characters == value:
			return
		max_visible_characters = value
		_ts_on_changed(&"max_visible_characters", 1)
## Number of words shown.
## TMP: maxVisibleWords
@export_range(0, 99999, 1, "or_greater") var max_visible_words: int = 99999:
	set(value):
		if max_visible_words == value:
			return
		max_visible_words = value
		_ts_on_changed(&"max_visible_words", 1)
## Number of lines shown.
## TMP: maxVisibleLines
@export_range(0, 99999, 1, "or_greater") var max_visible_lines: int = 99999:
	set(value):
		if max_visible_lines == value:
			return
		max_visible_lines = value
		_ts_on_changed(&"max_visible_lines", 1)
@export_group("")
## Object with `preprocess_text(text: String) -> String`, run before parsing (ITextPreprocessor).
## TMP: textPreprocessor
var text_preprocessor: Object = null:
	set(value):
		if text_preprocessor == value:
			return
		text_preprocessor = value
		_ts_on_changed(&"text_preprocessor", 1)

var _ts_core: TypesetterTextCore = TypesetterTextCore.new()
# Settings other than the text were last copied into _ts_core at this state;
# a text change then only sends the text (see _ts_sync_core).
var _ts_settings_stale := true
# Properties the core takes as they are and that touch nothing else (padding,
# materials, lookups): a change is sent on its own instead of forcing a full sync,
# so animating font size or spacing costs about what a text change does.
const _TS_CORE_DIRECT := {
	&"font_size": true, &"font_size_min": true, &"font_size_max": true,
	&"character_width_adjustment": true, &"line_spacing_adjustment": true, &"color": true,
	&"override_color_tags": true, &"character_spacing": true, &"word_spacing": true,
	&"line_spacing": true, &"paragraph_spacing": true, &"word_wrapping_ratios": true,
	&"text_wrapping_mode": true, &"page_to_display": true, &"horizontal_mapping": true,
	&"vertical_mapping": true, &"mapping_uv_line_offset": true, &"margin": true,
	&"use_max_visible_descender": true, &"is_right_to_left_text": true,
	&"first_visible_character": true, &"max_visible_characters": true,
	&"max_visible_words": true, &"max_visible_lines": true,
}
var _ts_pending_core := {}
var _ts_synced_lookup_revision := -1
var _ts_synced_bold_tag := false
var _ts_material_cache := {}
var _ts_material_cache_stale := true
var _ts_dirty_layout := true
var _ts_dirty_vertices := true
var _ts_dirty_material := true
var _ts_queued := false
var _ts_surfaces: Array[Dictionary] = []
var _ts_font_material_instance: Material
var _ts_font_materials_instances: Array[Material] = []
var _ts_tint := Color.WHITE
var _ts_watched := {}
var _ts_linked_parent: Node
var _ts_linked_start := -1
var _ts_info_requested := false
var _ts_parsed_cache := ""
var _ts_have_properties_changed := false


## Scale from the font asset's sampling size to the current size (after auto-sizing).
## TMP: fontScale
var font_scale: float:
	get:
		return _ts_get_font_scale()
	set(_value):
		push_error("font_scale is read-only")

func _ts_get_font_scale() -> float:
	_ts_ensure_layout()
	var a := _ts_font()
	if a == null or a.face_info == null:
		return 1.0
	var s := get_font_size_resolved() / a.face_info.point_size
	return s * (0.1 if _ts_is_3d() else 1.0)


## Pixels per node unit (1 for TypesetterLabel; 10 for TypesetterText3D at the default scale).
## TMP: pixelsPerUnit
var pixels_per_unit: float:
	get:
		return _ts_get_pixels_per_unit()
	set(_value):
		push_error("pixels_per_unit is read-only")

func _ts_get_pixels_per_unit() -> float:
	return 10.0 if _ts_is_3d() else 1.0


## True when bold is applied by `font_style` or a `<b>` tag.
## TMP: isUsingBold
var is_using_bold: bool:
	get:
		return _ts_get_is_using_bold()
	set(_value):
		push_error("is_using_bold is read-only")

func _ts_get_is_using_bold() -> bool:
	if font_style & FontStyles.BOLD:
		return true
	_ts_ensure_layout()
	var info := _ts_core.get_text_info()
	for i in info.character_count:
		if info.character_info[i].style & FontStyles.BOLD:
			return true
	return false


## Horizontal and vertical alignment combined.
## TMP: alignment
var alignment: TextAlignmentOptions:
	get:
		return _ts_get_alignment()
	set(value):
		_ts_set_alignment(value)

func _ts_get_alignment() -> int:
	return horizontal_alignment | vertical_alignment


func _ts_set_alignment(v: int) -> void:
	if v == TextAlignmentOptions.CONVERTED:
		return
	horizontal_alignment = (v & 0xFF) as HorizontalAlignmentOptions
	vertical_alignment = (v & 0xFF00) as VerticalAlignmentOptions


## Alpha of `color`.
## TMP: alpha
var alpha: float:
	get:
		return _ts_get_alpha()
	set(value):
		_ts_set_alpha(value)

func _ts_get_alpha() -> float:
	return color.a


func _ts_set_alpha(v: float) -> void:
	var c := color
	c.a = v
	color = c


## Obsolete alias for `text_wrapping_mode` (NORMAL / NO_WRAP).
## TMP: enableWordWrapping
var enable_word_wrapping: bool:
	get:
		return _ts_get_enable_word_wrapping()
	set(value):
		_ts_set_enable_word_wrapping(value)

func _ts_get_enable_word_wrapping() -> bool:
	return text_wrapping_mode == TextWrappingModes.NORMAL or text_wrapping_mode == TextWrappingModes.PRESERVE_WHITESPACE


func _ts_set_enable_word_wrapping(v: bool) -> void:
	text_wrapping_mode = TextWrappingModes.NORMAL if v else TextWrappingModes.NO_WRAP


## Obsolete alias for the `kern` bit of `font_features`.
## TMP: enableKerning
var enable_kerning: bool:
	get:
		return _ts_get_enable_kerning()
	set(value):
		_ts_set_enable_kerning(value)

func _ts_get_enable_kerning() -> bool:
	return font_features & FontFeatures.KERN != 0


func _ts_set_enable_kerning(v: bool) -> void:
	font_features = (font_features | FontFeatures.KERN) if v else (font_features & ~FontFeatures.KERN)


## This node's own copy of the material (created on first access); edits do not affect other text.
## TMP: fontMaterial
var font_material: Material:
	get:
		return _ts_get_font_material()
	set(value):
		_ts_set_font_material(value)

func _ts_get_font_material() -> Material:
	if _ts_font_material_instance == null:
		var base := _ts_base_shared_material()
		if base != null:
			_ts_font_material_instance = base.duplicate()
			_ts_font_material_instance.resource_name = base.resource_name + " (Instance)"
			# With the atlas bound, 2D text draws with this very material, so editing
			# its parameters shows at once (TMP's fontMaterial.SetFloat).
			if _ts_font_material_instance is ShaderMaterial and _ts_font() != null:
				TypesetterMaterialManager.apply_font_asset(_ts_font_material_instance, _ts_font(), 0)
		_ts_set_material_dirty()
	return _ts_font_material_instance


func _ts_set_font_material(v: Material) -> void:
	_ts_font_material_instance = v
	# Assigning a material (edited or not) refreshes the copies drawn for other
	# atlases, fallbacks and 3D.
	TypesetterMaterialManager.mark_changed(v)
	_ts_set_material_dirty()
	_ts_set_layout_dirty()


## Materials of every surface (primary first), shared.
## TMP: fontSharedMaterials
var font_shared_materials: Array:
	get:
		return _ts_get_font_shared_materials()
	set(value):
		_ts_set_font_shared_materials(value)

func _ts_get_font_shared_materials() -> Array:
	var out: Array = []
	for s in _ts_surfaces:
		if s.get("material_used") != null and not out.has(s.material_used):
			out.append(s.material_used)
	if out.is_empty():
		out.append(_ts_base_shared_material())
	return out


func _ts_set_font_shared_materials(v: Array) -> void:
	if not v.is_empty():
		font_shared_material = v[0]


## Instanced materials of every surface.
## TMP: fontMaterials
var font_materials: Array:
	get:
		return _ts_get_font_materials()
	set(value):
		_ts_set_font_materials(value)

func _ts_get_font_materials() -> Array:
	return [_ts_get_font_material()]


func _ts_set_font_materials(v: Array) -> void:
	if not v.is_empty():
		_ts_set_font_material(v[0])


## The material's face colour (instances the material).
## TMP: faceColor
var face_color: Color:
	get:
		return _ts_get_face_color()
	set(value):
		_ts_set_face_color(value)

func _ts_get_face_color() -> Color:
	return _ts_material_param(&"face_color", Color.WHITE)


func _ts_set_face_color(v: Color) -> void:
	_ts_set_material_param(&"face_color", v)


## The material's outline colour (instances the material).
## TMP: outlineColor
var outline_color: Color:
	get:
		return _ts_get_outline_color()
	set(value):
		_ts_set_outline_color(value)

func _ts_get_outline_color() -> Color:
	return _ts_material_param(&"outline_color", Color.BLACK)


func _ts_set_outline_color(v: Color) -> void:
	_ts_set_material_param(&"outline_color", v)


## The material's outline width, 0–1 (instances the material).
## TMP: outlineWidth
var outline_width: float:
	get:
		return _ts_get_outline_width()
	set(value):
		_ts_set_outline_width(value)

func _ts_get_outline_width() -> float:
	return _ts_material_param(&"outline_width", 0.0)


func _ts_set_outline_width(v: float) -> void:
	_ts_set_material_param(&"outline_width", v)


## True when the text does not fit vertically.
## TMP: isTextOverflowing
var is_text_overflowing: bool:
	get:
		return _ts_get_is_text_overflowing()
	set(_value):
		push_error("is_text_overflowing is read-only")

func _ts_get_is_text_overflowing() -> bool:
	_ts_ensure_layout()
	return _ts_core.is_text_overflowing()


## Index of the first character that did not fit, or -1.
## TMP: firstOverflowCharacterIndex
var first_overflow_character_index: int:
	get:
		return _ts_get_first_overflow_character_index()
	set(_value):
		push_error("first_overflow_character_index is read-only")

func _ts_get_first_overflow_character_index() -> int:
	_ts_ensure_layout()
	return _ts_core.get_first_overflow_character_index()


## True when Truncate or Ellipsis cut the text.
## TMP: isTextTruncated
var is_text_truncated: bool:
	get:
		return _ts_get_is_text_truncated()
	set(_value):
		push_error("is_text_truncated is read-only")

func _ts_get_is_text_truncated() -> bool:
	_ts_ensure_layout()
	return (overflow_mode == TextOverflowModes.TRUNCATE or overflow_mode == TextOverflowModes.ELLIPSIS) and _ts_core.get_first_overflow_character_index() >= 0


## Characters, words, lines, links, pages and meshes of the current layout.
## TMP: textInfo
var text_info: TypesetterTextInfo:
	get:
		return _ts_get_text_info()
	set(_value):
		push_error("text_info is read-only")

func _ts_get_text_info() -> TypesetterTextInfo:
	_ts_ensure_layout()
	return _ts_core.get_text_info()


## Bounds of the text geometry (padded quads), in node space.
## TMP: bounds
var bounds: AABB:
	get:
		return _ts_get_bounds()
	set(_value):
		push_error("bounds is read-only")

func _ts_get_bounds() -> AABB:
	_ts_ensure_layout()
	var info := _ts_core.get_text_info()
	var lo := Vector3(INF, INF, 0)
	var hi := Vector3(-INF, -INF, 0)
	for i in info.character_count:
		var c: TypesetterCharacterInfo = info.character_info[i]
		if not c.is_visible:
			continue
		for p in [c.top_left, c.bottom_right, c.top_right, c.bottom_left]:
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), 0)
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), 0)
	if lo.x > hi.x:
		return AABB()
	return AABB(lo, hi - lo)


## Bounds of the laid-out text (advances and line extents), in node space.
## TMP: textBounds
var text_bounds: AABB:
	get:
		return _ts_get_text_bounds()
	set(_value):
		push_error("text_bounds is read-only")

func _ts_get_text_bounds() -> AABB:
	_ts_ensure_layout()
	var r := _ts_core.get_text_bounds()
	return AABB(Vector3(r.position.x, r.position.y, 0), Vector3(r.size.x, r.size.y, 0))


## The generated mesh (TypesetterText3D) or the first surface mesh (TypesetterLabel).
## TMP: mesh
var mesh: Mesh:
	get:
		return _ts_get_mesh()
	set(_value):
		push_error("mesh is read-only")

func _ts_get_mesh() -> Mesh:
	_ts_ensure_geometry()
	return _ts_get_mesh_impl()


## Width the text needs on one line per paragraph (layout element).
## TMP: preferredWidth
var preferred_width: float:
	get:
		return _ts_get_preferred_width()
	set(_value):
		push_error("preferred_width is read-only")

func _ts_get_preferred_width() -> float:
	_ts_ensure_layout()
	return _ts_core.get_preferred_width()


## Height the text needs at the current width (layout element).
## TMP: preferredHeight
var preferred_height: float:
	get:
		return _ts_get_preferred_height()
	set(_value):
		push_error("preferred_height is read-only")

func _ts_get_preferred_height() -> float:
	_ts_ensure_layout()
	return _ts_core.get_preferred_height()


## Width of the laid-out text.
## TMP: renderedWidth
var rendered_width: float:
	get:
		return _ts_get_rendered_width()
	set(_value):
		push_error("rendered_width is read-only")

func _ts_get_rendered_width() -> float:
	return get_rendered_values(false).x


## Height of the laid-out text.
## TMP: renderedHeight
var rendered_height: float:
	get:
		return _ts_get_rendered_height()
	set(_value):
		push_error("rendered_height is read-only")

func _ts_get_rendered_height() -> float:
	return get_rendered_values(false).y


## Layout element flexible width (-1: not flexible).
## TMP: flexibleWidth
var flexible_width: float:
	get:
		return _ts_get_flexible_width()
	set(_value):
		push_error("flexible_width is read-only")

func _ts_get_flexible_width() -> float:
	return -1.0


## Layout element flexible height (-1: not flexible).
## TMP: flexibleHeight
var flexible_height: float:
	get:
		return _ts_get_flexible_height()
	set(_value):
		push_error("flexible_height is read-only")

func _ts_get_flexible_height() -> float:
	return -1.0


## Layout element minimum width.
## TMP: minWidth
var min_width: float:
	get:
		return _ts_get_min_width()
	set(_value):
		push_error("min_width is read-only")

func _ts_get_min_width() -> float:
	return 0.0


## Layout element minimum height.
## TMP: minHeight
var min_height: float:
	get:
		return _ts_get_min_height()
	set(_value):
		push_error("min_height is read-only")

func _ts_get_min_height() -> float:
	return 0.0


## Largest preferred width.
## TMP: maxWidth
var max_width: float:
	get:
		return _ts_get_max_width()
	set(_value):
		push_error("max_width is read-only")

func _ts_get_max_width() -> float:
	return _ts_get_preferred_width()


## Largest preferred height.
## TMP: maxHeight
var max_height: float:
	get:
		return _ts_get_max_height()
	set(_value):
		push_error("max_height is read-only")

func _ts_get_max_height() -> float:
	return _ts_get_preferred_height()


## Layout element priority.
## TMP: layoutPriority
var layout_priority: int:
	get:
		return _ts_get_layout_priority()
	set(_value):
		push_error("layout_priority is read-only")

func _ts_get_layout_priority() -> int:
	return 0


## True while a change is waiting for the next update; set it to force one.
## TMP: havePropertiesChanged
var have_properties_changed: bool:
	get:
		return _ts_get_have_properties_changed()
	set(value):
		_ts_set_have_properties_changed(value)

func _ts_get_have_properties_changed() -> bool:
	return _ts_dirty_layout or _ts_dirty_vertices or _ts_dirty_material


func _ts_set_have_properties_changed(v: bool) -> void:
	if v:
		_ts_set_layout_dirty()


## The animator that plays `<sprite anim=...>` (created on demand).
## TMP: spriteAnimator
var sprite_animator: TypesetterSpriteAnimator:
	get:
		return _ts_get_sprite_animator()
	set(_value):
		push_error("sprite_animator is read-only")

func _ts_get_sprite_animator() -> TypesetterSpriteAnimator:
	for c in get_children(true):
		if c is TypesetterSpriteAnimator:
			return c
	var a := TypesetterSpriteAnimator.new()
	a.name = "SpriteAnimator"
	add_child(a, false, Node.INTERNAL_MODE_BACK)
	return a


# ------------------------------------------------------------------ methods

## Lays the text out and rebuilds its geometry now instead of before the next frame.
## TMP: ForceMeshUpdate(bool ignoreActiveState, bool forceTextReparsing)
func force_mesh_update(ignore_active_state: bool = false, force_text_reparsing: bool = false) -> void:
	if not ignore_active_state and not _ts_is_active():
		return
	if force_text_reparsing:
		_ts_dirty_layout = true
	_ts_update(true)


## Replaces the drawn geometry with `mesh` (one surface per material).
## TMP: UpdateGeometry(Mesh mesh, int index)
func update_geometry(new_mesh: Mesh, index: int) -> void:
	if new_mesh == null:
		return
	if index < _ts_surfaces.size():
		_ts_replace_surface_mesh(index, new_mesh)


## Uploads edits made to `text_info.mesh_info` (vertices, colours, UVs).
## TMP: UpdateVertexData(TMP_VertexDataUpdateFlags flags)
func update_vertex_data(flags: int = VertexDataUpdateFlags.ALL) -> void:
	if flags == VertexDataUpdateFlags.NONE:
		return
	_ts_update_vertex_data_impl()


## Replaces the vertex positions of the first mesh.
## TMP: SetVertices(Vector3[] vertices)
func set_vertices(vertices: PackedVector3Array) -> void:
	var info := _ts_get_text_info()
	if info.mesh_info.is_empty():
		return
	var mi: TypesetterMeshInfo = info.mesh_info[0]
	var n := mini(vertices.size(), mi.vertices.size())
	for i in n:
		mi.vertices[i] = vertices[i]
	update_vertex_data(VertexDataUpdateFlags.VERTICES)


## Recomputes the quad padding from the material (after editing material effects).
## TMP: UpdateMeshPadding
func update_mesh_padding() -> void:
	_ts_set_layout_dirty()


## Fades the text tint to `target_color` over `duration` seconds.
## TMP: CrossFadeColor(Color targetColor, float duration, bool ignoreTimeScale, bool useAlpha)
func cross_fade_color(target_color: Color, duration: float, ignore_time_scale: bool = false, use_alpha: bool = true) -> void:
	var to := target_color
	if not use_alpha:
		to.a = _ts_tint.a
	_ts_fade_to(to, duration, ignore_time_scale)


## Fades the text tint's alpha to `target_alpha` over `duration` seconds.
## TMP: CrossFadeAlpha(float alpha, float duration, bool ignoreTimeScale)
func cross_fade_alpha(target_alpha: float, duration: float, ignore_time_scale: bool = false) -> void:
	var to := _ts_tint
	to.a = target_alpha
	_ts_fade_to(to, duration, ignore_time_scale)


## Sets `text` from a format string: `{0}` inserts the first argument, `{1:2}`
## the second with two decimals, `{2:00}` zero-padded to two digits.
## TMP: SetText(string sourceText, float arg0, float arg1, ...) and SetText(StringBuilder)
func set_text(source_text: Variant, ...args: Array) -> void:
	text = TypesetterTextUtilities.format_text(str(source_text), args)


## Sets `text` from an array of characters or code points.
## TMP: SetCharArray(char[] sourceText, int start, int length)
func set_char_array(source: Variant, start: int = 0, length: int = -1) -> void:
	var s := ""
	var n: int = source.size() if length < 0 else mini(length, source.size() - start)
	for i in range(start, start + n):
		var c = source[i]
		s += c if c is String else char(int(c))
	text = s


## Preferred size of the text. Forms: `()`, `(text)`, `(width, height)`,
## `(text, width, height)`; 0 or INF means unconstrained.
## TMP: GetPreferredValues(...)
func get_preferred_values(...args: Array) -> Vector2:
	var t := text
	var w := INF
	var h := INF
	if args.size() == 1 or args.size() == 3:
		t = str(args[0])
		args = args.slice(1)
	if args.size() >= 2:
		w = float(args[0])
		h = float(args[1])
	var core := _ts_make_core(t)
	return core.get_preferred_values(w, h)


## Size of the laid-out text; with `only_visible`, hidden characters are excluded.
## TMP: GetRenderedValues(bool onlyVisibleCharacters)
func get_rendered_values(only_visible: bool = false) -> Vector2:
	_ts_ensure_layout()
	return _ts_core.get_rendered_values(only_visible)


## Lays out `source_text` with this node's settings and returns its text info
## without changing the node.
## TMP: GetTextInfo(string text)
func get_text_info(source_text: String) -> TypesetterTextInfo:
	var core := _ts_make_core(source_text)
	return core.get_text_info()


## The text with tags removed and escapes resolved.
## TMP: GetParsedText
func get_parsed_text() -> String:
	var info := _ts_get_text_info()
	var s := ""
	for i in info.character_count:
		s += info.character_info[i].character
	return s


## Recomputes the text area after margin or size changes.
## TMP: ComputeMarginSize
func compute_margin_size() -> void:
	_ts_set_layout_dirty()


## Removes the drawn geometry until the next update.
## TMP: ClearMesh(bool updateMesh)
func clear_mesh(_update_mesh: bool = true) -> void:
	_ts_surfaces.clear()
	_ts_clear_geometry()


## TMP: SetAllDirty
func set_all_dirty() -> void:
	_ts_set_layout_dirty()
	_ts_set_material_dirty()


## TMP: SetVerticesDirty
func set_vertices_dirty() -> void:
	_ts_set_vertices_dirty()


## TMP: SetLayoutDirty
func set_layout_dirty() -> void:
	_ts_set_layout_dirty()


## TMP: SetMaterialDirty
func set_material_dirty() -> void:
	_ts_set_material_dirty()


## TMP: Rebuild(CanvasUpdate update)
func rebuild(_update: int = 0) -> void:
	_ts_update(true)


## TMP: CalculateLayoutInputHorizontal
func calculate_layout_input_horizontal() -> void:
	_ts_ensure_layout()


## TMP: CalculateLayoutInputVertical
func calculate_layout_input_vertical() -> void:
	_ts_ensure_layout()


## Font size after auto-sizing (`font_size` when auto-sizing is off).
func get_font_size_resolved() -> float:
	_ts_ensure_layout()
	return _ts_core.get_resolved_font_size()


## Number of pages (Page overflow).
func get_page_count() -> int:
	_ts_ensure_layout()
	return _ts_core.get_page_count()


## The underlying engine (for godot-uxml and custom renderers).
func get_text_core() -> TypesetterTextCore:
	_ts_ensure_layout()
	return _ts_core


# ------------------------------------------------------------------ internals

func _ts_is_active() -> bool:
	return is_inside_tree() and (ignore_visibility or _ts_is_visible())


func _ts_font() -> TypesetterFontAsset:
	if font != null:
		return font
	return TypesetterSettings.get_default_font_asset()


func _ts_base_shared_material() -> Material:
	if font_shared_material != null:
		return font_shared_material
	return TypesetterMaterialManager.get_default_material(_ts_font())


func _ts_base_material() -> Material:
	if _ts_font_material_instance != null:
		return _ts_font_material_instance
	return _ts_base_shared_material()


func _ts_material_param(n: StringName, d: Variant) -> Variant:
	var m := _ts_base_material() as ShaderMaterial
	if m == null:
		return d
	var v = m.get_shader_parameter(n)
	return d if v == null else v


func _ts_set_material_param(n: StringName, v: Variant) -> void:
	var m := _ts_get_font_material() as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter(n, v)
	TypesetterShaderUtilities.update_shader_ratios(m)
	TypesetterMaterialManager.mark_changed(m)
	_ts_set_material_dirty()
	_ts_set_layout_dirty()


func _ts_on_changed(prop: StringName, kinds: int) -> void:
	if kinds & 1:
		_ts_set_layout_dirty()
	if kinds & 2:
		_ts_set_vertices_dirty()
	if kinds & 4:
		_ts_set_material_dirty()
	if kinds & 8:
		text_changed.emit()
		TypesetterSettings.events.text_changed.emit(self)
	if _TS_CORE_DIRECT.has(prop):
		_ts_pending_core[prop] = true
	elif prop != &"text":
		_ts_settings_stale = true
	if prop == &"font":
		_ts_font_material_instance = null
	_ts_property_hook(prop)


func _ts_watch(old: Resource, new: Resource) -> void:
	if old != null and old.changed.is_connected(_ts_on_resource_changed):
		old.changed.disconnect(_ts_on_resource_changed)
	if new != null and not new.changed.is_connected(_ts_on_resource_changed):
		new.changed.connect(_ts_on_resource_changed)


func _ts_on_resource_changed() -> void:
	_ts_settings_stale = true
	_ts_material_cache_stale = true
	_ts_set_layout_dirty()


func _ts_set_layout_dirty() -> void:
	_ts_dirty_layout = true
	_ts_queue_update()


func _ts_set_vertices_dirty() -> void:
	_ts_dirty_vertices = true
	_ts_queue_update()


func _ts_set_material_dirty() -> void:
	_ts_settings_stale = true
	_ts_material_cache_stale = true
	_ts_dirty_material = true
	_ts_queue_update()


func _ts_queue_update() -> void:
	if _ts_queued:
		return
	_ts_queued = true
	_ts_deferred_update.call_deferred()


func _ts_deferred_update() -> void:
	_ts_queued = false
	if not is_inside_tree():
		return
	if not ignore_visibility and not _ts_is_visible():
		return
	_ts_update(false)


func _ts_ensure_layout() -> void:
	if _ts_dirty_layout:
		_ts_layout()


func _ts_ensure_geometry() -> void:
	if _ts_dirty_layout or _ts_dirty_vertices or _ts_dirty_material:
		_ts_update(false)


func _ts_layout() -> void:
	_ts_sync_core(_ts_core, _ts_source_text())
	_ts_core.update()
	_ts_dirty_layout = false
	_ts_dirty_vertices = true
	_ts_after_layout()


func _ts_update(force: bool) -> void:
	if _ts_try_fast_text_update():
		return
	if _ts_dirty_layout or force:
		_ts_layout()
	if _ts_dirty_vertices or _ts_dirty_material or force:
		_ts_dirty_vertices = false
		_ts_dirty_material = false
		if render_mode == TextRenderFlags.DONT_RENDER:
			_ts_surfaces.clear()
			_ts_clear_geometry()
			return
		_ts_build_surfaces()
		# Building text_info for a signal nobody hears is most of an update's cost.
		if not pre_render_text.get_connections().is_empty():
			pre_render_text.emit(_ts_core.get_text_info())
		_ts_present()


## A change to the text alone, drawn with the same fonts and materials: the core
## lays it out and rewrites the meshes in place, so nothing else is rebuilt.
func _ts_try_fast_text_update() -> bool:
	if not _ts_dirty_layout or _ts_dirty_material or _ts_settings_stale or _ts_surfaces.is_empty():
		return false
	if render_mode == TextRenderFlags.DONT_RENDER or auto_size_text_container or _ts_linked_parent != null:
		return false
	if overflow_mode == TextOverflowModes.LINKED:
		return false
	if _ts_synced_lookup_revision != TypesetterTextUtilities.revision or _ts_synced_bold_tag != _ts_style_has_bold():
		return false
	_ts_flush_pending_core(_ts_core)
	if not _ts_core.refresh_text(_ts_source_text(), _ts_container_size(), _ts_update_meshes()):
		# Laid out already: finish on the normal path without a second layout.
		_ts_dirty_layout = false
		_ts_dirty_vertices = true
		_ts_after_layout()
		return false
	_ts_dirty_layout = false
	_ts_dirty_vertices = false
	_ts_have_properties_changed = false
	if _ts_core.has_missing_characters() or (rich_text and text.contains("anim")):
		_ts_after_layout()
	if not pre_render_text.get_connections().is_empty():
		pre_render_text.emit(_ts_core.get_text_info())
	return true


func _ts_source_text() -> String:
	var t := text
	if _ts_linked_parent != null and is_instance_valid(_ts_linked_parent):
		t = _ts_linked_parent.text
	if text_preprocessor != null and text_preprocessor.has_method(&"preprocess_text"):
		t = text_preprocessor.preprocess_text(t)
	return t


## Copies this node's settings into a core (the node's own, or a scratch core
## for get_preferred_values / get_text_info).
func _ts_sync_core(c: TypesetterTextCore, source: String) -> void:
	var bold_tag := _ts_style_has_bold()
	if (
		c == _ts_core
		and not _ts_settings_stale
		and _ts_synced_lookup_revision == TypesetterTextUtilities.revision
		and _ts_synced_bold_tag == bold_tag
	):
		# Only the text, the size and core-only properties changed.
		_ts_flush_pending_core(c)
		c.text = source
		c.rect_size = _ts_container_size()
		c.pivot = _ts_container_pivot()
		if _ts_linked_parent != null and _ts_linked_start >= 0:
			c.first_visible_character = _ts_linked_start
		return
	if c == _ts_core:
		_ts_settings_stale = false
		_ts_material_cache_stale = true
		c.lookups_revision += 1
		_ts_synced_lookup_revision = TypesetterTextUtilities.revision
		_ts_synced_bold_tag = bold_tag
	c.text = source
	c.font = _ts_font()
	c.alignment = horizontal_alignment | vertical_alignment
	c.rect_size = _ts_container_size()
	c.pivot = _ts_container_pivot()
	c.world_space = _ts_is_3d()
	c.enable_kerning = font_features & FontFeatures.KERN != 0
	if _ts_linked_parent != null and _ts_linked_start >= 0:
		c.first_visible_character = _ts_linked_start
	# Gradient: preset wins over the per-node gradient.
	if enable_vertex_gradient and color_gradient_preset != null:
		c.color_gradient = color_gradient_preset.to_colors()
	elif enable_vertex_gradient and color_gradient != null:
		c.color_gradient = color_gradient.to_colors()
	else:
		c.color_gradient = PackedColorArray()
	# Lookups for <font>, <material>, <style>, <gradient> and <sprite>.
	var sheet := style_sheet if style_sheet != null else TypesetterSettings.get_default_style_sheet()
	c.style_lookup = sheet.to_lookup() if sheet != null else {}
	if text_style != null:
		c.text_style_opening = text_style.opening_definition
		c.text_style_closing = text_style.closing_definition
	else:
		c.text_style_opening = ""
		c.text_style_closing = ""
	var sprites: Array[Resource] = []
	var sa := sprite_asset if sprite_asset != null else TypesetterSettings.get_default_sprite_asset()
	if sa != null:
		sprites.append(sa)
	c.sprite_assets = sprites
	c.font_lookup = TypesetterTextUtilities.font_lookup()
	c.material_lookup = TypesetterTextUtilities.material_lookup()
	c.gradient_lookup = TypesetterTextUtilities.gradient_lookup()
	var fallbacks: Array[TypesetterFontAsset] = TypesetterSettings.get_fallback_font_assets()
	if emoji_fallback_support:
		for r in TypesetterSettings.get_emoji_fallback_text_assets():
			if r is TypesetterFontAsset:
				fallbacks.push_front(r)
	c.fallback_font_assets = fallbacks
	c.missing_glyph_character = TypesetterSettings.get_missing_glyph_character()
	c.leading_characters = TypesetterSettings.get_leading_characters()
	c.following_characters = TypesetterSettings.get_following_characters()
	# Quad padding: the atlas edge allowance plus what the material's effects need.
	var a := c.font
	var bitmap := a != null and a.atlas_render_mode <= TypesetterFontAsset.RASTER_HINTED
	var base := 1.0 if bitmap else 1.25
	c.mesh_padding = base + (0.0 if bitmap else TypesetterShaderUtilities.get_padding(_ts_base_material(), extra_padding, _ts_style_has_bold()))
	_ts_sync_core_generated(c)
	if c == _ts_core:
		_ts_pending_core.clear()


func _ts_flush_pending_core(c: TypesetterTextCore) -> void:
	for prop in _ts_pending_core:
		c.set(prop, get(prop))
	_ts_pending_core.clear()


func _ts_style_has_bold() -> bool:
	return font_style & FontStyles.BOLD != 0 or (rich_text and text.findn("<b>") >= 0)


func _ts_make_core(source: String) -> TypesetterTextCore:
	var c := TypesetterTextCore.new()
	_ts_sync_core(c, source)
	c.update()
	return c


func _ts_after_layout() -> void:
	_ts_have_properties_changed = false
	# Linked overflow: hand the rest of the text to the linked component.
	if overflow_mode == TextOverflowModes.LINKED and linked_text_component != null and linked_text_component.has_method(&"_ts_set_linked_source"):
		linked_text_component._ts_set_linked_source(self, _ts_core.get_first_overflow_character_index())
	# Missing characters.
	var missing: PackedInt32Array = _ts_core.get_missing_characters()
	for i in range(0, missing.size(), 2):
		TypesetterSettings.events.missing_character.emit(missing[i], missing[i + 1], text, _ts_font(), self)
	if auto_size_text_container:
		_ts_apply_auto_size_container()
	if rich_text and text.contains("anim"):
		_ts_get_sprite_animator().refresh_from_text.call_deferred()


func _ts_set_linked_source(parent: Node, start: int) -> void:
	_ts_settings_stale = true
	if start < 0:
		_ts_linked_parent = parent
		_ts_linked_start = 1 << 30
	else:
		_ts_linked_parent = parent
		_ts_linked_start = start
	_ts_set_layout_dirty()


func _ts_build_surfaces() -> void:
	_ts_surfaces = _ts_build_meshes_impl()
	if _ts_material_cache_stale:
		_ts_material_cache.clear()
		_ts_material_cache_stale = false
	var base := _ts_base_material()
	var owner := _ts_font()
	for s in _ts_surfaces:
		var tex: Texture2D = s.get("texture")
		var surface_base: Material = s.get("material", base)
		if surface_base == null:
			surface_base = base
		# Resolving a surface material is the costliest step of a text change that
		# keeps the same fonts; reuse it until the material or font changes.
		var key := [surface_base, s.get("font"), tex, s.get("sprite", false)]
		var m: Material = _ts_material_cache.get(key)
		if m == null:
			m = TypesetterMaterialManager.get_surface_material(surface_base, owner, s.get("font"), 0, _ts_is_3d(), _ts_overlay(), tex, s.get("sprite", false))
			_ts_material_cache[key] = m
		s["material_used"] = m


func _ts_fade_to(to: Color, duration: float, ignore_time_scale: bool) -> void:
	if duration <= 0.0:
		_ts_set_tint(to)
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(ignore_time_scale)
	tw.tween_method(_ts_set_tint, _ts_tint, to, duration)


func _ts_set_tint(c: Color) -> void:
	_ts_tint = c
	_ts_apply_tint()


func _ts_sync_core_generated(c: TypesetterTextCore) -> void:
	c.font_style = font_style
	c.font_size = font_size
	c.enable_auto_sizing = enable_auto_sizing
	c.font_size_min = font_size_min
	c.font_size_max = font_size_max
	c.character_width_adjustment = character_width_adjustment
	c.line_spacing_adjustment = line_spacing_adjustment
	c.font_weight = font_weight
	c.color = color
	c.override_color_tags = override_color_tags
	c.character_spacing = character_spacing
	c.word_spacing = word_spacing
	c.line_spacing = line_spacing
	c.paragraph_spacing = paragraph_spacing
	c.word_wrapping_ratios = word_wrapping_ratios
	c.text_wrapping_mode = text_wrapping_mode
	c.overflow_mode = overflow_mode
	c.page_to_display = page_to_display
	c.horizontal_mapping = horizontal_mapping
	c.vertical_mapping = vertical_mapping
	c.mapping_uv_line_offset = mapping_uv_line_offset
	c.margin = margin
	c.geometry_sorting_order = geometry_sorting_order
	c.rich_text = rich_text
	c.parse_ctrl_characters = parse_ctrl_characters
	c.use_max_visible_descender = use_max_visible_descender
	c.tint_all_sprites = tint_all_sprites
	c.font_features = font_features
	c.extra_padding = extra_padding
	c.is_right_to_left_text = is_right_to_left_text
	c.first_visible_character = first_visible_character
	c.max_visible_characters = max_visible_characters
	c.max_visible_words = max_visible_words
	c.max_visible_lines = max_visible_lines


var _ts_mesh: ArrayMesh = ArrayMesh.new()


func _init() -> void:
	_ts_core.world_space = true
	set_base(_ts_mesh.get_rid())


func _ts_property_hook(prop: StringName) -> void:
	if prop == &"sorting_order":
		sorting_offset = sorting_order


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			set_base(_ts_mesh.get_rid())
			_ts_set_layout_dirty()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree() and (_ts_dirty_layout or _ts_dirty_vertices or _ts_dirty_material):
				_ts_queue_update()


func _get_aabb() -> AABB:
	return _ts_mesh.get_aabb()


func _ts_apply_auto_size_container() -> void:
	var p := _ts_make_core(_ts_source_text()).get_preferred_values(INF, INF)
	if not p.is_equal_approx(rect_size):
		rect_size = p


func _ts_is_3d() -> bool:
	return true


func _ts_overlay() -> bool:
	return is_overlay


func _ts_is_visible() -> bool:
	return is_visible_in_tree()


func _ts_container_size() -> Vector2:
	return rect_size


func _ts_container_pivot() -> Vector2:
	return pivot


func _ts_build_meshes_impl() -> Array[Dictionary]:
	var dicts := _ts_core.build_mesh(_ts_mesh)
	var out: Array[Dictionary] = []
	for d in dicts:
		out.append(d)
	return out


func _ts_update_meshes() -> Array[ArrayMesh]:
	return [_ts_mesh]


func _ts_present() -> void:
	for s in _ts_surfaces:
		var i: int = s.surface
		if i < _ts_mesh.get_surface_count():
			_ts_mesh.surface_set_material(i, s.get("material_used"))
	var masked := overflow_mode == TextOverflowModes.MASKING
	var r := Vector4(-32767, -32767, 32767, 32767)
	if masked:
		var x0 := -rect_size.x * pivot.x + margin.x
		var y0 := -rect_size.y * pivot.y + margin.w
		r = Vector4(x0, y0, -rect_size.x * pivot.x + rect_size.x - margin.z, -rect_size.y * pivot.y + rect_size.y - margin.y)
	set_instance_shader_parameter(&"clip_rect", r)
	_ts_apply_tint()
	update_gizmos()


func _ts_clear_geometry() -> void:
	_ts_mesh.clear_surfaces()


func _ts_apply_tint() -> void:
	set_instance_shader_parameter(&"ts_tint", _ts_tint)


func _ts_get_mesh_impl() -> Mesh:
	return _ts_mesh


func _ts_replace_surface_mesh(_index: int, new_mesh: Mesh) -> void:
	if new_mesh is ArrayMesh:
		_ts_mesh = new_mesh
		set_base(_ts_mesh.get_rid())
		_ts_present()


func _ts_update_vertex_data_impl() -> void:
	var meshes: Array[ArrayMesh] = []
	for s in _ts_surfaces:
		meshes.append(ArrayMesh.new())
	_ts_core.update_vertex_data(meshes)
	_ts_mesh.clear_surfaces()
	for i in meshes.size():
		var m := meshes[i]
		if m.get_surface_count() > 0:
			_ts_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0), [], {}, m.surface_get_format(0))
			_ts_surfaces[i]["surface"] = _ts_mesh.get_surface_count() - 1
	_ts_present()
