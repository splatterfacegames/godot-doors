@tool
class_name TypesetterShaderUtilities
extends RefCounted
## Material helpers for the Typesetter shaders (TMP ShaderUtilities): the
## effect scale ratios, the quad padding a material needs, and the shader
## parameter names.
## TMP: ShaderUtilities

# Shader parameter names (TMP ShaderUtilities.ID_*).
const ID_MAIN_TEX := &"main_tex"
const ID_FACE_TEX := &"face_tex"
const ID_FACE_COLOR := &"face_color"
const ID_FACE_DILATE := &"face_dilate"
const ID_SHININESS := &"specular_power"
const ID_UNDERLAY_COLOR := &"underlay_color"
const ID_UNDERLAY_OFFSET_X := &"underlay_offset_x"
const ID_UNDERLAY_OFFSET_Y := &"underlay_offset_y"
const ID_UNDERLAY_DILATE := &"underlay_dilate"
const ID_UNDERLAY_SOFTNESS := &"underlay_softness"
const ID_WEIGHT_NORMAL := &"weight_normal"
const ID_WEIGHT_BOLD := &"weight_bold"
const ID_OUTLINE_TEX := &"outline_tex"
const ID_OUTLINE_WIDTH := &"outline_width"
const ID_OUTLINE_SOFTNESS := &"outline_softness"
const ID_OUTLINE_COLOR := &"outline_color"
const ID_PADDING := &"padding"
const ID_GRADIENT_SCALE := &"gradient_scale"
const ID_SCALE_X := &"scale_x"
const ID_SCALE_Y := &"scale_y"
const ID_PERSPECTIVE_FILTER := &"perspective_filter"
const ID_SHARPNESS := &"sharpness"
const ID_TEXTURE_WIDTH := &"texture_width"
const ID_TEXTURE_HEIGHT := &"texture_height"
const ID_BEVEL_AMOUNT := &"bevel"
const ID_GLOW_COLOR := &"glow_color"
const ID_GLOW_OFFSET := &"glow_offset"
const ID_GLOW_POWER := &"glow_power"
const ID_GLOW_OUTER := &"glow_outer"
const ID_GLOW_INNER := &"glow_inner"
const ID_LIGHT_ANGLE := &"light_angle"
const ID_ENV_MAP := &"cube"
const ID_ENV_MATRIX := &"env_matrix_rotation"
const ID_SPECULAR_COLOR := &"specular_color"
const ID_DIFFUSE_POWER := &"diffuse"
const ID_REFLECTIVITY := &"reflectivity"
const ID_AMBIENT := &"ambient"
const ID_CLIP_RECT := &"clip_rect"
const ID_MASK_SOFTNESS_X := &"mask_softness_x"
const ID_MASK_SOFTNESS_Y := &"mask_softness_y"
const ID_VERTEX_OFFSET_X := &"vertex_offset_x"
const ID_VERTEX_OFFSET_Y := &"vertex_offset_y"
const ID_SCALE_RATIO_A := &"scale_ratio_a"
const ID_SCALE_RATIO_B := &"scale_ratio_b"
const ID_SCALE_RATIO_C := &"scale_ratio_c"
const ID_UNDERLAY_TYPE := &"underlay_type"
const ID_GLOW_ENABLED := &"glow_enabled"
const ID_BEVEL_ENABLED := &"bevel_enabled"

# Feature switches (TMP ShaderUtilities.Keyword_*). Typesetter shaders use
# uniforms instead of keywords: set these parameters to enable a feature.
const KEYWORD_BEVEL := &"bevel_enabled"
const KEYWORD_GLOW := &"glow_enabled"
const KEYWORD_UNDERLAY := &"underlay_type"
const KEYWORD_RATIOS := &"ratios_disabled"
const KEYWORD_MASK_SOFT := &"mask_softness_x"
const KEYWORD_OUTLINE := &"outline_width"

const _DEFAULTS := {
	&"face_dilate": 0.0, &"outline_width": 0.0, &"outline_softness": 0.0,
	&"underlay_offset_x": 0.0, &"underlay_offset_y": 0.0, &"underlay_dilate": 0.0,
	&"underlay_softness": 0.0, &"underlay_type": 0, &"glow_offset": 0.0, &"glow_outer": 0.05,
	&"glow_inner": 0.05, &"glow_enabled": false, &"weight_normal": 0.0, &"weight_bold": 0.75,
	&"gradient_scale": 10.0, &"ratios_disabled": false,
}


static func _f(m: ShaderMaterial, n: StringName) -> float:
	var v = m.get_shader_parameter(n)
	if v == null:
		v = _DEFAULTS.get(n, 0.0)
	return float(v)


static func _b(m: ShaderMaterial, n: StringName) -> bool:
	var v = m.get_shader_parameter(n)
	if v == null:
		v = _DEFAULTS.get(n, false)
	return bool(v)


## True when the material uses a Typesetter distance-field shader.
static func is_distance_field(m: Material) -> bool:
	var sm := m as ShaderMaterial
	return sm != null and TypesetterMaterialManager.family_of(sm.shader).begins_with("typesetter_distance_field")


## Recomputes scale_ratio_a/b/c: the factors that keep face dilate + outline +
## softness (A), glow (B) and underlay (C) inside the distance range the atlas
## encodes, so effects never clip at the quad edge.
## TMP: UpdateShaderRatios
static func update_shader_ratios(m: Material) -> void:
	var sm := m as ShaderMaterial
	if sm == null or not is_distance_field(sm):
		return
	var g := _f(sm, &"gradient_scale")
	var weight := maxf(_f(sm, &"weight_normal"), _f(sm, &"weight_bold")) / 4.0
	var range_ := (g - 1.0) / g
	if _b(sm, &"ratios_disabled"):
		sm.set_shader_parameter(&"scale_ratio_a", 1.0)
		sm.set_shader_parameter(&"scale_ratio_b", 1.0)
		sm.set_shader_parameter(&"scale_ratio_c", 1.0)
		return
	# A: face dilate, outline width and softness.
	var t := maxf(1.0, weight + _f(sm, &"face_dilate") + _f(sm, &"outline_width") + _f(sm, &"outline_softness"))
	var ratio_a := range_ / t
	# B: glow.
	var glow := maxf(1.0, _f(sm, &"glow_offset") + _f(sm, &"glow_outer"))
	var ratio_b := range_ * (1.0 - weight) / glow
	# C: underlay offset, dilate and softness.
	var off := maxf(absf(_f(sm, &"underlay_offset_x")), absf(_f(sm, &"underlay_offset_y")))
	var tc := maxf(1.0, off + _f(sm, &"underlay_dilate") + _f(sm, &"underlay_softness"))
	var ratio_c := range_ * (1.0 - weight) / tc
	sm.set_shader_parameter(&"scale_ratio_a", ratio_a)
	sm.set_shader_parameter(&"scale_ratio_b", ratio_b)
	sm.set_shader_parameter(&"scale_ratio_c", ratio_c)


## Extra quad padding a material needs, in sampling-point pixels, on top of the
## base padding (effects that extend past the glyph edge: outline, dilate,
## softness, underlay, glow, bold weight).
## TMP: GetPadding(Material, bool enableExtraPadding, bool isBold)
static func get_padding(m: Material, enable_extra_padding: bool, is_bold: bool) -> float:
	var sm := m as ShaderMaterial
	if sm == null or not is_distance_field(sm):
		return 1.0 if not enable_extra_padding else 4.0
	update_shader_ratios(sm)
	var g := _f(sm, &"gradient_scale")
	var ra := _f(sm, &"scale_ratio_a")
	var rb := _f(sm, &"scale_ratio_b")
	var rc := _f(sm, &"scale_ratio_c")
	var weight := (_f(sm, &"weight_bold") if is_bold else _f(sm, &"weight_normal")) / 4.0
	var face := (weight + _f(sm, &"face_dilate")) * ra
	var outline := (_f(sm, &"outline_width") + _f(sm, &"outline_softness")) * ra
	var pad := maxf(face + outline, 0.0)
	if int(_f(sm, &"underlay_type")) > 0:
		var off := maxf(absf(_f(sm, &"underlay_offset_x")), absf(_f(sm, &"underlay_offset_y")))
		pad = maxf(pad, (off + _f(sm, &"underlay_dilate") + _f(sm, &"underlay_softness")) * rc)
	if _b(sm, &"glow_enabled"):
		pad = maxf(pad, (_f(sm, &"glow_offset") + _f(sm, &"glow_outer")) * rb)
	var extra := 4.0 if enable_extra_padding else 0.0
	return minf(pad * g + extra, g)


## TMP: IsMaskingEnabled
static func is_masking_enabled(m: Material) -> bool:
	var sm := m as ShaderMaterial
	if sm == null:
		return false
	var r = sm.get_shader_parameter(&"clip_rect")
	return r != null and r != Vector4(-32767, -32767, 32767, 32767)


## Copies material parameters between two Typesetter materials.
## TMP: TMP_MaterialManager.CopyMaterialPresetProperties
static func copy_material_preset_properties(from: Material, to: Material) -> void:
	if from is ShaderMaterial and to is ShaderMaterial:
		TypesetterMaterialManager.copy_parameters(from, to)
