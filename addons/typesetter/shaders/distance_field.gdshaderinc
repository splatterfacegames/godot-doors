// Typesetter distance-field text: shared uniforms and shading.
//
// The atlas stores 0.5 + d / (2 * gradient_scale) with d the signed distance to
// the glyph edge in atlas texels (positive inside). Every effect below is a
// function of that distance, converted to screen pixels with the screen-space
// derivatives of the atlas UV, so edges stay one pixel wide at any scale,
// rotation or perspective, in 2D and 3D.
//
// The variant defines TS_TEX: the atlas sampler (TEXTURE in 2D, main_tex in 3D).
//
// Feature defines (set by the variant shader):
//   TS_OUTLINE TS_UNDERLAY TS_GLOW TS_BEVEL TS_TEXTURES TS_MASK TS_MTSDF_EDGE

// --- face
uniform vec4 face_color : source_color = vec4(1.0);
uniform float face_dilate : hint_range(-1.0, 1.0) = 0.0;
uniform float outline_softness : hint_range(0.0, 1.0) = 0.0;
#ifdef TS_TEXTURES
uniform sampler2D face_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 face_tex_tiling = vec2(1.0);
uniform vec2 face_tex_offset = vec2(0.0);
uniform vec2 face_uv_speed = vec2(0.0);
#endif

// --- outline
#ifdef TS_OUTLINE
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 1.0) = 0.0;
#ifdef TS_TEXTURES
uniform sampler2D outline_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2 outline_tex_tiling = vec2(1.0);
uniform vec2 outline_tex_offset = vec2(0.0);
uniform vec2 outline_uv_speed = vec2(0.0);
#endif
#endif

// --- underlay
#ifdef TS_UNDERLAY
/// 0 none, 1 normal, 2 inner.
uniform int underlay_type : hint_range(0, 2) = 0;
uniform vec4 underlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float underlay_offset_x : hint_range(-1.0, 1.0) = 0.0;
uniform float underlay_offset_y : hint_range(-1.0, 1.0) = 0.0;
uniform float underlay_dilate : hint_range(-1.0, 1.0) = 0.0;
uniform float underlay_softness : hint_range(0.0, 1.0) = 0.0;
#endif

// --- glow
#ifdef TS_GLOW
uniform bool glow_enabled = false;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.0, 0.5);
uniform float glow_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float glow_inner : hint_range(0.0, 1.0) = 0.05;
uniform float glow_outer : hint_range(0.0, 1.0) = 0.05;
uniform float glow_power : hint_range(1.0, 0.0) = 0.75;
#endif

// --- lighting: bevel, local lighting, bump and environment maps
#ifdef TS_BEVEL
uniform bool bevel_enabled = false;
/// 0 outer bevel, 1 inner bevel.
uniform int bevel_type : hint_range(0, 1) = 0;
uniform float bevel : hint_range(0.0, 1.0) = 0.5;
uniform float bevel_offset : hint_range(-0.5, 0.5) = 0.0;
uniform float bevel_width : hint_range(-0.5, 0.5) = 0.0;
uniform float bevel_roundness : hint_range(0.0, 1.0) = 0.0;
uniform float bevel_clamp : hint_range(0.0, 1.0) = 0.0;
uniform float light_angle : hint_range(0.0, 6.2831853) = 3.1416;
uniform vec4 specular_color : source_color = vec4(1.0);
uniform float specular_power : hint_range(0.0, 4.0) = 2.0;
uniform float reflectivity : hint_range(5.0, 15.0) = 10.0;
uniform float diffuse : hint_range(0.0, 1.0) = 0.5;
uniform float ambient : hint_range(1.0, 0.0) = 0.5;
uniform sampler2D bump_map : hint_normal, repeat_enable, filter_linear;
uniform float bump_face : hint_range(0.0, 1.0) = 0.0;
uniform float bump_outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 reflect_face_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 reflect_outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform samplerCube cube : source_color, hint_default_black;
uniform vec3 env_matrix_rotation = vec3(0.0);
#endif

// --- weights, ratios and atlas
uniform float weight_normal = 0.0;
uniform float weight_bold = 0.75;
/// Atlas padding + 1 (set from the font asset).
uniform float gradient_scale = 10.0;
/// Effect normalisation (TMP's ScaleRatioA/B/C): keeps dilate + outline +
/// softness within the encoded distance range.
uniform float scale_ratio_a = 1.0;
uniform float scale_ratio_b = 1.0;
uniform float scale_ratio_c = 1.0;
uniform float perspective_filter : hint_range(0.0, 1.0) = 0.875;
uniform float sharpness : hint_range(-1.0, 1.0) = 0.0;
uniform float vertex_offset_x = 0.0;
uniform float vertex_offset_y = 0.0;

// --- masking (Masking overflow, ScrollRect): node-space rect and soft edge
#ifdef TS_MASK
#ifdef TS_INSTANCE_MASK
instance uniform vec4 clip_rect = vec4(-32767.0, -32767.0, 32767.0, 32767.0);
#else
uniform vec4 clip_rect = vec4(-32767.0, -32767.0, 32767.0, 32767.0);
#endif
uniform float mask_softness_x = 0.0;
uniform float mask_softness_y = 0.0;
#endif

/// Edge ramp: the anti-aliased transition spans 1 / TS_EDGE_RAMP pixels.
/// Calibrated against TextMesh Pro renders (tools/compare_renders.py): its
/// edges are about 1.33 px wide, slightly softer than exact pixel coverage.
const float TS_EDGE_RAMP = 0.75;

/// Screen pixels per atlas texel from the UV derivatives.
float ts_pixels_per_texel(vec2 uv, vec2 tex_size) {
	vec2 dx = dFdx(uv * tex_size);
	vec2 dy = dFdy(uv * tex_size);
	float texels_per_pixel = sqrt(0.5 * (dot(dx, dx) + dot(dy, dy)));
	return 1.0 / max(texels_per_pixel, 1e-5);
}

/// Distance sample (0..1, 0.5 on the edge). MTSDF atlases use the median of
/// RGB for the face edge; single-channel atlases store distance in red.
float ts_sample(vec2 uv) {
	vec4 s = texture(TS_TEX, uv);
#ifdef TS_MTSDF_EDGE
	return max(min(s.r, s.g), min(max(s.r, s.g), s.b));
#else
	return s.r;
#endif
}

float ts_sample_true(vec2 uv) {
	vec4 s = texture(TS_TEX, uv);
#ifdef TS_MTSDF_EDGE
	return s.a;
#else
	return s.r;
#endif
}

struct TsResult {
	vec4 color; // premultiplied
	float dist; // signed distance to the dilated face edge, pixels (positive inside)
};

/// Shades one fragment. `custom0` = (face_u, face_v, scale, flags).
vec4 ts_shade(vec2 uv, vec4 vcolor, vec4 custom0, float time) {
	vec2 tex_size = vec2(textureSize(TS_TEX, 0));
	float flags = custom0.w;
	bool bold = mod(flags, 2.0) >= 1.0;
	float d = ts_sample(uv);
	float ppt = ts_pixels_per_texel(uv, tex_size);
	// Pixels per unit of normalised distance (the 0..1 range spans 2 × gradient_scale texels).
	float scale = 2.0 * gradient_scale * ppt * (1.0 + sharpness) * TS_EDGE_RAMP;
	// Fitted against TextMesh Pro renders (tests/render, tp_style_bold).
	float weight = (bold ? weight_bold : weight_normal) * 0.125;
	// Edge threshold after dilation (normalised units).
	float bias = 0.5 - (face_dilate * 0.5 + weight) * scale_ratio_a;
	float sd = (d - bias) * scale; // pixels, positive inside
	float softness = outline_softness * scale_ratio_a * scale;
	vec4 fc = face_color * vcolor;
#ifdef TS_TEXTURES
	vec2 fuv = custom0.xy * face_tex_tiling + face_tex_offset + face_uv_speed * time;
	fc *= texture(face_tex, fuv);
#endif
	fc.rgb *= fc.a;
	vec4 color;
#ifdef TS_OUTLINE
	float ow = outline_width * scale_ratio_a * 0.5 * scale;
	vec4 oc = outline_color;
	oc.a *= vcolor.a;
#ifdef TS_TEXTURES
	vec2 ouv = custom0.xy * outline_tex_tiling + outline_tex_offset + outline_uv_speed * time;
	oc *= texture(outline_tex, ouv);
#endif
	oc.rgb *= oc.a;
	// Softness acts on the outer edge only (measured: fx_outline_soft).
	float face_a = clamp(sd - ow + 0.5, 0.0, 1.0);
	float outer_a = clamp((sd + ow) / (1.0 + softness) + 0.5, 0.0, 1.0);
	color = mix(oc, fc, ow > 0.0 ? face_a : 1.0) * outer_a;
#else
	float a = clamp(sd / (1.0 + softness) + 0.5, 0.0, 1.0);
	color = fc * a;
#endif

#ifdef TS_BEVEL
	if (bevel_enabled) {
		// Surface normal from the distance-field gradient.
		vec2 e = vec2(1.0 / tex_size.x, 0.0);
		vec2 f = vec2(0.0, 1.0 / tex_size.y);
		float dl = ts_sample_true(uv - e), dr = ts_sample_true(uv + e);
		float dd = ts_sample_true(uv - f), du = ts_sample_true(uv + f);
		float w = max(bevel_width + 0.5, 0.01);
		float h0 = clamp((d - bias + bevel_offset) / (w * scale_ratio_a), -1.0, 1.0);
		if (bevel_type == 1) { h0 = 1.0 - abs(h0); }
		float rnd = mix(1.0, sqrt(max(1.0 - h0 * h0, 0.0)), bevel_roundness);
		// Only the band around the edge tilts; the rest of the face stays flat (fx_bevel).
		float band = max(bevel_width, 0.01) * 0.5 * scale_ratio_a;
		float tilt = bevel * 2.0 * rnd * (1.0 - smoothstep(band * 0.8, band, abs(d - bias + bevel_offset)));
		vec3 n = normalize(vec3((dl - dr) * tilt, (du - dd) * tilt, 1.0 - bevel_clamp * 0.5));
		vec3 light = normalize(vec3(sin(light_angle), cos(light_angle), 1.0));
		// Fitted to TextMesh Pro's renders (fx_bevel): a flat face takes dot(n, l) at the
		// default diffuse, and specular only shows where the surface tilts to the light.
		float spec = pow(max(reflect(-light, n).z, 0.0), reflectivity) * specular_power * min(tilt, 1.0);
		float diff = max(dot(n, light), 0.0);
		vec3 lit = color.rgb * max(mix(1.0, diff, clamp(diffuse * 2.0, 0.0, 1.0)), ambient) + specular_color.rgb * spec * color.a;
		vec3 refl = texture(cube, reflect(vec3(0.0, 0.0, -1.0), n)).rgb;
		lit += refl * mix(reflect_outline_color.rgb, reflect_face_color.rgb, clamp(sd + 0.5, 0.0, 1.0)) * color.a;
		color.rgb = lit;
	}
#endif

#ifdef TS_UNDERLAY
	if (underlay_type > 0) {
		vec2 off = vec2(underlay_offset_x, -underlay_offset_y) * gradient_scale * scale_ratio_c / tex_size;
		float du = ts_sample_true(uv - off);
		float ub = 0.5 - underlay_dilate * 0.5 * scale_ratio_c;
		float us = underlay_softness * scale_ratio_c * scale;
		float ua = clamp((du - ub) * scale / (1.0 + us) + 0.5, 0.0, 1.0);
		vec4 uc = underlay_color;
		uc.a *= vcolor.a;
		// An inner underlay is cut by the face edge and, like a normal one, sits behind
		// the face: an opaque face hides it (measured: fx_underlay_inner).
		if (underlay_type == 2) {
			ua = (1.0 - ua) * clamp(sd + 0.5, 0.0, 1.0);
		}
		uc.rgb *= uc.a;
		color = color + uc * ua * (1.0 - color.a);
	}
#endif

#ifdef TS_GLOW
	if (glow_enabled) {
		// Fitted to TextMesh Pro's renders (fx_glow*): in pixels from the glow's centre,
		// with half a pixel of extra span, fully on until about half way.
		float gx = (d - (0.5 - glow_offset * 0.5 * scale_ratio_b)) * scale;
		float span = (gx >= 0.0 ? glow_inner : glow_outer) * scale_ratio_b * 0.5 * scale;
		float g = clamp(2.0 * (1.0 - pow(min(abs(gx) / (0.5 + span), 1.0), max(glow_power, 1e-3))), 0.0, 1.0);
		vec4 gc = glow_color;
		gc.a *= g * vcolor.a;
		color.rgb = color.rgb + gc.rgb * gc.a;
		color.a = max(color.a, gc.a);
	}
#endif
	return color;
}

/// Solid-colour quads (highlight, underline, strikethrough).
vec4 ts_solid(vec4 vcolor) {
	vec4 c = vcolor;
	c.rgb *= c.a;
	return c;
}

#ifdef TS_MASK
float ts_mask(vec2 p) {
	vec2 lo = clip_rect.xy, hi = clip_rect.zw;
	vec2 soft = max(vec2(mask_softness_x, mask_softness_y), vec2(1e-4));
	vec2 m = clamp((p - lo) / soft, 0.0, 1.0) * clamp((hi - p) / soft, 0.0, 1.0);
	return m.x * m.y;
}
#endif
