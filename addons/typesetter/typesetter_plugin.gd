@tool
extends EditorPlugin
## Typesetter editor plugin: project settings, the Font Asset Creator dock,
## font asset inspector, FileSystem context menu, TypesetterText3D gizmo and
## Project > Tools menu items.

const Creator := preload("res://addons/typesetter/editor/font_asset_creator.gd")
const FontInspector := preload("res://addons/typesetter/editor/font_asset_inspector.gd")
const TextGizmo := preload("res://addons/typesetter/editor/text_gizmo.gd")
const FsMenu := preload("res://addons/typesetter/editor/filesystem_menu.gd")

var _creator: Control
var _inspector: EditorInspectorPlugin
var _gizmo: EditorNode3DGizmoPlugin
var _fs_menu: EditorContextMenuPlugin


func _enter_tree() -> void:
	TypesetterSettings.register()
	_creator = Creator.new()
	_creator.editor_interface = EditorInterface
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _creator)
	_inspector = FontInspector.new()
	_inspector.undo_redo = get_undo_redo()
	add_inspector_plugin(_inspector)
	_gizmo = TextGizmo.new()
	_gizmo.undo_redo = get_undo_redo()
	add_node_3d_gizmo_plugin(_gizmo)
	_fs_menu = FsMenu.new()
	_fs_menu.plugin = self
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _fs_menu)
	add_tool_menu_item("Typesetter: Font Asset Creator", open_creator.bind(""))
	add_tool_menu_item("Typesetter: Create Default Style Sheet", _create_style_sheet)


func _exit_tree() -> void:
	remove_tool_menu_item("Typesetter: Font Asset Creator")
	remove_tool_menu_item("Typesetter: Create Default Style Sheet")
	remove_context_menu_plugin(_fs_menu)
	remove_node_3d_gizmo_plugin(_gizmo)
	remove_inspector_plugin(_inspector)
	remove_control_from_docks(_creator)
	_creator.queue_free()


## Shows the Font Asset Creator, optionally with a source font.
func open_creator(font_path: String) -> void:
	if not font_path.is_empty():
		_creator.set_source_font(font_path)
	var tabs := _creator.get_parent() as TabContainer
	if tabs:
		tabs.current_tab = _creator.get_index()


func _create_style_sheet() -> void:
	var dir: String = TypesetterSettings.get_value("style_sheets_resource_path")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("Default Style Sheet.tres")
	ResourceSaver.save(TypesetterStyleSheet.create_default(), path)
	if (TypesetterSettings.get_value("default_style_sheet") as String).is_empty():
		ProjectSettings.set_setting(TypesetterSettings.PREFIX + "default_style_sheet", path)
		ProjectSettings.save()
	EditorInterface.get_resource_filesystem().scan()
	print("Typesetter: wrote ", path)
