@tool
class_name TypesetterMaterialManager
extends RefCounted
## Creates and shares the materials Typesetter draws with (TMP_MaterialManager).
##
## * Every font asset owns a default 2D material (`TypesetterFontAsset.material`),
##   created on first use with the shader matching the atlas render mode.
## * A surface drawn with a font asset other than the material's own (a fallback
##   font, a `<font>` tag), with a different atlas page, or in 3D gets a derived
##   material: a copy of the base material's parameters on the right shader
##   variant with that asset's gradient scale and atlas texture. Derived
##   materials are cached and re-synchronised when the base changes.
## TMP: TMP_MaterialManager

const SHADER_DIR := "res://addons/typesetter/shaders/"
## Parameters owned by the surface, never copied from the base material.
const SURFACE_PARAMS := [&"main_tex", &"gradient_scale", &"texture_width", &"texture_height"]

static var _shaders := {}
## key → {"material": ShaderMaterial, "base": WeakRef, "stamp": int}
static var _derived := {}
static var _stamps := {}


## Shader family for an atlas render mode.
static func family_for_render_mode(render_mode: int) -> String:
	if render_mode <= TypesetterFontAsset.RASTER_HINTED:
		return "typesetter_bitmap"
	if render_mode == TypesetterFontAsset.MSDF or render_mode == TypesetterFontAsset.MTSDF:
		return "typesetter_distance_field_msdf"
	return "typesetter_distance_field"


static func get_shader(family: String, is_3d: bool, overlay: bool = false) -> Shader:
	var suffix := ""
	if is_3d:
		suffix = "_overlay_3d" if overlay else "_3d"
	var path := SHADER_DIR + family + suffix + ".gdshader"
	if not _shaders.has(path):
		_shaders[path] = load(path) if ResourceLoader.exists(path) else null
	return _shaders[path]


## The family a Typesetter shader belongs to ("" for other shaders).
static func family_of(shader: Shader) -> String:
	if shader == null or not shader.resource_path.begins_with(SHADER_DIR):
		return ""
	var n := shader.resource_path.get_file().get_basename()
	for s in ["_overlay_3d", "_3d"]:
		if n.ends_with(s):
			return n.substr(0, n.length() - s.length())
	return n


## The font asset's default 2D material, created on first use
## (TMP: the material sub-asset created with the font asset).
static func get_default_material(asset: TypesetterFontAsset) -> Material:
	if asset == null:
		return null
	if asset.material == null:
		var m := ShaderMaterial.new()
		m.resource_name = asset.resource_name + " Material"
		m.shader = get_shader(family_for_render_mode(asset.atlas_render_mode), false)
		apply_font_asset(m, asset)
		asset.material = m
	return asset.material


## Writes the asset-dependent parameters into a material.
static func apply_font_asset(m: ShaderMaterial, asset: TypesetterFontAsset, atlas_index: int = 0) -> void:
	if m == null or asset == null:
		return
	m.set_shader_parameter(&"gradient_scale", asset.get_gradient_scale())
	m.set_shader_parameter(&"weight_normal", asset.normal_style)
	m.set_shader_parameter(&"weight_bold", asset.bold_style)
	var tex: Texture2D = asset.atlas_textures[atlas_index] if atlas_index < asset.atlas_textures.size() else null
	if tex != null:
		m.set_shader_parameter(&"main_tex", tex)
		m.set_shader_parameter(&"texture_width", tex.get_width())
		m.set_shader_parameter(&"texture_height", tex.get_height())
	TypesetterShaderUtilities.update_shader_ratios(m)


## Bumps a material's change stamp so derived materials re-synchronise
## (call after editing a base material's parameters from code).
static func mark_changed(m: Material) -> void:
	if m != null:
		_stamps[m.get_instance_id()] = int(_stamps.get(m.get_instance_id(), 0)) + 1


## The material to draw one surface with.
## `base`: the text's material (font_shared_material or the primary asset's).
## `owner_asset`: the asset `base` belongs to. `asset`/`atlas_index`: what the
## surface samples. `texture`: the surface texture (sprite sheet or atlas).
static func get_surface_material(base: Material, owner_asset: TypesetterFontAsset, asset: Resource, atlas_index: int, is_3d: bool, overlay: bool, texture: Texture2D, sprite: bool = false) -> Material:
	if sprite:
		var sm: Material = asset.get("material") if asset != null else null
		if sm != null and not is_3d:
			return sm
		return _derive(null, "typesetter_sprite", null, 0, is_3d, overlay, texture)
	var fa := asset as TypesetterFontAsset
	if base == null and fa != null:
		base = get_default_material(fa)
	var sbase := base as ShaderMaterial
	if sbase == null:
		return base
	var fam := family_of(sbase.shader)
	if fam.is_empty():
		# A custom shader: used as-is in 2D; in 3D the atlas goes in main_tex.
		if not is_3d:
			return base
		return _derive(sbase, "", fa, atlas_index, true, false, texture)
	if fa != null:
		# The atlas render mode decides between bitmap / SDF / MSDF shaders.
		var want := family_for_render_mode(fa.atlas_render_mode)
		if want == "typesetter_distance_field" and fam == "typesetter_distance_field_mobile":
			want = fam
		fam = want
	var same_asset := fa == null or fa == owner_asset
	if not is_3d and same_asset and fam == family_of(sbase.shader) and (texture == null or sbase.get_shader_parameter(&"main_tex") == texture):
		return base
	return _derive(sbase, fam, fa, atlas_index, is_3d, overlay, texture)


static func _derive(base: ShaderMaterial, fam: String, asset: TypesetterFontAsset, atlas_index: int, is_3d: bool, overlay: bool, texture: Texture2D) -> ShaderMaterial:
	var key := "%d|%s|%d|%d|%s|%s|%d" % [base.get_instance_id() if base else 0, fam, asset.get_instance_id() if asset else 0, atlas_index, is_3d, overlay, texture.get_instance_id() if texture else 0]
	var e: Dictionary = _derived.get(key, {})
	var m: ShaderMaterial = e.get("material")
	if m == null:
		m = ShaderMaterial.new()
		m.shader = get_shader(fam, is_3d, overlay) if not fam.is_empty() else base.shader
		e = {"material": m, "stamp": -1, "base": weakref(base) if base else null}
		_derived[key] = e
	var stamp: int = _stamps.get(base.get_instance_id(), 0) if base else 0
	if e.stamp != stamp or Engine.is_editor_hint():
		if base != null:
			copy_parameters(base, m)
			m.render_priority = base.render_priority
		if asset != null:
			apply_font_asset(m, asset, atlas_index)
		e.stamp = stamp
	if texture != null:
		m.set_shader_parameter(&"main_tex", texture)
	return m


## Copies every shader parameter of `from` that `to`'s shader declares.
static func copy_parameters(from: ShaderMaterial, to: ShaderMaterial) -> void:
	if from.shader == null or to.shader == null:
		return
	var names := {}
	for u in to.shader.get_shader_uniform_list(true):
		names[StringName(u.name)] = true
	for u in from.shader.get_shader_uniform_list(true):
		var n := StringName(u.name)
		if names.has(n) and not n in SURFACE_PARAMS:
			to.set_shader_parameter(n, from.get_shader_parameter(n))


## Drops derived materials whose base material no longer exists.
static func cleanup() -> void:
	for k in _derived.keys():
		var w: WeakRef = _derived[k].get("base")
		if w != null and w.get_ref() == null:
			_derived.erase(k)


## TMP: TMP_MaterialManager.GetFallbackMaterial — the material a fallback asset
## uses when drawn by text whose primary material is `base`.
static func get_fallback_material(base: Material, fallback: TypesetterFontAsset, is_3d: bool = false) -> Material:
	return get_surface_material(base, null, fallback, 0, is_3d, false, fallback.get_atlas_texture() if fallback else null)
