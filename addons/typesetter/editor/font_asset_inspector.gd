@tool
extends EditorInspectorPlugin
## Inspector additions for TypesetterFontAsset: atlas preview, glyph and
## character counts, and the asset utilities from TMP's font asset inspector.

const MODES := ["SMOOTH", "SMOOTH_HINTED", "RASTER", "RASTER_HINTED", "SDF", "SDF8", "SDF16", "SDF32", "SDFAA", "SDFAA_HINTED", "MSDF", "MTSDF"]

var undo_redo: EditorUndoRedoManager


func _can_handle(object: Object) -> bool:
	return object is TypesetterFontAsset


func _parse_begin(object: Object) -> void:
	var a := object as TypesetterFontAsset
	var box := VBoxContainer.new()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fi := a.face_info
	var family := fi.family_name if fi else "?"
	var style := fi.style_name if fi else "?"
	info.text = "%s %s\nSampling %d pt, padding %d, %s\nGlyphs %d, characters %d, atlases %d" % [
		family, style, int(a.get_sampling_point_size()), a.atlas_padding, MODES[clampi(a.atlas_render_mode, 0, 11)],
		a.get_glyph_table().size(), a.get_character_table().size(), a.get_atlas_texture_count()]
	box.add_child(info)
	var tex := a.get_atlas_texture()
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.custom_minimum_size = Vector2(0, 200)
		box.add_child(tr)
	var row := HBoxContainer.new()
	var add := LineEdit.new()
	add.placeholder_text = "Characters to add"
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(add)
	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_add_characters.bind(a, add))
	row.add_child(add_btn)
	box.add_child(row)
	var row2 := HBoxContainer.new()
	var feat := Button.new()
	feat.text = "Get Font Features"
	feat.tooltip_text = "Read kerning (GPOS) and ligatures (GSUB) into the feature table."
	feat.pressed.connect(a.update_font_feature_table)
	row2.add_child(feat)
	var clear := Button.new()
	clear.text = "Clear Dynamic Data"
	clear.tooltip_text = "Remove all glyphs and reset the atlas (dynamic assets refill on use)."
	clear.pressed.connect(a.clear_font_asset_data.bind(false))
	row2.add_child(clear)
	var mat := Button.new()
	mat.text = "Reset Material"
	mat.pressed.connect(_reset_material.bind(a))
	row2.add_child(mat)
	box.add_child(row2)
	add_custom_control(box)


func _add_characters(a: TypesetterFontAsset, edit: LineEdit) -> void:
	var missing := a.try_add_characters_get_missing(edit.text, a.full_font_features)
	if not missing.is_empty():
		push_warning("Typesetter: not in font: " + missing)
	a.emit_changed()
	edit.text = ""


func _reset_material(a: TypesetterFontAsset) -> void:
	a.material = null
	TypesetterMaterialManager.get_default_material(a)
