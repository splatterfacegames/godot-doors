class_name TypesetterTextLayout
extends RefCounted
## Text as a service, for code that owns its own layout and drawing.
##
## Measures, lays out and draws styled text into any CanvasItem without a text
## node. It uses the same TypesetterTextCore as TypesetterLabel. Sizes and
## positions are fractional and never rounded.
##
##     var layout := TypesetterTextLayout.new()
##     layout.set_style(style)
##     layout.set_text("Hello <b>world</b>")
##     var size := layout.measure(Vector2(max_width, INF))
##     layout.layout(Rect2(0, 0, width, height))
##     layout.draw(get_canvas_item())

var _style: TypesetterTextStyle
var _text := ""
var _core: TypesetterTextCore = TypesetterTextCore.new()
var _rect := Rect2()
var _dirty := true
var _measured := {}
var _meshes: Array[ArrayMesh] = []
var _surfaces: Array[Dictionary] = []
var _items: Array[RID] = []
var _material: Material
var _material_key: Array = []

## textInfo of the last layout (characters, words, lines, pages, links, meshes).
var text_info: TypesetterTextInfo:
	get:
		_ensure_layout()
		return _core.get_text_info()


func _init() -> void:
	_core.world_space = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Methods cannot be called while the object is being freed.
		for it in _items:
			RenderingServer.free_rid(it)


func set_style(style: TypesetterTextStyle) -> void:
	_style = style
	_dirty = true


func get_style() -> TypesetterTextStyle:
	return _style


func set_text(value: String) -> void:
	if value == _text:
		return
	_text = value
	_dirty = true


func get_text() -> String:
	return _text


## Marks the layout out of date after a change inside the style resource.
func invalidate() -> void:
	_dirty = true


## Size the text needs inside `available`; pass INF on an axis for no limit.
## Wrapped text reports the available width (CSS fit-content behaviour).
## Does not change the current layout.
func measure(available: Vector2 = Vector2(INF, INF)) -> Vector2:
	if _style == null or _style.font == null:
		return Vector2.ZERO
	_ensure_layout()
	# Flex layout asks the same question many times per pass.
	if _measured.has(available):
		return _measured[available]
	var size := _core.get_preferred_values(available.x, available.y)
	# Preferred width ignores wrapping; a box fits its content up to what is available.
	if size.x > available.x:
		size.x = available.x
	_measured[available] = size
	return size


## Lays the text out in `rect`. `rect.position` is applied when drawing.
func layout(rect: Rect2) -> void:
	if rect.size != _rect.size:
		_dirty = true
	_rect = rect
	_ensure_layout()


## Rendered size of the last layout.
func get_rendered_size(only_visible: bool = true) -> Vector2:
	_ensure_layout()
	return _core.get_rendered_values(only_visible)


func is_overflowing() -> bool:
	_ensure_layout()
	return _core.is_text_overflowing()


## Draws into `canvas_item` on child canvas items owned by this object, one per
## atlas or material. They stay until the next draw() or clear(). They render
## over what the parent item draws itself unless `draw_index` is negative.
func draw(canvas_item: RID, xform: Transform2D = Transform2D(), modulate: Color = Color.WHITE, draw_index: int = 0) -> void:
	_ensure_layout()
	_build_surfaces()
	while _items.size() < _surfaces.size():
		var it := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_default_texture_filter(it, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		_items.append(it)
	while _items.size() > _surfaces.size():
		RenderingServer.free_rid(_items.pop_back())
	var placed := xform * Transform2D(0.0, _rect.position)
	for i in _surfaces.size():
		var s := _surfaces[i]
		var it := _items[i]
		var tex: Texture2D = s.get("texture")
		var mat: Material = s.get("material_used")
		RenderingServer.canvas_item_clear(it)
		RenderingServer.canvas_item_set_parent(it, canvas_item)
		RenderingServer.canvas_item_set_transform(it, placed)
		RenderingServer.canvas_item_set_draw_index(it, draw_index + i)
		RenderingServer.canvas_item_set_modulate(it, modulate)
		RenderingServer.canvas_item_set_material(it, mat.get_rid() if mat else RID())
		RenderingServer.canvas_item_add_mesh(it, (s.mesh as ArrayMesh).get_rid(), Transform2D(), Color.WHITE, tex.get_rid() if tex else RID())


## Removes everything draw() created.
func clear() -> void:
	for it in _items:
		RenderingServer.free_rid(it)
	_items.clear()


## Number of canvas items the last draw() used (batches).
func get_surface_count() -> int:
	return _surfaces.size()


func _ensure_layout() -> void:
	if not _dirty:
		return
	_dirty = false
	_surfaces.clear()
	_measured.clear()
	if _style == null or _style.font == null:
		return
	_sync()
	_core.update()


func _sync() -> void:
	var s := _style
	var c := _core
	c.text = _text
	c.font = s.font
	c.rect_size = _rect.size
	c.world_space = false
	c.font_size = s.font_size
	c.color = s.color
	c.font_style = s.font_style
	c.font_weight = s.font_weight
	c.alignment = s.alignment
	c.text_wrapping_mode = s.text_wrapping_mode
	c.overflow_mode = s.overflow_mode
	c.character_spacing = s.character_spacing
	c.word_spacing = s.word_spacing
	c.line_spacing = s.line_spacing
	c.paragraph_spacing = s.paragraph_spacing
	c.margin = s.margin
	c.rich_text = s.rich_text
	c.enable_kerning = s.enable_kerning
	c.extra_padding = s.extra_padding
	c.lookups_revision += 1
	var sheet := TypesetterSettings.get_default_style_sheet()
	c.style_lookup = sheet.to_lookup() if sheet != null else {}
	var sprites: Array[Resource] = []
	var sa := TypesetterSettings.get_default_sprite_asset()
	if sa != null:
		sprites.append(sa)
	c.sprite_assets = sprites
	c.font_lookup = TypesetterTextUtilities.font_lookup()
	c.material_lookup = TypesetterTextUtilities.material_lookup()
	c.gradient_lookup = TypesetterTextUtilities.gradient_lookup()
	c.fallback_font_assets = TypesetterSettings.get_fallback_font_assets()
	c.missing_glyph_character = TypesetterSettings.get_missing_glyph_character()
	c.leading_characters = TypesetterSettings.get_leading_characters()
	c.following_characters = TypesetterSettings.get_following_characters()
	var bitmap := s.font.atlas_render_mode <= TypesetterFontAsset.RASTER_HINTED
	var base := 1.0 if bitmap else 1.25
	var bold := s.font_style & 1 != 0 or (s.rich_text and _text.findn("<b>") >= 0)
	c.mesh_padding = base + (0.0 if bitmap else TypesetterShaderUtilities.get_padding(_base_material(), s.extra_padding, bold))


func _base_material() -> Material:
	var s := _style
	if s.material != null:
		return s.material
	var base := TypesetterMaterialManager.get_default_material(s.font)
	if not s.needs_own_material():
		return base
	var key := [s.font, s.outline_width, s.outline_color, s.underlay_enabled, s.underlay_color, s.underlay_offset_x, s.underlay_offset_y, s.underlay_dilate, s.underlay_softness]
	if key == _material_key and _material != null:
		return _material
	_material_key = key
	var m: ShaderMaterial = base.duplicate()
	m.set_shader_parameter(&"outline_width", s.outline_width)
	m.set_shader_parameter(&"outline_color", s.outline_color)
	if s.underlay_enabled:
		m.set_shader_parameter(&"underlay_color", s.underlay_color)
		m.set_shader_parameter(&"underlay_offset_x", s.underlay_offset_x)
		m.set_shader_parameter(&"underlay_offset_y", s.underlay_offset_y)
		m.set_shader_parameter(&"underlay_dilate", s.underlay_dilate)
		m.set_shader_parameter(&"underlay_softness", s.underlay_softness)
	TypesetterShaderUtilities.update_shader_ratios(m)
	_material = m
	return m


func _build_surfaces() -> void:
	if not _surfaces.is_empty() or _style == null or _style.font == null:
		return
	var arr: Array[ArrayMesh] = []
	arr.assign(_meshes)
	var dicts := _core.build_meshes(arr)
	_meshes.clear()
	var base := _base_material()
	for d: Dictionary in dicts:
		_meshes.append(d.mesh)
		var tex: Texture2D = d.get("texture")
		var surface_base: Material = d.get("material", base)
		if surface_base == null:
			surface_base = base
		d["material_used"] = TypesetterMaterialManager.get_surface_material(surface_base, _style.font, d.get("font"), 0, false, false, tex, d.get("sprite", false))
		_surfaces.append(d)
