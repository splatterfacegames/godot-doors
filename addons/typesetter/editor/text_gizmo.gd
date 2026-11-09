@tool
extends EditorNode3DGizmoPlugin
## Draws TypesetterText3D's container rectangle (and margins) with resize
## handles: TMP's RectTransform gizmo for TextMeshPro.

var undo_redo: EditorUndoRedoManager


func _init() -> void:
	create_material("rect", Color(1.0, 0.85, 0.2, 0.9))
	create_material("margin", Color(1.0, 1.0, 1.0, 0.4))
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "TypesetterText3D"


func _has_gizmo(node: Node3D) -> bool:
	return node is TypesetterText3D


static func _box(lo: Vector2, hi: Vector2) -> PackedVector3Array:
	var a := Vector3(lo.x, lo.y, 0)
	var b := Vector3(hi.x, lo.y, 0)
	var c := Vector3(hi.x, hi.y, 0)
	var d := Vector3(lo.x, hi.y, 0)
	return PackedVector3Array([a, b, b, c, c, d, d, a])


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var t := gizmo.get_node_3d() as TypesetterText3D
	var lo := -t.rect_size * t.pivot
	var hi := lo + t.rect_size
	gizmo.add_lines(_box(lo, hi), get_material("rect", gizmo))
	var m := t.margin
	if m != Vector4.ZERO:
		gizmo.add_lines(_box(lo + Vector2(m.x, m.w), hi - Vector2(m.z, m.y)), get_material("margin", gizmo))
	# Handles: right edge (0) and top edge (1).
	gizmo.add_handles(PackedVector3Array([Vector3(hi.x, (lo.y + hi.y) * 0.5, 0), Vector3((lo.x + hi.x) * 0.5, hi.y, 0)]), get_material("handles", gizmo), [])


func _get_handle_name(_gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return "Width" if id == 0 else "Height"


func _get_handle_value(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d() as TypesetterText3D).rect_size


func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var t := gizmo.get_node_3d() as TypesetterText3D
	var p = TypesetterTextUtilities.screen_point_to_local(t, screen_pos, camera)
	if p == null:
		return
	# The pivot stays put: the dragged edge sits at size × (1 − pivot).
	var s := t.rect_size
	if id == 0 and t.pivot.x < 1.0:
		s.x = maxf(0.01, p.x / (1.0 - t.pivot.x))
	elif id == 1 and t.pivot.y < 1.0:
		s.y = maxf(0.01, p.y / (1.0 - t.pivot.y))
	t.rect_size = s


func _commit_handle(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var t := gizmo.get_node_3d() as TypesetterText3D
	if cancel:
		t.rect_size = restore
		return
	undo_redo.create_action("Resize Typesetter Text")
	undo_redo.add_do_property(t, &"rect_size", t.rect_size)
	undo_redo.add_undo_property(t, &"rect_size", restore)
	undo_redo.commit_action()
