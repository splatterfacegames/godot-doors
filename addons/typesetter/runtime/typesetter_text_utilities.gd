@tool
class_name TypesetterTextUtilities
extends RefCounted
## Hit testing and helpers for Typesetter text (TMP_TextUtilities).
##
## `position` arguments are viewport (screen) coordinates. For TypesetterLabel
## the camera is ignored; for TypesetterText3D pass the Camera3D that renders
## the text (null uses the viewport's active camera): the point is projected
## onto the text's plane.
## TMP: TMP_TextUtilities

## Caret position relative to the character returned by get_cursor_index_from_position.
## TMP: CaretPosition
enum CaretPosition { NONE, LEFT, RIGHT }

static var _lookups := {}
static var _overrides := {}
## Bumped whenever the name lookups change, so text nodes know to re-read them.
static var revision := 0


## Converts a viewport position to the text node's local space; returns null
## when a 3D ray misses the text plane.
static func screen_point_to_local(text_node: Node, position: Vector2, camera: Camera3D = null) -> Variant:
	if text_node is CanvasItem:
		return (text_node as CanvasItem).get_global_transform_with_canvas().affine_inverse() * position
	if text_node is Node3D:
		var n := text_node as Node3D
		var cam := camera if camera != null else n.get_viewport().get_camera_3d()
		if cam == null:
			return null
		var origin := cam.project_ray_origin(position)
		var dir := cam.project_ray_normal(position)
		var inv := n.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		if absf(d.z) < 1e-8:
			return null
		var t := -o.z / d.z
		if t < 0.0:
			return null
		var p := o + d * t
		return Vector2(p.x, p.y)
	return null


## World/canvas point of a viewport position on the text's rectangle plane.
## TMP: ScreenPointToWorldPointInRectangle
static func screen_point_to_world_point_in_rectangle(text_node: Node, position: Vector2, camera: Camera3D = null) -> Variant:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return null
	if text_node is Node3D:
		return (text_node as Node3D).global_transform * Vector3(p.x, p.y, 0.0)
	return (text_node as CanvasItem).get_global_transform() * p


static func _rect(text_node: Node) -> Rect2:
	if text_node is Control:
		return Rect2(Vector2.ZERO, text_node.size)
	var s: Vector2 = text_node.rect_size
	var pv: Vector2 = text_node.pivot
	return Rect2(-s * pv, s)


## True when `position` falls inside the text's container rectangle.
## TMP: IsIntersectingRectTransform
static func is_intersecting_rect(text_node: Node, position: Vector2, camera: Camera3D = null) -> bool:
	var p = screen_point_to_local(text_node, position, camera)
	return p != null and _rect(text_node).has_point(p)


## Character index under `position`, or -1.
## TMP: FindIntersectingCharacter
static func find_intersecting_character(text_node: Node, position: Vector2, camera: Camera3D = null, visible_only: bool = true) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	return text_node.get_text_core().find_intersecting_character(p, visible_only)


## Character nearest to `position`.
## TMP: FindNearestCharacter
static func find_nearest_character(text_node: Node, position: Vector2, camera: Camera3D = null, visible_only: bool = true) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	return text_node.get_text_core().find_nearest_character(p, visible_only)


static func _cell(info: TypesetterTextInfo, ci: int) -> Rect2:
	# Character cell: origin..x_advance horizontally, line ascender..descender vertically, in node space.
	var c: TypesetterCharacterInfo = info.character_info[ci]
	var y0 := c.ascender
	var y1 := c.descender
	return Rect2(Vector2(c.origin, minf(y0, y1)), Vector2(c.x_advance - c.origin, absf(y1 - y0)))


static func _dist(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_squared_to(p)


## Word index under `position`, or -1.
## TMP: FindIntersectingWord
static func find_intersecting_word(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	var info: TypesetterTextInfo = text_node.text_info
	for wi in info.word_count:
		var w: TypesetterWordInfo = info.word_info[wi]
		for ci in range(w.first_character_index, w.last_character_index + 1):
			if _cell(info, ci).has_point(p):
				return wi
	return -1


## Word nearest to `position`.
## TMP: FindNearestWord
static func find_nearest_word(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	var info: TypesetterTextInfo = text_node.text_info
	var best := -1
	var bd := INF
	for wi in info.word_count:
		var w: TypesetterWordInfo = info.word_info[wi]
		for ci in range(w.first_character_index, w.last_character_index + 1):
			var d := _dist(_cell(info, ci), p)
			if d < bd:
				bd = d
				best = wi
	return best


static func _line_rect(info: TypesetterTextInfo, li: int, node: Node) -> Rect2:
	var l: TypesetterLineInfo = info.line_info[li]
	var r := _rect(node)
	var y0 := l.ascender
	var y1 := l.descender
	return Rect2(Vector2(r.position.x, minf(y0, y1)), Vector2(r.size.x, absf(y1 - y0)))


## Line index under `position`, or -1.
## TMP: FindIntersectingLine
static func find_intersecting_line(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	var info: TypesetterTextInfo = text_node.text_info
	for li in info.line_count:
		var lr := _line_rect(info, li, text_node)
		if p.y >= lr.position.y and p.y <= lr.end.y:
			return li
	return -1


## Line nearest to `position`.
## TMP: FindNearestLine
static func find_nearest_line(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	return text_node.get_text_core().find_nearest_line(p)


## Link index under `position`, or -1.
## TMP: FindIntersectingLink
static func find_intersecting_link(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	var info: TypesetterTextInfo = text_node.text_info
	for li in info.link_count:
		var l: TypesetterLinkInfo = info.link_info[li]
		for ci in range(l.link_text_first_character_index, l.link_text_first_character_index + l.link_text_length):
			if ci < info.character_count and _cell(info, ci).has_point(p):
				return li
	return -1


## Link nearest to `position`.
## TMP: FindNearestLink
static func find_nearest_link(text_node: Node, position: Vector2, camera: Camera3D = null) -> int:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return -1
	var info: TypesetterTextInfo = text_node.text_info
	var best := -1
	var bd := INF
	for li in info.link_count:
		var l: TypesetterLinkInfo = info.link_info[li]
		for ci in range(l.link_text_first_character_index, l.link_text_first_character_index + l.link_text_length):
			if ci >= info.character_count:
				continue
			var d := _dist(_cell(info, ci), p)
			if d < bd:
				bd = d
				best = li
	return best


## Caret insertion index for `position`: [index, CaretPosition].
## TMP: GetCursorIndexFromPosition
static func get_cursor_index_from_position(text_node: Node, position: Vector2, camera: Camera3D = null) -> Array:
	var p = screen_point_to_local(text_node, position, camera)
	if p == null:
		return [0, CaretPosition.NONE]
	var info: TypesetterTextInfo = text_node.text_info
	if info.character_count == 0:
		return [0, CaretPosition.LEFT]
	var li: int = text_node.get_text_core().find_nearest_line(p)
	if li < 0:
		return [0, CaretPosition.LEFT]
	var line: TypesetterLineInfo = info.line_info[li]
	var best := line.first_character_index
	var bd := INF
	var side := CaretPosition.LEFT
	for ci in range(line.first_character_index, line.last_character_index + 1):
		var c: TypesetterCharacterInfo = info.character_info[ci]
		var dl := absf(p.x - c.origin)
		var dr := absf(p.x - c.x_advance)
		if dl < bd:
			bd = dl
			best = ci
			side = CaretPosition.LEFT
		if dr < bd:
			bd = dr
			best = ci
			side = CaretPosition.RIGHT
	return [best, side]


## Formats `{n}` / `{n:d}` placeholders (d = decimal places, or a zero pattern
## like `00.0`) with `args`. Used by set_text.
static func format_text(fmt: String, args: Array) -> String:
	var out := ""
	var i := 0
	while i < fmt.length():
		var ch := fmt[i]
		if ch == "{":
			var j := fmt.find("}", i)
			if j > i:
				var body := fmt.substr(i + 1, j - i - 1)
				var parts := body.split(":", true, 1)
				if parts[0].is_valid_int() and int(parts[0]) < args.size():
					out += _format_arg(args[int(parts[0])], parts[1] if parts.size() > 1 else "")
					i = j + 1
					continue
		out += ch
		i += 1
	return out


static func _format_arg(v: Variant, spec: String) -> String:
	if spec.is_empty():
		if v is float and is_equal_approx(v, roundf(v)):
			return str(int(v))
		return str(v)
	var x := float(v)
	# "{1:2}" is a decimal count; a leading zero ("00") is a padding pattern.
	if spec.is_valid_int() and not (spec.length() > 1 and spec.begins_with("0")):
		return ("%." + spec + "f") % x
	# Zero patterns: "00" (pad), "0.00" (decimals), "00.0".
	var dot := spec.find(".")
	var int_digits := (spec.length() if dot < 0 else dot)
	var decimals := 0 if dot < 0 else spec.length() - dot - 1
	var s := ("%." + str(decimals) + "f") % absf(x)
	var ip := s.split(".")[0]
	while ip.length() < int_digits:
		ip = "0" + ip
		s = "0" + s
	return ("-" if x < 0.0 else "") + s


## Case-insensitive hash of a string (TMP GetHashCodeCaseInSensitive).
static func get_hash_code_case_insensitive(s: String) -> int:
	return TypesetterStyle.get_hash_code(s)


## Case-sensitive hash (TMP GetSimpleHashCode).
static func get_simple_hash_code(s: String) -> int:
	var h := 0
	for i in s.length():
		h = (((h << 5) + h) ^ s.unicode_at(i)) & 0xFFFFFFFF
	return h


static func _scan(dir_key: String, ext_filter: Callable) -> Dictionary:
	var dir_path: String = TypesetterSettings.get_value(dir_key)
	var cache_key := dir_key + "|" + dir_path
	if _lookups.has(cache_key):
		return _lookups[cache_key]
	var d := {}
	if DirAccess.dir_exists_absolute(dir_path):
		for f in DirAccess.get_files_at(dir_path):
			var p := dir_path.path_join(f.trim_suffix(".remap"))
			if not (p.ends_with(".tres") or p.ends_with(".res")):
				continue
			var r = load(p)
			if ext_filter.call(r):
				d[p.get_file().get_basename()] = r
				if r.resource_name != "":
					d[r.resource_name] = r
	_lookups[cache_key] = d
	return d


## Name → TypesetterFontAsset for `<font="name">`, from the font asset folder
## (TypesetterSettings `default_font_asset_path`).
static func font_lookup() -> Dictionary:
	if _overrides.has("font"):
		return _overrides["font"]
	return _scan("default_font_asset_path", func(r): return r is TypesetterFontAsset)


## Name → Material for `<material="name">`, from the font asset folder.
static func material_lookup() -> Dictionary:
	return _scan("default_font_asset_path", func(r): return r is Material)


## Name → PackedColorArray for `<gradient="name">`, from the colour gradient folder.
static func gradient_lookup() -> Dictionary:
	if _overrides.has("gradient"):
		return _overrides["gradient"]
	var src := _scan("default_color_gradient_presets_path", func(r): return r is TypesetterColorGradient)
	var d := {}
	for k in src:
		d[k] = src[k].to_colors()
	return d


## Forgets scanned asset folders (call after adding assets at runtime).
static func clear_lookups() -> void:
	_lookups.clear()
	_overrides.clear()
	revision += 1


## Replaces a name lookup ("font" or "gradient") with `values`, instead of
## scanning the asset folder. For assets built at runtime.
static func set_lookup_override(kind: String, values: Dictionary) -> void:
	_overrides[kind] = values
	revision += 1
