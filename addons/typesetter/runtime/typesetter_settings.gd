@tool
class_name TypesetterSettings
extends RefCounted
## Project-wide Typesetter defaults (TMP_Settings), stored in ProjectSettings
## under `typesetter/`. Read them with the static getters; the editor plugin
## registers the settings so they appear in Project Settings.
##
## TMP: TMP_Settings

const PREFIX := "typesetter/"

## Setting name → [default, type, hint, hint_string].
static var DEFINITIONS := {
	"default_font_asset": ["", TYPE_STRING, PROPERTY_HINT_FILE, "*.tres,*.res"],
	"default_font_size": [36.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "1,1000,0.01,or_greater"],
	"default_text_auto_sizing_min_ratio": [0.5, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,1,0.01"],
	"default_text_auto_sizing_max_ratio": [2.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "1,10,0.01"],
	"default_text_3d_container_size": [Vector2(20, 5), TYPE_VECTOR2, PROPERTY_HINT_NONE, ""],
	"default_label_container_size": [Vector2(200, 50), TYPE_VECTOR2, PROPERTY_HINT_NONE, ""],
	"auto_size_text_container": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"text_wrapping_mode": [1, TYPE_INT, PROPERTY_HINT_ENUM, "No Wrap,Normal,Preserve Whitespace,Preserve Whitespace No Wrap"],
	"enable_kerning": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"enable_extra_padding": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"enable_tint_all_sprites": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"enable_parse_escape_characters": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"enable_raycast_target": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"get_font_features_at_runtime": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"missing_glyph_character": [0, TYPE_INT, PROPERTY_HINT_NONE, ""],
	"clear_dynamic_data_on_build": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"warnings_disabled": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"fallback_font_assets": [PackedStringArray(), TYPE_PACKED_STRING_ARRAY, PROPERTY_HINT_NONE, ""],
	"match_material_preset": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"default_sprite_asset": ["", TYPE_STRING, PROPERTY_HINT_FILE, "*.tres,*.res"],
	"enable_emoji_support": [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"emoji_fallback_text_assets": [PackedStringArray(), TYPE_PACKED_STRING_ARRAY, PROPERTY_HINT_NONE, ""],
	"default_color_gradient_presets_path": ["res://typesetter/color_gradients", TYPE_STRING, PROPERTY_HINT_DIR, ""],
	"default_style_sheet": ["", TYPE_STRING, PROPERTY_HINT_FILE, "*.tres,*.res"],
	"style_sheets_resource_path": ["res://typesetter/style_sheets", TYPE_STRING, PROPERTY_HINT_DIR, ""],
	"default_font_asset_path": ["res://typesetter/fonts", TYPE_STRING, PROPERTY_HINT_DIR, ""],
	"default_sprite_asset_path": ["res://typesetter/sprites", TYPE_STRING, PROPERTY_HINT_DIR, ""],
	"leading_characters": ["", TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT, ""],
	"following_characters": ["", TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT, ""],
	"use_modern_hangul_line_breaking_rules": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	"is_text_object_scale_static": [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
}

## Callbacks for `<font="name">` and `<sprite="name">` lookups that the
## registered assets cannot resolve: `func(hash_code: int, name: String) -> Resource`.
## TMP: TMP_Text.OnFontAssetRequest, TMP_Text.OnSpriteAssetRequest
static var on_font_asset_request: Callable
static var on_sprite_asset_request: Callable

## Global events (TMP's static events): `missing_character(unicode, string_index,
## text, font_asset, text_component)` and `text_changed(text_component)`.
## TMP: TMP_Text.OnMissingCharacter, TMPro_EventManager.TEXT_CHANGED_EVENT
static var events: TypesetterEvents:
	get:
		if _events == null:
			_events = TypesetterEvents.new()
		return _events
static var _events: TypesetterEvents

static var _cache := {}


## Registers every setting in ProjectSettings with its default (editor plugin).
static func register() -> void:
	for key in DEFINITIONS:
		var d: Array = DEFINITIONS[key]
		var path: String = PREFIX + key
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, d[0])
		ProjectSettings.set_initial_value(path, d[0])
		ProjectSettings.add_property_info({"name": path, "type": d[1], "hint": d[2], "hint_string": d[3]})
		ProjectSettings.set_as_basic(path, key in ["default_font_asset", "default_font_size", "default_sprite_asset", "default_style_sheet"])


## A setting's value (falls back to the documented default).
static func get_value(key: String) -> Variant:
	var d: Array = DEFINITIONS.get(key, [null])
	return ProjectSettings.get_setting(PREFIX + key, d[0])


static func _load_cached(key: String) -> Resource:
	var path: String = get_value(key)
	if path.is_empty():
		return null
	if _cache.get(key + ":path") == path and _cache.has(key):
		return _cache[key]
	var r: Resource = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = r
	_cache[key + ":path"] = path
	return r


## The font asset used when a text node has none (TMP_Settings.defaultFontAsset).
## Without a configured asset, the bundled Inter font is used.
static func get_default_font_asset() -> TypesetterFontAsset:
	var a := _load_cached("default_font_asset") as TypesetterFontAsset
	if a != null:
		return a
	if not _cache.has("builtin_font"):
		# load() goes through the import, which exported games keep; the raw .ttf is
		# not exported.
		var f := load("res://addons/typesetter/fonts/Inter-Regular.ttf") as FontFile
		if f != null and not f.data.is_empty():
			var asset := TypesetterFontAsset.create_font_asset(f)
			asset.resource_name = "Inter Regular SDF"
			_cache["builtin_font"] = asset
		else:
			_cache["builtin_font"] = null
	return _cache["builtin_font"]


static func get_default_sprite_asset() -> TypesetterSpriteAsset:
	return _load_cached("default_sprite_asset") as TypesetterSpriteAsset


static func get_default_style_sheet() -> TypesetterStyleSheet:
	return _load_cached("default_style_sheet") as TypesetterStyleSheet


## Global fallback font assets (TMP_Settings.fallbackFontAssets).
static func get_fallback_font_assets() -> Array[TypesetterFontAsset]:
	var out: Array[TypesetterFontAsset] = []
	for p in get_value("fallback_font_assets"):
		if ResourceLoader.exists(p):
			var a := load(p) as TypesetterFontAsset
			if a != null:
				out.append(a)
	return out


static func get_emoji_fallback_text_assets() -> Array[Resource]:
	var out: Array[Resource] = []
	for p in get_value("emoji_fallback_text_assets"):
		if ResourceLoader.exists(p):
			var r := load(p)
			if r != null:
				out.append(r)
	return out


static func get_default_font_size() -> float:
	return get_value("default_font_size")


static func get_missing_glyph_character() -> int:
	return get_value("missing_glyph_character")


## Line-breaking rules (TMP_Settings.linebreakingRules): characters that may not
## start a line (leading) and may not end one (following).
static func get_leading_characters() -> String:
	var s: String = get_value("leading_characters")
	return s if not s.is_empty() else TypesetterLineBreakingRules.DEFAULT_LEADING


static func get_following_characters() -> String:
	var s: String = get_value("following_characters")
	return s if not s.is_empty() else TypesetterLineBreakingRules.DEFAULT_FOLLOWING


## Drops cached resources (call after changing settings at runtime).
static func clear_cache() -> void:
	_cache.clear()
