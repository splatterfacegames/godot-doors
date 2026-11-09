@tool
extends VBoxContainer
## Typesetter Font Asset Creator: builds a static (or dynamic) font asset from
## a font file and a character set, previews the atlas and saves the asset.
## TMP: Window > TextMeshPro > Font Asset Creator

const CHARACTER_SETS := ["ASCII", "Extended ASCII", "ASCII Lowercase", "ASCII Uppercase", "Numbers + Symbols", "Custom Range", "Unicode Range (Hex)", "Custom Characters", "Characters from File", "Dynamic (empty)"]
const RENDER_MODES := ["SMOOTH", "SMOOTH_HINTED", "RASTER", "RASTER_HINTED", "SDF", "SDF8", "SDF16", "SDF32", "SDFAA", "SDFAA_HINTED", "MSDF", "MTSDF"]
const SIZES := [64, 128, 256, 512, 1024, 2048, 4096, 8192]

var editor_interface: Object

var _font_path: LineEdit
var _auto_size: CheckBox
var _point_size: SpinBox
var _padding: SpinBox
var _packing: OptionButton
var _width: OptionButton
var _height: OptionButton
var _charset: OptionButton
var _custom: TextEdit
var _render_mode: OptionButton
var _features: CheckBox
var _multi_atlas: CheckBox
var _report: RichTextLabel
var _preview: TextureRect
var _asset: TypesetterFontAsset
var _file_dialog: EditorFileDialog
var _save_dialog: EditorFileDialog
var _picking := ""


func _ready() -> void:
	name = "Font Asset Creator"
	custom_minimum_size = Vector2(280, 0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(box)

	var hb := HBoxContainer.new()
	_font_path = LineEdit.new()
	_font_path.placeholder_text = "res://fonts/MyFont.ttf"
	_font_path.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(_font_path)
	var pick := Button.new()
	pick.text = "…"
	pick.pressed.connect(func(): _picking = "font"; _file_dialog.popup_file_dialog())
	hb.add_child(pick)
	_row(box, "Source Font File", hb)

	_auto_size = CheckBox.new()
	_auto_size.text = "Auto Sizing"
	_auto_size.button_pressed = true
	_row(box, "Sampling Point Size", _auto_size)
	_point_size = _spin(box, "Custom Size", 1, 1024, 90)
	_padding = _spin(box, "Padding", 0, 64, 9)
	_packing = _options(box, "Packing Method", ["Best Short Side Fit (Optimum)", "Best Long Side Fit", "Best Area Fit", "Bottom Left Rule", "Contact Point Rule", "Fast"], 0)
	_width = _options(box, "Atlas Width", SIZES.map(func(v): return str(v)), 4)
	_height = _options(box, "Atlas Height", SIZES.map(func(v): return str(v)), 4)
	_charset = _options(box, "Character Set", CHARACTER_SETS, 0)
	_custom = TextEdit.new()
	_custom.custom_minimum_size = Vector2(0, 70)
	_custom.placeholder_text = "Custom range: 32-126,160-255\nUnicode hex: 20-7E,A0-FF\nCharacters: type them here\nFile: res://chars.txt"
	_custom.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_custom)
	_render_mode = _options(box, "Render Mode", RENDER_MODES, 8)
	_features = CheckBox.new()
	_features.text = "Get Font Features (kerning, ligatures)"
	_features.button_pressed = true
	box.add_child(_features)
	_multi_atlas = CheckBox.new()
	_multi_atlas.text = "Multi Atlas Textures"
	box.add_child(_multi_atlas)

	var gen := Button.new()
	gen.text = "Generate Font Atlas"
	gen.pressed.connect(generate)
	box.add_child(gen)
	var hb2 := HBoxContainer.new()
	var save := Button.new()
	save.text = "Save"
	save.size_flags_horizontal = SIZE_EXPAND_FILL
	save.pressed.connect(_save_default)
	hb2.add_child(save)
	var save_as := Button.new()
	save_as.text = "Save as…"
	save_as.size_flags_horizontal = SIZE_EXPAND_FILL
	save_as.pressed.connect(func(): _save_dialog.popup_file_dialog())
	hb2.add_child(save_as)
	box.add_child(hb2)

	_report = RichTextLabel.new()
	_report.fit_content = true
	_report.selection_enabled = true
	box.add_child(_report)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_preview.custom_minimum_size = Vector2(256, 256)
	box.add_child(_preview)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.ttf, *.otf, *.ttc, *.woff, *.woff2 ; Font files", "*.txt ; Character lists"])
	_file_dialog.file_selected.connect(_on_file)
	add_child(_file_dialog)
	_save_dialog = EditorFileDialog.new()
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.filters = PackedStringArray(["*.tres ; Typesetter font asset", "*.res ; Binary resource"])
	_save_dialog.file_selected.connect(save_to)
	add_child(_save_dialog)


func _row(parent: Control, label: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	hb.add_child(l)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(control)
	parent.add_child(hb)


func _spin(parent: Control, label: String, lo: float, hi: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = v
	_row(parent, label, s)
	return s


func _options(parent: Control, label: String, items: Array, sel: int) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	_row(parent, label, o)
	return o


## Opens the creator for a font file (FileSystem context menu).
func set_source_font(path: String) -> void:
	_font_path.text = path


func _on_file(path: String) -> void:
	if _picking == "font" and not path.ends_with(".txt"):
		_font_path.text = path
	else:
		_custom.text = path


## The characters selected by the character set options.
func get_characters() -> String:
	var s := ""
	match _charset.selected:
		0:
			for c in range(32, 127):
				s += char(c)
		1:
			for c in range(32, 127):
				s += char(c)
			for c in range(160, 256):
				s += char(c)
		2:
			for c in range(32, 65):
				s += char(c)
			for c in range(91, 127):
				s += char(c)
		3:
			for c in range(32, 97):
				s += char(c)
			for c in range(123, 127):
				s += char(c)
		4:
			for c in range(32, 65):
				s += char(c)
			for c in range(91, 97):
				s += char(c)
			for c in range(123, 127):
				s += char(c)
		5, 6:
			for part in _custom.text.replace("\n", ",").split(",", false):
				var r := part.strip_edges().split("-")
				var lo := r[0].hex_to_int() if _charset.selected == 6 else int(r[0])
				var hi := lo
				if r.size() > 1:
					hi = r[1].hex_to_int() if _charset.selected == 6 else int(r[1])
				for c in range(lo, hi + 1):
					s += char(c)
		7:
			s = _custom.text
		8:
			s = FileAccess.get_file_as_string(_custom.text.strip_edges())
		9:
			s = ""
	# Unique, in order.
	var seen := {}
	var out := ""
	for ch in s:
		if not seen.has(ch) and ch != "\n" and ch != "\r":
			seen[ch] = true
			out += ch
	return out


## Builds the asset from the current settings.
func generate() -> void:
	var ff: FontFile = load(_font_path.text) as FontFile if ResourceLoader.exists(_font_path.text) else null
	if ff == null:
		ff = FontFile.new()
		if ff.load_dynamic_font(_font_path.text) != OK:
			ff = null
	if ff == null:
		_report.text = "[color=red]Cannot load font %s[/color]" % _font_path.text
		return
	var chars := get_characters()
	var w: int = SIZES[_width.selected]
	var h: int = SIZES[_height.selected]
	var packing := _packing.selected
	var fast := packing == 5
	var t0 := Time.get_ticks_msec()
	var a := TypesetterFontAsset.create_font_asset(ff, int(_point_size.value), int(_padding.value), _render_mode.selected, w, h, TypesetterFontAsset.DYNAMIC, _multi_atlas.button_pressed)
	a.packing_mode = 0 if fast else packing
	if _auto_size.button_pressed and not chars.is_empty():
		var pt := a.find_auto_point_size(chars, fast)
		a.set_sampling_point_size(maxi(pt, 1))
	var missing := a.try_add_characters_get_missing(chars, false) if not chars.is_empty() else ""
	if _features.button_pressed:
		a.update_font_feature_table()
	if _charset.selected != 9:
		a.atlas_population_mode = TypesetterFontAsset.STATIC
	a.resource_name = _font_path.text.get_file().get_basename() + " SDF"
	TypesetterMaterialManager.get_default_material(a)
	_asset = a
	var dt := Time.get_ticks_msec() - t0
	var ft: Dictionary = a.get_font_feature_table()
	var pairs: int = ft.get("glyph_pair_adjustment_records", []).size()
	_report.text = "Point size: %d   Padding: %d   Atlas: %dx%d ×%d\nCharacters included: %d / %d   Missing: %d\nGlyph pairs: %s   Ligatures: %d   Time: %d ms\n%s" % [
		int(a.get_sampling_point_size()), int(_padding.value), w, h, a.get_atlas_texture_count(),
		chars.length() - missing.length(), chars.length(), missing.length(), str(pairs), ft.get("ligature_records", []).size(), dt,
		("[color=orange]Missing: " + missing + "[/color]") if not missing.is_empty() else ""]
	_preview.texture = a.get_atlas_texture()


func _save_default() -> void:
	if _asset == null:
		generate()
	if _asset == null:
		return
	var p := _font_path.text.get_basename() + " SDF.tres"
	save_to(p)


## Saves the generated asset (and its material inside it).
func save_to(path: String) -> void:
	if _asset == null:
		return
	var err := ResourceSaver.save(_asset, path)
	if err != OK:
		_report.text += "\n[color=red]Save failed (%d)[/color]" % err
		return
	_asset.take_over_path(path)
	_report.text += "\nSaved %s" % path
	if editor_interface:
		editor_interface.get_resource_filesystem().scan()
