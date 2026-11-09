@tool
@icon("res://addons/typesetter/icons/typesetter_dropdown.svg")
class_name TypesetterDropdown
extends Control
## A drop-down list whose caption and items are Typesetter text (TMP_Dropdown).
##
## Click to open a list of `options`; picking one sets `value` and emits
## `value_changed`. The caption shows the selected option's text (and image,
## when `caption_image` is set). Item rows are TypesetterLabels using
## `item_font_size`, `item_color` and the caption's font.
## TMP: TMP_Dropdown

## TMP: onValueChanged
signal value_changed(index: int)

## One entry of the list (TMP_Dropdown.OptionData).
## TMP: TMP_Dropdown.OptionData
class OptionData:
	extends RefCounted
	## TMP: text
	var text: String = ""
	## TMP: image
	var image: Texture2D
	## TMP: color
	var color: Color = Color.WHITE

	func _init(t: String = "", img: Texture2D = null, c: Color = Color.WHITE) -> void:
		text = t
		image = img
		color = c

## Option texts as edited in the inspector (images are set from code).
@export var option_texts: PackedStringArray = PackedStringArray(["Option A", "Option B", "Option C"]):
	set(v):
		option_texts = v
		options.clear()
		for t in v:
			options.append(OptionData.new(t))
		refresh_shown_value()
## Selected index.
## TMP: value
@export var value: int = 0:
	set(v):
		_set_value(v, true)
	get:
		return _value
## Text shown on the closed drop-down. Created automatically when empty.
## TMP: captionText
@export var caption_text: TypesetterLabel
## Image shown on the closed drop-down (optional).
## TMP: captionImage
@export var caption_image: TextureRect
## Shown when no option is selected (value = -1).
## TMP: placeholder
@export var placeholder: Control
## Font size of the list items.
## TMP: itemText (font size of the item template)
@export var item_font_size: float = 14.0
## Text colour of the list items.
@export var item_color: Color = Color(0.2, 0.2, 0.2)
## Height of a list row in pixels.
@export var item_height: float = 24.0
## Fade-in time of the list, seconds.
## TMP: alphaFadeSpeed
@export var alpha_fade_speed: float = 0.15
## Accepts input (Selectable.interactable).
## TMP: interactable
@export var interactable: bool = true

## The list entries. TMP: options
var options: Array[OptionData] = []
## True while the list is open. TMP: IsExpanded
var is_expanded: bool:
	get:
		return _popup != null and _popup.visible

var _value := 0
var _popup: PopupPanel


func _init() -> void:
	focus_mode = FOCUS_ALL
	size = Vector2(160, 30)
	for t in option_texts:
		options.append(OptionData.new(t))


func _ready() -> void:
	if caption_text == null:
		var l := TypesetterLabel.new()
		l.name = "Label"
		l.font_size = 14
		l.color = Color(0.2, 0.2, 0.2)
		l.vertical_alignment = TypesetterLabel.VerticalAlignmentOptions.MIDDLE
		l.raycast_target = false
		add_child(l, false, INTERNAL_MODE_FRONT)
		caption_text = l
	_layout()
	refresh_shown_value()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _layout() -> void:
	if caption_text and caption_text.get_parent() == self:
		var left := 10.0
		if caption_image and caption_image.visible:
			caption_image.position = Vector2(6, 4)
			caption_image.size = Vector2(size.y - 8, size.y - 8)
			left = size.y + 2
		caption_text.position = Vector2(left, 0)
		caption_text.size = Vector2(size.x - left - 26, size.y)


func _draw() -> void:
	var sb := get_theme_stylebox("normal", "OptionButton")
	if has_focus():
		sb = get_theme_stylebox("focus", "OptionButton")
		draw_style_box(get_theme_stylebox("normal", "OptionButton"), Rect2(Vector2.ZERO, size))
	if sb:
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var arrow := get_theme_icon("arrow", "OptionButton")
	if arrow:
		draw_texture(arrow, Vector2(size.x - arrow.get_width() - 8, (size.y - arrow.get_height()) * 0.5))


func _gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_list()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		show_list()
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_set_value(maxi(_value - 1, 0), true)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_set_value(mini(_value + 1, options.size() - 1), true)
		accept_event()


## Adds options from strings, textures or OptionData. TMP: AddOptions
func add_options(list: Array) -> void:
	for o in list:
		if o is OptionData:
			options.append(o)
		elif o is Texture2D:
			options.append(OptionData.new("", o))
		else:
			options.append(OptionData.new(str(o)))
	refresh_shown_value()


## TMP: ClearOptions
func clear_options() -> void:
	options.clear()
	_value = 0
	refresh_shown_value()


## Updates the caption from the selected option. TMP: RefreshShownValue
func refresh_shown_value() -> void:
	if caption_text == null:
		return
	var has := _value >= 0 and _value < options.size()
	caption_text.text = options[_value].text if has else ""
	if caption_image:
		caption_image.texture = options[_value].image if has else null
		caption_image.visible = caption_image.texture != null
	if placeholder:
		placeholder.visible = not has
	_layout()


## TMP: SetValueWithoutNotify
func set_value_without_notify(index: int) -> void:
	_set_value(index, false)


func _set_value(index: int, notify: bool) -> void:
	var v := clampi(index, -1, options.size() - 1) if not options.is_empty() else index
	if v == _value:
		return
	_value = v
	refresh_shown_value()
	if notify:
		value_changed.emit(_value)


## Opens the list. TMP: Show
func show_list() -> void:
	if options.is_empty():
		return
	hide_list()
	_popup = PopupPanel.new()
	_popup.transparent_bg = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_popup.add_child(scroll)
	for i in options.size():
		var o := options[i]
		var row := Button.new()
		row.flat = true
		row.toggle_mode = true
		row.button_pressed = i == _value
		row.custom_minimum_size = Vector2(0, item_height)
		row.focus_mode = Control.FOCUS_ALL
		var x := 22.0
		if o.image:
			var img := TextureRect.new()
			img.texture = o.image
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.position = Vector2(x, 2)
			img.size = Vector2(item_height - 4, item_height - 4)
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(img)
			x += item_height
		var l := TypesetterLabel.new()
		l.text = o.text
		l.font = caption_text.font if caption_text else null
		l.font_size = item_font_size
		l.color = item_color * o.color
		l.vertical_alignment = TypesetterLabel.VerticalAlignmentOptions.MIDDLE
		l.text_wrapping_mode = TypesetterLabel.TextWrappingModes.NO_WRAP
		l.raycast_target = false
		l.position = Vector2(x, 0)
		l.size = Vector2(size.x - x - 8, item_height)
		row.add_child(l)
		if i == _value:
			var check := TypesetterLabel.new()
			check.text = "✓"
			check.font_size = item_font_size
			check.color = item_color
			check.vertical_alignment = TypesetterLabel.VerticalAlignmentOptions.MIDDLE
			check.raycast_target = false
			check.position = Vector2(6, 0)
			check.size = Vector2(16, item_height)
			row.add_child(check)
		row.pressed.connect(_on_item.bind(i))
		box.add_child(row)
	add_child(_popup, false, INTERNAL_MODE_BACK)
	var h := minf(options.size() * item_height + 8.0, 200.0)
	var r := Rect2i(Vector2i(get_screen_position() + Vector2(0, size.y)), Vector2i(int(size.x), int(h)))
	scroll.custom_minimum_size = Vector2(size.x - 8, h - 8)
	_popup.popup(r)
	if alpha_fade_speed > 0.0:
		_popup.modulate.a = 0.0
		create_tween().tween_property(_popup, "modulate:a", 1.0, alpha_fade_speed)
	_popup.popup_hide.connect(_on_popup_hide)


func _on_popup_hide() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null


## Closes the list. TMP: Hide
func hide_list() -> void:
	if _popup:
		_popup.hide()
		_popup.queue_free()
		_popup = null


func _on_item(i: int) -> void:
	_set_value(i, true)
	hide_list()
	grab_focus()
