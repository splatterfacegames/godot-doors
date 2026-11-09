@tool
class_name TypesetterSpriteAsset
extends Resource
## Inline images for `<sprite>` tags and emoji (TMP_SpriteAsset).
##
## A sprite asset is a sprite sheet texture plus a glyph table (rectangles and
## metrics in sheet pixels) and a character table (unicode and name per glyph).
## Create one from a grid, from AtlasTextures, or from a TexturePacker JSON file
## with the editor importer.
## TMP: TMP_SpriteAsset

## TMP: spriteSheet
@export var sprite_sheet: Texture2D:
	set(v):
		sprite_sheet = v
		emit_changed()
## Metrics used to scale sprites relative to text: point_size, ascent_line,
## descent_line, line_height, baseline, scale.
## TMP: faceInfo
@export var face_info: Dictionary = {"point_size": 0.0, "ascent_line": 0.0, "descent_line": 0.0, "line_height": 0.0, "baseline": 0.0, "scale": 1.0}
## TMP: spriteGlyphTable
@export var sprite_glyph_table: Array[TypesetterSpriteGlyph] = []:
	set(v):
		sprite_glyph_table = v
		_dirty = true
		emit_changed()
## TMP: spriteCharacterTable
@export var sprite_character_table: Array[TypesetterSpriteCharacter] = []:
	set(v):
		sprite_character_table = v
		_dirty = true
		emit_changed()
## TMP: fallbackSpriteAssets
@export var fallback_sprite_assets: Array[TypesetterSpriteAsset] = []
## Material for the sprites (null: the built-in sprite shader).
## TMP: material
@export var material: Material

## TMP: hashCode
var hash_code: int:
	get:
		return TypesetterStyle.get_hash_code(resource_name)

var _dirty := true
var _by_name := {}
var _by_unicode := {}
var _by_glyph := {}


## TMP: UpdateLookupTables
func update_lookup_tables() -> void:
	_by_name.clear()
	_by_unicode.clear()
	_by_glyph.clear()
	for g in sprite_glyph_table:
		if g != null:
			_by_glyph[g.index] = g
	for i in sprite_character_table.size():
		var c := sprite_character_table[i]
		if c == null:
			continue
		if not c.name.is_empty():
			_by_name[TypesetterStyle.get_hash_code(c.name)] = i
		if c.unicode != 0 and c.unicode != 0xFFFE:
			_by_unicode[c.unicode] = i
	_dirty = false


## Character-table index for a name hash, or -1. TMP: GetSpriteIndexFromHashcode
func get_sprite_index_from_hashcode(hash: int) -> int:
	if _dirty:
		update_lookup_tables()
	return _by_name.get(hash, -1)


## TMP: GetSpriteIndexFromUnicode
func get_sprite_index_from_unicode(unicode: int) -> int:
	if _dirty:
		update_lookup_tables()
	return _by_unicode.get(unicode, -1)


## TMP: GetSpriteIndexFromName
func get_sprite_index_from_name(sprite_name: String) -> int:
	return get_sprite_index_from_hashcode(TypesetterStyle.get_hash_code(sprite_name))


## Searches this asset and its fallbacks for a unicode; returns
## [asset, character index] or [null, -1]. TMP: SearchForSpriteByUnicode
static func search_for_sprite_by_unicode(asset: TypesetterSpriteAsset, unicode: int, include_fallbacks: bool = true) -> Array:
	return _search(asset, func(a: TypesetterSpriteAsset) -> int: return a.get_sprite_index_from_unicode(unicode), include_fallbacks, {})


## TMP: SearchForSpriteByHashCode
static func search_for_sprite_by_hash_code(asset: TypesetterSpriteAsset, hash: int, include_fallbacks: bool = true) -> Array:
	return _search(asset, func(a: TypesetterSpriteAsset) -> int: return a.get_sprite_index_from_hashcode(hash), include_fallbacks, {})


static func _search(asset: TypesetterSpriteAsset, f: Callable, fallbacks: bool, seen: Dictionary) -> Array:
	if asset == null or seen.has(asset.get_instance_id()):
		return [null, -1]
	seen[asset.get_instance_id()] = true
	var i: int = f.call(asset)
	if i >= 0:
		return [asset, i]
	if fallbacks:
		for fb in asset.fallback_sprite_assets:
			var r := _search(fb, f, true, seen)
			if r[1] >= 0:
				return r
	return [null, -1]


## TMP: SortGlyphTable
func sort_glyph_table() -> void:
	sprite_glyph_table.sort_custom(func(a, b): return a.index < b.index)
	_dirty = true


## TMP: SortCharacterTable
func sort_character_table() -> void:
	sprite_character_table.sort_custom(func(a, b): return a.unicode < b.unicode)
	_dirty = true


## Lookup used by the native layout: by character-table `index` (>= 0), by
## `sprite_name`, or by `unicode` when given. Searches fallbacks. Returns the
## sprite's metrics in sheet pixels, or {} when not found.
func find_sprite(index: int, sprite_name: String, unicode: int = 0) -> Dictionary:
	var asset: TypesetterSpriteAsset = self
	var ci := -1
	if index >= 0:
		ci = index if index < sprite_character_table.size() else -1
	elif not sprite_name.is_empty():
		var r := search_for_sprite_by_hash_code(self, TypesetterStyle.get_hash_code(sprite_name))
		asset = r[0]
		ci = r[1]
	elif unicode != 0:
		var r := search_for_sprite_by_unicode(self, unicode)
		asset = r[0]
		ci = r[1]
	if asset == null or ci < 0:
		return {}
	var ch: TypesetterSpriteCharacter = asset.sprite_character_table[ci]
	if asset._dirty:
		asset.update_lookup_tables()
	var g: TypesetterSpriteGlyph = asset._by_glyph.get(ch.glyph_index)
	if g == null:
		return {}
	var sheet_size := Vector2(1, 1)
	if asset.sprite_sheet != null:
		sheet_size = Vector2(asset.sprite_sheet.get_width(), asset.sprite_sheet.get_height())
	var fi := asset.face_info
	# 0 means no face info: the sprite then fills the font's ascent line.
	var pt: float = fi.get("point_size", 0.0)
	return {
		"index": ci,
		"unicode": ch.unicode,
		"width": g.metrics_width,
		"height": g.metrics_height,
		"bearing_x": g.bearing_x,
		"bearing_y": g.bearing_y,
		"advance": g.advance,
		"scale": g.scale * ch.scale * float(fi.get("scale", 1.0)),
		"rect": Rect2(g.glyph_rect),
		"atlas_size": sheet_size,
		"point_size": pt,
		"ascent": fi.get("ascent_line", pt * 0.8),
		"descent": fi.get("descent_line", -pt * 0.2),
		"tint": false,
		"asset": asset,
	}


## Builds a sprite asset from a sheet split into a `columns` × `rows` grid.
## `names` (optional) names the cells in reading order; `first_unicode` assigns
## consecutive code points (0 for none). Metrics follow TMP's conventions:
## bearing_y = 0.8 × height, advance = width.
static func create_from_grid(sheet: Texture2D, columns: int, rows: int, names: PackedStringArray = PackedStringArray(), first_unicode: int = 0) -> TypesetterSpriteAsset:
	var a := TypesetterSpriteAsset.new()
	a.sprite_sheet = sheet
	var cw := sheet.get_width() / columns
	var chh := sheet.get_height() / rows
	var glyphs: Array[TypesetterSpriteGlyph] = []
	var chars: Array[TypesetterSpriteCharacter] = []
	for r in rows:
		for c in columns:
			var i := r * columns + c
			glyphs.append(TypesetterSpriteGlyph.create(i, Rect2i(c * cw, r * chh, cw, chh)))
			var ch := TypesetterSpriteCharacter.new()
			ch.glyph_index = i
			ch.name = names[i] if i < names.size() else "sprite%d" % i
			ch.unicode = first_unicode + i if first_unicode != 0 else 0xFFFE
			chars.append(ch)
	a.sprite_glyph_table = glyphs
	a.sprite_character_table = chars
	a.face_info = {"point_size": float(chh), "ascent_line": chh * 0.8, "descent_line": -chh * 0.2, "line_height": float(chh), "baseline": 0.0, "scale": 1.0}
	return a


## Builds a sprite asset from AtlasTextures sharing one atlas (names from their
## resource names).
static func create_from_atlas_textures(textures: Array[AtlasTexture]) -> TypesetterSpriteAsset:
	var a := TypesetterSpriteAsset.new()
	if textures.is_empty():
		return a
	a.sprite_sheet = textures[0].atlas
	var glyphs: Array[TypesetterSpriteGlyph] = []
	var chars: Array[TypesetterSpriteCharacter] = []
	var max_h := 0.0
	for i in textures.size():
		var t := textures[i]
		glyphs.append(TypesetterSpriteGlyph.create(i, Rect2i(t.region)))
		var ch := TypesetterSpriteCharacter.new()
		ch.glyph_index = i
		ch.name = t.resource_name if not t.resource_name.is_empty() else "sprite%d" % i
		chars.append(ch)
		max_h = maxf(max_h, t.region.size.y)
	a.sprite_glyph_table = glyphs
	a.sprite_character_table = chars
	a.face_info = {"point_size": max_h, "ascent_line": max_h * 0.8, "descent_line": -max_h * 0.2, "line_height": max_h, "baseline": 0.0, "scale": 1.0}
	return a


## Builds a sprite asset from a TexturePacker "JSON (Array)" or "JSON (Hash)"
## export. TMP: the Sprite Importer.
static func create_from_texture_packer_json(sheet: Texture2D, json_text: String) -> TypesetterSpriteAsset:
	var data = JSON.parse_string(json_text)
	var a := TypesetterSpriteAsset.new()
	a.sprite_sheet = sheet
	if typeof(data) != TYPE_DICTIONARY or not data.has("frames"):
		push_error("TypesetterSpriteAsset: not a TexturePacker JSON file")
		return a
	var frames: Array = []
	if data.frames is Array:
		frames = data.frames
	else:
		for k in data.frames:
			var f: Dictionary = data.frames[k]
			f["filename"] = k
			frames.append(f)
	var glyphs: Array[TypesetterSpriteGlyph] = []
	var chars: Array[TypesetterSpriteCharacter] = []
	var max_h := 0.0
	for i in frames.size():
		var f: Dictionary = frames[i]
		var fr: Dictionary = f.frame
		var g := TypesetterSpriteGlyph.create(i, Rect2i(int(fr.x), int(fr.y), int(fr.w), int(fr.h)))
		glyphs.append(g)
		var ch := TypesetterSpriteCharacter.new()
		ch.glyph_index = i
		ch.name = str(f.filename).get_basename()
		var hex := ch.name.to_lower()
		ch.unicode = hex.hex_to_int() if hex.is_valid_hex_number() else 0xFFFE
		chars.append(ch)
		max_h = maxf(max_h, fr.h)
	a.sprite_glyph_table = glyphs
	a.sprite_character_table = chars
	a.face_info = {"point_size": max_h, "ascent_line": max_h * 0.8, "descent_line": -max_h * 0.2, "line_height": max_h, "baseline": 0.0, "scale": 1.0}
	return a
