@tool
class_name TypesetterSpriteAnimator
extends Node
## Plays sprite animations written as `<sprite anim="first,last,frame_rate">`
## by cycling the sprite quad through the sprite asset's glyphs
## (TMP_SpriteAnimator). Text nodes create it on demand.
## TMP: TMP_SpriteAnimator

var _anims := {} # character index → {asset, start, end, rate, t, frame}


## Animates character `character_index` through glyphs `start`..`end` of
## `sprite_asset` at `frame_rate` frames per second.
## TMP: DoSpriteAnimation
func do_sprite_animation(character_index: int, sprite_asset: TypesetterSpriteAsset, start: int, end: int, frame_rate: int) -> void:
	_anims[character_index] = {"asset": sprite_asset, "start": start, "end": end, "rate": maxf(frame_rate, 0.01), "t": 0.0, "frame": start}
	set_process(true)


## TMP: StopAllAnimations
func stop_all_animations() -> void:
	_anims.clear()
	set_process(false)


func _ready() -> void:
	set_process(not _anims.is_empty())


## Re-reads `anim` attributes from the parent's text (called after layout).
func refresh_from_text() -> void:
	var host := get_parent()
	if host == null or not host.has_method(&"get_text_core"):
		return
	var src: String = host.text
	var re := RegEx.create_from_string(r'<sprite[^>]*anim\s*=\s*"?\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)')
	var anims: Array = []
	var tag_re := RegEx.create_from_string("<sprite[^>]*>")
	for m in tag_re.search_all(src):
		var a := re.search(m.get_string())
		anims.append([int(a.get_string(1)), int(a.get_string(2)), int(a.get_string(3))] if a else null)
	var info: TypesetterTextInfo = host.text_info
	var k := 0
	var keep := {}
	for i in info.character_count:
		var c: TypesetterCharacterInfo = info.character_info[i]
		if c.element_type != 1:
			continue
		if k < anims.size() and anims[k] != null:
			var sa: TypesetterSpriteAsset = host.sprite_asset if host.sprite_asset else TypesetterSettings.get_default_sprite_asset()
			if sa != null and not _anims.has(i):
				do_sprite_animation(i, sa, anims[k][0], anims[k][1], anims[k][2])
			keep[i] = true
		k += 1
	for i in _anims.keys():
		if not keep.has(i):
			_anims.erase(i)
	set_process(not _anims.is_empty())


func _process(delta: float) -> void:
	var host := get_parent()
	if host == null or _anims.is_empty():
		return
	var info: TypesetterTextInfo = host.text_info
	var changed := false
	for ci in _anims:
		var a: Dictionary = _anims[ci]
		a.t += delta
		var step: float = 1.0 / a.rate
		if a.t < step:
			continue
		a.t = fmod(a.t, step)
		a.frame = a.start if a.frame >= a.end else a.frame + 1
		var d: Dictionary = (a.asset as TypesetterSpriteAsset).find_sprite(a.frame, "")
		if d.is_empty() or ci >= info.character_count:
			continue
		var c: TypesetterCharacterInfo = info.character_info[ci]
		var mi_index: int = c.material_reference_index
		if mi_index < 0 or mi_index >= info.mesh_info.size():
			continue
		var mi: TypesetterMeshInfo = info.mesh_info[mi_index]
		var r: Rect2 = d.rect
		var sz: Vector2 = d.atlas_size
		var u0 := r.position.x / sz.x
		var u1 := r.end.x / sz.x
		var v0 := r.position.y / sz.y
		var v1 := r.end.y / sz.y
		var vi: int = c.vertex_index
		if vi + 3 >= mi.uvs0.size():
			continue
		# Quad order: bottom-left, top-left, top-right, bottom-right.
		mi.uvs0[vi] = Vector4(u0, v1, mi.uvs0[vi].z, mi.uvs0[vi].w)
		mi.uvs0[vi + 1] = Vector4(u0, v0, mi.uvs0[vi + 1].z, mi.uvs0[vi + 1].w)
		mi.uvs0[vi + 2] = Vector4(u1, v0, mi.uvs0[vi + 2].z, mi.uvs0[vi + 2].w)
		mi.uvs0[vi + 3] = Vector4(u1, v1, mi.uvs0[vi + 3].z, mi.uvs0[vi + 3].w)
		changed = true
	if changed:
		host.update_vertex_data(2)
