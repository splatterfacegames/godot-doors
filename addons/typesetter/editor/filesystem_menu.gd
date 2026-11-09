@tool
extends EditorContextMenuPlugin
## FileSystem dock: "Create Typesetter Font Asset" on font files and
## "Create Typesetter Sprite Asset" on textures (TMP's Create menu items).

const FONT_EXT := ["ttf", "otf", "ttc", "woff", "woff2"]
const IMAGE_EXT := ["png", "svg", "webp", "jpg", "jpeg", "tga"]

var plugin: EditorPlugin


func _popup_menu(paths: PackedStringArray) -> void:
	var has_font := false
	var has_image := false
	for p in paths:
		var e := p.get_extension().to_lower()
		has_font = has_font or e in FONT_EXT
		has_image = has_image or e in IMAGE_EXT
	if has_font:
		add_context_menu_item("Create Typesetter Font Asset", _create_fonts)
		add_context_menu_item("Open in Font Asset Creator", _open_creator)
	if has_image:
		add_context_menu_item("Create Typesetter Sprite Asset", _create_sprites)


func _open_creator(paths: PackedStringArray) -> void:
	plugin.open_creator(paths[0])


func _create_fonts(paths: PackedStringArray) -> void:
	for p in paths:
		if not p.get_extension().to_lower() in FONT_EXT:
			continue
		var ff := load(p) as FontFile
		if ff == null:
			continue
		var a := TypesetterFontAsset.create_font_asset(ff)
		a.resource_name = p.get_file().get_basename() + " SDF"
		TypesetterMaterialManager.get_default_material(a)
		ResourceSaver.save(a, p.get_basename() + " SDF.tres")
	EditorInterface.get_resource_filesystem().scan()


func _create_sprites(paths: PackedStringArray) -> void:
	for p in paths:
		if not p.get_extension().to_lower() in IMAGE_EXT:
			continue
		var tex := load(p) as Texture2D
		if tex == null:
			continue
		var json_path := p.get_basename() + ".json"
		var a: TypesetterSpriteAsset
		if FileAccess.file_exists(json_path):
			a = TypesetterSpriteAsset.create_from_texture_packer_json(tex, FileAccess.get_file_as_string(json_path))
		else:
			var n := maxi(1, int(round(float(tex.get_width()) / tex.get_height())))
			a = TypesetterSpriteAsset.create_from_grid(tex, n, 1)
		a.resource_name = p.get_file().get_basename()
		ResourceSaver.save(a, p.get_basename() + ".sprites.tres")
	EditorInterface.get_resource_filesystem().scan()
