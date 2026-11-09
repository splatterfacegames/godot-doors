@tool
@icon("res://addons/typesetter/icons/typesetter_input_field.svg")
class_name TypesetterInputField
extends Control
## An editable text field drawn with Typesetter text (TMP_InputField).
##
## The field shows `text` through `text_component` (a TypesetterLabel) inside
## `text_viewport`, which clips and scrolls it, with `placeholder` shown while
## the field is empty. Missing parts are created automatically. Supports
## selection with mouse and keyboard, clipboard, content types and validation,
## single and multi-line editing, password masking, IME composition and the
## virtual keyboard.
## TMP: TMP_InputField

## TMP: onValueChanged
signal value_changed(text: String)
## TMP: onEndEdit
signal end_edit(text: String)
## TMP: onSubmit
signal submit(text: String)
## TMP: onSelect
signal select(text: String)
## TMP: onDeselect
signal deselect(text: String)
## TMP: onTextSelection
signal text_selection(text: String, string_position: int, string_select_position: int)
## TMP: onEndTextSelection
signal end_text_selection(text: String, string_position: int, string_select_position: int)
## TMP: onTouchScreenKeyboardStatusChanged
signal touch_screen_keyboard_status_changed(status: int)

## TMP: TMP_InputField.ContentType
enum ContentType { STANDARD, AUTOCORRECTED, INTEGER_NUMBER, DECIMAL_NUMBER, ALPHANUMERIC, NAME, EMAIL_ADDRESS, PASSWORD, PIN, CUSTOM }
## TMP: TMP_InputField.InputType
enum InputType { STANDARD, AUTO_CORRECT, PASSWORD }
## TMP: TMP_InputField.CharacterValidation
enum CharacterValidation { NONE, DIGIT, INTEGER, DECIMAL, ALPHANUMERIC, NAME, REGEX, EMAIL_ADDRESS, CUSTOM_VALIDATOR }
## TMP: TMP_InputField.LineType
enum LineType { SINGLE_LINE, MULTI_LINE_SUBMIT, MULTI_LINE_NEWLINE }
## TMP: TouchScreenKeyboardType
enum KeyboardType { DEFAULT, ASCII_CAPABLE, NUMBERS_AND_PUNCTUATION, URL, NUMBER_PAD, PHONE_PAD, NAME_PHONE_PAD, EMAIL_ADDRESS, SOCIAL, SEARCH, DECIMAL_PAD, ONE_TIME_CODE }
## TMP: TouchScreenKeyboard.Status
enum KeyboardStatus { VISIBLE, DONE, CANCELED, LOST_FOCUS }

## The text being edited.
## TMP: text
@export_multiline var text: String = "":
	set(v):
		_set_text(v, true)
	get:
		return _text

@export_group("Components")
## Clips and scrolls the text. Created automatically when empty.
## TMP: textViewport
@export var text_viewport: Control:
	set(v):
		text_viewport = v
		_layout_children()
## The label showing the text. Created automatically when empty.
## TMP: textComponent
@export var text_component: TypesetterLabel:
	set(v):
		text_component = v
		_refresh()
## Shown while the field is empty (any Control; a TypesetterLabel by default).
## TMP: placeholder
@export var placeholder: Control:
	set(v):
		placeholder = v
		_refresh()
## Optional scrollbar for multi-line fields.
## TMP: verticalScrollbar
@export var vertical_scrollbar: ScrollBar:
	set(v):
		if vertical_scrollbar and vertical_scrollbar.value_changed.is_connected(_on_scrollbar):
			vertical_scrollbar.value_changed.disconnect(_on_scrollbar)
		vertical_scrollbar = v
		if v:
			v.value_changed.connect(_on_scrollbar)
## TMP: scrollSensitivity
@export var scroll_sensitivity: float = 1.0

@export_group("Caret and Selection")
## Blinks per second (0: no blinking).
## TMP: caretBlinkRate
@export_range(0.0, 4.0, 0.01) var caret_blink_rate: float = 0.85
## TMP: caretWidth
@export_range(1, 5, 1) var caret_width: int = 1
## TMP: customCaretColor
@export var custom_caret_color: bool = false
## TMP: caretColor
@export var caret_color: Color = Color(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0)
## TMP: selectionColor
@export var selection_color: Color = Color(168.0 / 255.0, 206.0 / 255.0, 1.0, 192.0 / 255.0)

@export_group("Text")
## Font asset applied to the text component and placeholder (null keeps theirs).
## TMP: fontAsset
@export var font_asset: TypesetterFontAsset:
	set(v):
		font_asset = v
		set_global_font_asset(v)
## Point size applied to the text component and placeholder (0 keeps theirs).
## TMP: pointSize
@export var point_size: float = 0.0:
	set(v):
		point_size = v
		set_global_point_size(v)

@export_group("Behaviour")
## TMP: contentType
@export var content_type: ContentType = ContentType.STANDARD:
	set(v):
		content_type = v
		_enforce_content_type()
## TMP: lineType
@export var line_type: LineType = LineType.SINGLE_LINE:
	set(v):
		line_type = v
		if content_type != ContentType.STANDARD and content_type != ContentType.AUTOCORRECTED and v != LineType.SINGLE_LINE:
			content_type = ContentType.CUSTOM
		_refresh()
## Maximum number of lines (0: unlimited).
## TMP: lineLimit
@export var line_limit: int = 0
## TMP: inputType
@export var input_type: InputType = InputType.STANDARD:
	set(v):
		input_type = v
		_refresh()
## Virtual keyboard layout.
## TMP: keyboardType
@export var keyboard_type: KeyboardType = KeyboardType.DEFAULT
## TMP: characterValidation
@export var character_validation: CharacterValidation = CharacterValidation.NONE
## Used with CUSTOM_VALIDATOR.
## TMP: inputValidator
@export var input_validator: TypesetterInputValidator
## Pattern each character must match with REGEX validation.
## TMP: regexValue
@export var regex_value: String = ""
## Maximum number of characters (0: unlimited).
## TMP: characterLimit
@export var character_limit: int = 0
## Character shown for each character of a password.
## TMP: asteriskChar
@export var asterisk_char: String = "*"
## TMP: readOnly
@export var read_only: bool = false
## Parses rich text tags in the text component.
## TMP: richText
@export var rich_text: bool = true:
	set(v):
		rich_text = v
		_refresh()
## Shows tags as typed instead of parsing them.
## TMP: isRichTextEditingAllowed
@export var is_rich_text_editing_allowed: bool = false:
	set(v):
		is_rich_text_editing_allowed = v
		_refresh()
## TMP: onFocusSelectAll
@export var on_focus_select_all: bool = true
## TMP: resetOnDeActivation
@export var reset_on_de_activation: bool = true
## TMP: keepTextSelectionVisible
@export var keep_text_selection_visible: bool = false
## TMP: restoreOriginalTextOnEscape
@export var restore_original_text_on_escape: bool = true
## TMP: shouldHideMobileInput
@export var should_hide_mobile_input: bool = false
## TMP: shouldHideSoftKeyboard
@export var should_hide_soft_keyboard: bool = false
## TMP: shouldActivateOnSelect
@export var should_activate_on_select: bool = true
## Accepts input (Selectable.interactable).
## TMP: interactable
@export var interactable: bool = true:
	set(v):
		interactable = v
		focus_mode = FOCUS_ALL if v else FOCUS_NONE
		queue_redraw()

## Optional `func(text: String, char_index: int, added_char: String) -> String`
## that validates each character; return "" to reject.
## TMP: onValidateInput
var on_validate_input: Callable

## True for MULTI_LINE_* line types. TMP: multiLine
var multi_line: bool:
	get:
		return line_type != LineType.SINGLE_LINE
## True when editing ended with Escape. TMP: wasCanceled
var was_canceled: bool = false
## TMP: isFocused
var is_focused: bool:
	get:
		return has_focus()

## Caret index in the text (string position). TMP: stringPosition
var string_position: int:
	get:
		return _focus
	set(v):
		_focus = clampi(v, 0, _text.length())
		_anchor = _focus
		_caret_moved()
## TMP: selectionStringAnchorPosition
var selection_string_anchor_position: int:
	get:
		return _anchor
	set(v):
		_anchor = clampi(v, 0, _text.length())
		_caret_moved()
## TMP: selectionStringFocusPosition
var selection_string_focus_position: int:
	get:
		return _focus
	set(v):
		_focus = clampi(v, 0, _text.length())
		_caret_moved()
## Caret index among the displayed characters. TMP: caretPosition
var caret_position: int:
	get:
		return _string_to_char(_focus)
	set(v):
		string_position = _char_to_string(v)
## TMP: selectionAnchorPosition
var selection_anchor_position: int:
	get:
		return _string_to_char(_anchor)
	set(v):
		selection_string_anchor_position = _char_to_string(v)
## TMP: selectionFocusPosition
var selection_focus_position: int:
	get:
		return _string_to_char(_focus)
	set(v):
		selection_string_focus_position = _char_to_string(v)

var _text := ""
var _anchor := 0
var _focus := 0
var _original := ""
var _blink := 0.0
var _caret_visible := true
var _scroll := Vector2.ZERO
var _overlay: Control
var _dragging := false
var _ime_text := ""
var _ime_sel := Vector2i.ZERO
var _undo: Array = []
var _redo: Array = []
var _last_click_ms := 0
var _click_count := 0


func _init() -> void:
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_IBEAM
	clip_contents = true
	size = Vector2(160, 30)


func _ready() -> void:
	_ensure_children()
	_refresh()
	set_process(false)


func _ensure_children() -> void:
	if text_viewport == null:
		var vp := Control.new()
		vp.name = "Text Area"
		vp.clip_contents = true
		vp.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(vp, false, INTERNAL_MODE_FRONT)
		text_viewport = vp
	if placeholder == null:
		var ph := TypesetterLabel.new()
		ph.name = "Placeholder"
		ph.text = "Enter text..."
		ph.font_style = TypesetterLabel.FontStyles.ITALIC
		ph.color = Color(0.2, 0.2, 0.2, 0.5)
		ph.font_size = 14
		ph.raycast_target = false
		text_viewport.add_child(ph, false, INTERNAL_MODE_FRONT)
		placeholder = ph
	if text_component == null:
		var tc := TypesetterLabel.new()
		tc.name = "Text"
		tc.color = Color(0.2, 0.2, 0.2)
		tc.font_size = 14
		tc.raycast_target = false
		text_viewport.add_child(tc, false, INTERNAL_MODE_FRONT)
		text_component = tc
	if _overlay == null:
		_overlay = Control.new()
		_overlay.name = "Caret"
		_overlay.mouse_filter = MOUSE_FILTER_IGNORE
		_overlay.draw.connect(_draw_caret)
		text_viewport.add_child(_overlay, false, INTERNAL_MODE_BACK)
	_layout_children()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout_children()
		NOTIFICATION_FOCUS_ENTER:
			activate_input_field()
		NOTIFICATION_FOCUS_EXIT:
			deactivate_input_field(false)
		NOTIFICATION_OS_IME_UPDATE:
			if has_focus():
				_ime_text = DisplayServer.ime_get_text()
				_ime_sel = DisplayServer.ime_get_selection()
				_refresh()
		NOTIFICATION_THEME_CHANGED:
			queue_redraw()


func _draw() -> void:
	var sb_name := "focus" if has_focus() else ("read_only" if read_only or not interactable else "normal")
	var sb := get_theme_stylebox(sb_name, "LineEdit")
	if sb_name == "focus":
		draw_style_box(get_theme_stylebox("normal", "LineEdit"), Rect2(Vector2.ZERO, size))
	if sb:
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _layout_children() -> void:
	if text_viewport == null:
		return
	var sb := get_theme_stylebox("normal", "LineEdit") if is_inside_tree() else null
	var m := Vector4(10, 6, 10, 7)
	if sb:
		m = Vector4(maxf(sb.content_margin_left, 4), maxf(sb.content_margin_top, 2), maxf(sb.content_margin_right, 4), maxf(sb.content_margin_bottom, 2))
	if text_viewport.get_parent() == self:
		text_viewport.position = Vector2(m.x, m.y)
		text_viewport.size = size - Vector2(m.x + m.z, m.y + m.w)
	if placeholder:
		placeholder.position = Vector2.ZERO
		placeholder.size = text_viewport.size
	if _overlay:
		_overlay.position = Vector2.ZERO
		_overlay.size = text_viewport.size
	_refresh()


# ------------------------------------------------------------------ public API

## Gives the field focus and starts editing. TMP: ActivateInputField
func activate_input_field() -> void:
	if not interactable:
		return
	if not has_focus():
		grab_focus()
		return
	_original = _text
	was_canceled = false
	if on_focus_select_all:
		select_all()
	else:
		_caret_moved()
	set_process(true)
	if not should_hide_soft_keyboard and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var vk_type := _virtual_keyboard_type()
		DisplayServer.virtual_keyboard_show(_text, get_global_rect(), vk_type, character_limit if character_limit > 0 else -1, _anchor, _focus)
		touch_screen_keyboard_status_changed.emit(KeyboardStatus.VISIBLE)
	DisplayServer.window_set_ime_active(true)
	select.emit(_text)


## Stops editing. TMP: DeactivateInputField(bool clearSelection)
func deactivate_input_field(clear_selection: bool = false) -> void:
	set_process(false)
	_caret_visible = false
	DisplayServer.window_set_ime_active(false)
	_ime_text = ""
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
		touch_screen_keyboard_status_changed.emit(KeyboardStatus.CANCELED if was_canceled else KeyboardStatus.DONE)
	if clear_selection or reset_on_de_activation:
		_anchor = _focus
	if has_focus():
		release_focus()
	end_edit.emit(_text)
	deselect.emit(_text)
	_refresh()


## Selects the field (focus without necessarily editing). TMP: Select
func select_field() -> void:
	if should_activate_on_select:
		activate_input_field()
	else:
		grab_focus()


## Sets the text without emitting value_changed. TMP: SetTextWithoutNotify
func set_text_without_notify(value: String) -> void:
	_set_text(value, false)


## TMP: MoveTextStart(bool shift)
func move_text_start(shift: bool) -> void:
	_move_to(0, shift)


## TMP: MoveTextEnd(bool shift)
func move_text_end(shift: bool) -> void:
	_move_to(_text.length(), shift)


## TMP: MoveToStartOfLine(bool shift, bool ctrl)
func move_to_start_of_line(shift: bool, ctrl: bool) -> void:
	if ctrl:
		move_text_start(shift)
		return
	var li := _line_of(_focus)
	_move_to(_line_start(li), shift)


## TMP: MoveToEndOfLine(bool shift, bool ctrl)
func move_to_end_of_line(shift: bool, ctrl: bool) -> void:
	if ctrl:
		move_text_end(shift)
		return
	var li := _line_of(_focus)
	_move_to(_line_end(li), shift)


## Selects all text.
func select_all() -> void:
	_anchor = 0
	_focus = _text.length()
	_caret_moved()


## TMP: ReleaseSelection
func release_selection() -> void:
	_anchor = _focus
	_caret_moved()


## Applies a point size to the text component and placeholder. TMP: SetGlobalPointSize
func set_global_point_size(size_pt: float) -> void:
	if size_pt <= 0.0:
		return
	if text_component:
		text_component.font_size = size_pt
	if placeholder is TypesetterLabel:
		placeholder.font_size = size_pt
	_refresh()


## Applies a font asset to the text component and placeholder. TMP: SetGlobalFontAsset
func set_global_font_asset(asset: TypesetterFontAsset) -> void:
	if asset == null:
		return
	if text_component:
		text_component.font = asset
	if placeholder is TypesetterLabel:
		placeholder.font = asset
	_refresh()


## Updates the displayed text and caret now. TMP: ForceLabelUpdate
func force_label_update() -> void:
	_refresh()
	if text_component:
		text_component.force_mesh_update(true)


## TMP: Rebuild
func rebuild(_update: int = 0) -> void:
	force_label_update()


## The selected text.
func get_selected_text() -> String:
	return _text.substr(mini(_anchor, _focus), absi(_focus - _anchor))


## Handles an input event as if it were typed into the field. TMP: ProcessEvent
func process_event(event: InputEvent) -> void:
	_gui_input(event)


# ------------------------------------------------------------------ editing

func _set_text(value: String, notify: bool) -> void:
	var v := value
	if character_limit > 0 and v.length() > character_limit:
		v = v.substr(0, character_limit)
	if not multi_line:
		v = v.replace("\n", "").replace("\r", "")
	if v == _text:
		return
	_text = v
	_anchor = mini(_anchor, _text.length())
	_focus = mini(_focus, _text.length())
	_refresh()
	if notify:
		value_changed.emit(_text)


func _push_undo() -> void:
	_undo.append([_text, _anchor, _focus])
	if _undo.size() > 100:
		_undo.pop_front()
	_redo.clear()


func _insert(s: String) -> void:
	if read_only or s.is_empty():
		return
	var lo := mini(_anchor, _focus)
	var hi := maxi(_anchor, _focus)
	var accepted := ""
	var base := _text.substr(0, lo) + _text.substr(hi)
	var pos := lo
	for ch in s:
		var c := _validate(base.substr(0, pos) + accepted + base.substr(pos), pos + accepted.length(), ch)
		if c.is_empty():
			continue
		accepted += c
	if accepted.is_empty() and lo == hi:
		return
	var new_text := base.substr(0, pos) + accepted + base.substr(pos)
	if character_limit > 0 and new_text.length() > character_limit:
		var room := character_limit - base.length()
		if room <= 0:
			return
		accepted = accepted.substr(0, room)
		new_text = base.substr(0, pos) + accepted + base.substr(pos)
	if line_limit > 0 and multi_line and new_text.count("\n") + 1 > line_limit:
		return
	_push_undo()
	_text = new_text
	_anchor = pos + accepted.length()
	_focus = _anchor
	_refresh()
	value_changed.emit(_text)


func _delete_range(lo: int, hi: int) -> void:
	if read_only or lo >= hi:
		return
	_push_undo()
	_text = _text.substr(0, lo) + _text.substr(hi)
	_anchor = lo
	_focus = lo
	_refresh()
	value_changed.emit(_text)


func _validate(current: String, pos: int, ch: String) -> String:
	if on_validate_input.is_valid():
		return on_validate_input.call(current, pos, ch)
	if ch == "\n" or ch == "\r":
		return ch if multi_line and line_type == LineType.MULTI_LINE_NEWLINE else ""
	var is_digit := ch >= "0" and ch <= "9"
	var is_letter := ch.to_upper() != ch.to_lower()
	match character_validation:
		CharacterValidation.DIGIT:
			return ch if is_digit else ""
		CharacterValidation.INTEGER:
			if is_digit:
				return ch if not (pos == 0 and current.begins_with("-")) else ""
			if ch == "-" and pos == 0 and not current.begins_with("-"):
				return ch
			return ""
		CharacterValidation.DECIMAL:
			if is_digit:
				return ch if not (pos == 0 and current.begins_with("-")) else ""
			if ch == "-" and pos == 0 and not current.begins_with("-"):
				return ch
			if (ch == "." or ch == ",") and not current.contains(".") and not current.contains(","):
				return ch
			return ""
		CharacterValidation.ALPHANUMERIC:
			return ch if is_digit or is_letter else ""
		CharacterValidation.NAME:
			if is_letter:
				var prev := current.substr(pos - 1, 1) if pos > 0 else " "
				if prev == " " or prev == "-":
					return ch.to_upper()
				return ch.to_lower() if prev != "'" else ch
			if ch == " " or ch == "-" or ch == "'":
				var prev2 := current.substr(pos - 1, 1) if pos > 0 else ""
				return ch if pos > 0 and prev2 != " " and prev2 != "-" and prev2 != "'" else ""
			return ""
		CharacterValidation.EMAIL_ADDRESS:
			if is_digit or is_letter:
				return ch
			if ch == "@":
				return ch if not current.contains("@") and pos > 0 else ""
			if "!#$%&'*+-/=?^_`{|}~".contains(ch):
				return ch
			if ch == ".":
				var prev3 := current.substr(pos - 1, 1) if pos > 0 else ""
				var next3 := current.substr(pos, 1)
				return ch if pos > 0 and prev3 != "." and next3 != "." else ""
			return ""
		CharacterValidation.REGEX:
			var re := RegEx.create_from_string(regex_value)
			return ch if re != null and re.is_valid() and re.search(ch) != null else ""
		CharacterValidation.CUSTOM_VALIDATOR:
			return input_validator.validate(current, pos, ch) if input_validator else ch
	return ch


func _enforce_content_type() -> void:
	match content_type:
		ContentType.STANDARD:
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.NONE
			keyboard_type = KeyboardType.DEFAULT
		ContentType.AUTOCORRECTED:
			input_type = InputType.AUTO_CORRECT
			character_validation = CharacterValidation.NONE
			keyboard_type = KeyboardType.DEFAULT
		ContentType.INTEGER_NUMBER:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.INTEGER
			keyboard_type = KeyboardType.NUMBER_PAD
		ContentType.DECIMAL_NUMBER:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.DECIMAL
			keyboard_type = KeyboardType.DECIMAL_PAD
		ContentType.ALPHANUMERIC:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.ALPHANUMERIC
			keyboard_type = KeyboardType.ASCII_CAPABLE
		ContentType.NAME:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.NAME
			keyboard_type = KeyboardType.NAME_PHONE_PAD
		ContentType.EMAIL_ADDRESS:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.STANDARD
			character_validation = CharacterValidation.EMAIL_ADDRESS
			keyboard_type = KeyboardType.EMAIL_ADDRESS
		ContentType.PASSWORD:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.PASSWORD
			character_validation = CharacterValidation.NONE
			keyboard_type = KeyboardType.DEFAULT
		ContentType.PIN:
			line_type = LineType.SINGLE_LINE
			input_type = InputType.PASSWORD
			character_validation = CharacterValidation.DIGIT
			keyboard_type = KeyboardType.NUMBER_PAD
	_refresh()


func _virtual_keyboard_type() -> DisplayServer.VirtualKeyboardType:
	match keyboard_type:
		KeyboardType.NUMBER_PAD, KeyboardType.NUMBERS_AND_PUNCTUATION:
			return DisplayServer.KEYBOARD_TYPE_NUMBER
		KeyboardType.DECIMAL_PAD:
			return DisplayServer.KEYBOARD_TYPE_NUMBER_DECIMAL
		KeyboardType.PHONE_PAD, KeyboardType.NAME_PHONE_PAD:
			return DisplayServer.KEYBOARD_TYPE_PHONE
		KeyboardType.EMAIL_ADDRESS:
			return DisplayServer.KEYBOARD_TYPE_EMAIL_ADDRESS
		KeyboardType.URL:
			return DisplayServer.KEYBOARD_TYPE_URL
	if input_type == InputType.PASSWORD:
		return DisplayServer.KEYBOARD_TYPE_PASSWORD
	return DisplayServer.KEYBOARD_TYPE_MULTILINE if multi_line else DisplayServer.KEYBOARD_TYPE_DEFAULT


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		_focus = _pos_at(text_component.get_local_mouse_position())
		_caret_moved()
		text_selection.emit(_text, _focus, _anchor)
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		if _key(event):
			accept_event()


func _mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if multi_line and e.pressed:
			var d := -1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			_scroll.y = clampf(_scroll.y + d * scroll_sensitivity * text_component.font_size, 0.0, _max_scroll().y)
			_apply_scroll()
			accept_event()
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		if not has_focus():
			grab_focus()
		var now := Time.get_ticks_msec()
		_click_count = _click_count + 1 if now - _last_click_ms < 400 else 1
		_last_click_ms = now
		var p := _pos_at(text_component.get_local_mouse_position())
		if _click_count == 2:
			_select_word_at(p)
		elif _click_count >= 3:
			var li := _line_of(p)
			_anchor = _line_start(li)
			_focus = _line_end(li)
			_caret_moved()
		else:
			_focus = p
			if not e.shift_pressed:
				_anchor = p
			_caret_moved()
			_dragging = true
		accept_event()
	else:
		if _dragging and _anchor != _focus:
			end_text_selection.emit(_text, _focus, _anchor)
		_dragging = false


func _key(e: InputEventKey) -> bool:
	var ctrl := e.is_command_or_control_pressed()
	var shift := e.shift_pressed
	var word := ctrl or e.alt_pressed
	match e.keycode:
		KEY_LEFT:
			if _anchor != _focus and not shift:
				_move_to(mini(_anchor, _focus), false)
			else:
				_move_to(_prev_word(_focus) if word else _prev_pos(_focus), shift)
			return true
		KEY_RIGHT:
			if _anchor != _focus and not shift:
				_move_to(maxi(_anchor, _focus), false)
			else:
				_move_to(_next_word(_focus) if word else _next_pos(_focus), shift)
			return true
		KEY_UP:
			if multi_line:
				_move_vertical(-1, shift)
				return true
			move_text_start(shift)
			return true
		KEY_DOWN:
			if multi_line:
				_move_vertical(1, shift)
				return true
			move_text_end(shift)
			return true
		KEY_HOME:
			move_to_start_of_line(shift, ctrl)
			return true
		KEY_END:
			move_to_end_of_line(shift, ctrl)
			return true
		KEY_PAGEUP:
			_move_vertical(-maxi(1, _visible_lines()), shift)
			return true
		KEY_PAGEDOWN:
			_move_vertical(maxi(1, _visible_lines()), shift)
			return true
		KEY_BACKSPACE:
			if _anchor != _focus:
				_delete_range(mini(_anchor, _focus), maxi(_anchor, _focus))
			elif _focus > 0:
				_delete_range(_prev_word(_focus) if word else _prev_pos(_focus), _focus)
			return true
		KEY_DELETE:
			if _anchor != _focus:
				_delete_range(mini(_anchor, _focus), maxi(_anchor, _focus))
			elif _focus < _text.length():
				_delete_range(_focus, _next_word(_focus) if word else _next_pos(_focus))
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if line_type == LineType.MULTI_LINE_NEWLINE and not ctrl:
				_insert("\n")
			else:
				submit.emit(_text)
				deactivate_input_field(false)
			return true
		KEY_ESCAPE:
			was_canceled = true
			if restore_original_text_on_escape and _text != _original:
				_set_text(_original, true)
			deactivate_input_field(false)
			return true
		KEY_TAB:
			return false
	if ctrl:
		match e.keycode:
			KEY_A:
				select_all()
				return true
			KEY_C:
				if input_type != InputType.PASSWORD and _anchor != _focus:
					DisplayServer.clipboard_set(get_selected_text())
				return true
			KEY_X:
				if input_type != InputType.PASSWORD and _anchor != _focus:
					DisplayServer.clipboard_set(get_selected_text())
					_delete_range(mini(_anchor, _focus), maxi(_anchor, _focus))
				return true
			KEY_V:
				var clip := DisplayServer.clipboard_get()
				if not multi_line:
					clip = clip.replace("\r", "").replace("\n", "")
				_insert(clip.replace("\r\n", "\n"))
				return true
			KEY_Z:
				if shift:
					_redo_step()
				else:
					_undo_step()
				return true
			KEY_Y:
				_redo_step()
				return true
		return false
	if e.unicode >= 32 and e.unicode != 127:
		_insert(char(e.unicode))
		return true
	return false


func _undo_step() -> void:
	if _undo.is_empty() or read_only:
		return
	_redo.append([_text, _anchor, _focus])
	var s: Array = _undo.pop_back()
	_text = s[0]
	_anchor = s[1]
	_focus = s[2]
	_refresh()
	value_changed.emit(_text)


func _redo_step() -> void:
	if _redo.is_empty() or read_only:
		return
	_undo.append([_text, _anchor, _focus])
	var s: Array = _redo.pop_back()
	_text = s[0]
	_anchor = s[1]
	_focus = s[2]
	_refresh()
	value_changed.emit(_text)


# ------------------------------------------------------------------ positions

func _move_to(p: int, shift: bool) -> void:
	_focus = clampi(p, 0, _text.length())
	if not shift:
		_anchor = _focus
	_caret_moved()
	if shift:
		text_selection.emit(_text, _focus, _anchor)


func _prev_pos(p: int) -> int:
	var q := p - 1
	# Skip over hidden tag characters when tags are parsed.
	while q > 0 and _hidden(q):
		q -= 1
	return maxi(q, 0)


func _next_pos(p: int) -> int:
	var q := p + 1
	while q < _text.length() and _hidden(q - 1):
		q += 1
	return mini(q, _text.length())


func _hidden(string_index: int) -> bool:
	if not (rich_text and not is_rich_text_editing_allowed) or text_component == null:
		return false
	return not _visible_indices().has(string_index)


var _visible_cache := {}
var _visible_cache_text := ""


func _visible_indices() -> Dictionary:
	if _visible_cache_text == _text and not _visible_cache.is_empty():
		return _visible_cache
	_visible_cache.clear()
	var info := text_component.text_info
	for i in info.character_count:
		_visible_cache[info.character_info[i].index] = true
	_visible_cache_text = _text
	return _visible_cache


func _is_word_char(c: String) -> bool:
	return c.to_upper() != c.to_lower() or (c >= "0" and c <= "9") or c == "_"


func _prev_word(p: int) -> int:
	var q := p
	while q > 0 and not _is_word_char(_text[q - 1]):
		q -= 1
	while q > 0 and _is_word_char(_text[q - 1]):
		q -= 1
	return q


func _next_word(p: int) -> int:
	var q := p
	var n := _text.length()
	while q < n and _is_word_char(_text[q]):
		q += 1
	while q < n and not _is_word_char(_text[q]):
		q += 1
	return q


func _select_word_at(p: int) -> void:
	var a := p
	var b := p
	while a > 0 and _is_word_char(_text[a - 1]):
		a -= 1
	while b < _text.length() and _is_word_char(_text[b]):
		b += 1
	_anchor = a
	_focus = b
	_caret_moved()


func _string_to_char(sp: int) -> int:
	if text_component == null:
		return sp
	var info := text_component.text_info
	for i in info.character_count:
		if info.character_info[i].index >= sp:
			return i
	return info.character_count


func _char_to_string(cp: int) -> int:
	if text_component == null:
		return cp
	var info := text_component.text_info
	if cp < info.character_count and cp >= 0:
		return info.character_info[cp].index
	return _text.length()


func _line_of(sp: int) -> int:
	var info := text_component.text_info
	var ci := _string_to_char(sp)
	if info.character_count == 0:
		return 0
	ci = clampi(ci, 0, info.character_count - 1)
	if sp >= _text.length() and _text.ends_with("\n"):
		return info.line_count
	return info.character_info[ci].line_number


func _line_start(li: int) -> int:
	var info := text_component.text_info
	if li >= info.line_count:
		return _text.length()
	return info.character_info[info.line_info[li].first_character_index].index


func _line_end(li: int) -> int:
	var info := text_component.text_info
	if li >= info.line_count:
		return _text.length()
	var last: int = info.line_info[li].last_character_index
	var c: TypesetterCharacterInfo = info.character_info[last]
	var e := c.index + c.string_length
	if c.character == "\n" or (c.character == " " and li < info.line_count - 1):
		e = c.index
	return mini(e, _text.length())


func _visible_lines() -> int:
	var info := text_component.text_info
	if info.line_count == 0:
		return 1
	var l: TypesetterLineInfo = info.line_info[0]
	var lh := absf(l.line_height) if l.line_height != 0 else text_component.font_size
	return int(text_viewport.size.y / maxf(lh, 1.0))


func _move_vertical(dl: int, shift: bool) -> void:
	var info := text_component.text_info
	var x := _caret_local().position.x
	var li := clampi(_line_of(_focus) + dl, 0, maxi(info.line_count - 1, 0))
	if info.line_count == 0:
		return
	var l: TypesetterLineInfo = info.line_info[li]
	var y := (l.ascender + l.descender) * 0.5
	_move_to(_pos_at(Vector2(x, y)), shift)


## String index nearest to a point in the text component's space.
func _pos_at(p: Vector2) -> int:
	var info := text_component.text_info
	if info.character_count == 0:
		return 0
	var core := text_component.get_text_core()
	var li := core.find_nearest_line(p)
	if li < 0:
		return _text.length()
	var line: TypesetterLineInfo = info.line_info[li]
	var best := _line_start(li)
	var bd := INF
	for ci in range(line.first_character_index, line.last_character_index + 1):
		var c: TypesetterCharacterInfo = info.character_info[ci]
		if c.character == "\n":
			var d0 := absf(p.x - c.origin)
			if d0 < bd:
				bd = d0
				best = c.index
			continue
		var dl := absf(p.x - c.origin)
		var dr := absf(p.x - c.x_advance)
		if dl < bd:
			bd = dl
			best = c.index
		if dr < bd:
			bd = dr
			best = c.index + c.string_length
	return clampi(best, 0, _text.length())


## Caret rectangle in the text component's space.
func _caret_local() -> Rect2:
	var info := text_component.text_info
	var fs := text_component.get_font_size_resolved()
	if info.character_count == 0:
		var x0 := text_component.margin.x
		match text_component.horizontal_alignment:
			TypesetterLabel.HorizontalAlignmentOptions.CENTER:
				x0 = text_component.size.x * 0.5
			TypesetterLabel.HorizontalAlignmentOptions.RIGHT:
				x0 = text_component.size.x - text_component.margin.z
		var ph_h := fs * 1.2
		var y0 := text_component.margin.y
		if text_component.vertical_alignment == TypesetterLabel.VerticalAlignmentOptions.MIDDLE:
			y0 = (text_component.size.y - ph_h) * 0.5
		return Rect2(x0, y0, caret_width, ph_h)
	var ci := _string_to_char(_focus)
	var c: TypesetterCharacterInfo
	var x: float
	if ci < info.character_count:
		c = info.character_info[ci]
		x = c.origin
	else:
		c = info.character_info[info.character_count - 1]
		x = c.x_advance
		if c.character == "\n" and info.line_count > c.line_number:
			# Caret after a trailing newline sits at the start of the next line.
			var l: TypesetterLineInfo = info.line_info[c.line_number]
			var h := absf(l.ascender - l.descender)
			return Rect2(text_component.margin.x, maxf(l.ascender, l.descender), caret_width, h)
	var line: TypesetterLineInfo = info.line_info[c.line_number]
	var top := minf(line.ascender, line.descender)
	var height := absf(line.descender - line.ascender)
	return Rect2(x, top, caret_width, height)


# ------------------------------------------------------------------ display

func _display_text() -> String:
	var t := _text
	if input_type == InputType.PASSWORD:
		t = asterisk_char.repeat(_text.length())
	if not _ime_text.is_empty():
		t = t.substr(0, _focus) + _ime_text + t.substr(_focus)
	return t


func _refresh() -> void:
	if text_component == null or not is_inside_tree():
		return
	text_component.rich_text = rich_text and not is_rich_text_editing_allowed and input_type != InputType.PASSWORD
	text_component.text_wrapping_mode = TypesetterLabel.TextWrappingModes.NORMAL if multi_line else TypesetterLabel.TextWrappingModes.NO_WRAP
	text_component.text = _display_text()
	_visible_cache.clear()
	if placeholder:
		placeholder.visible = _text.is_empty() and _ime_text.is_empty()
	_fit_component()
	_caret_moved()


func _fit_component() -> void:
	if text_viewport == null:
		return
	var vs := text_viewport.size
	if multi_line:
		text_component.size = Vector2(vs.x, vs.y)
		var ph := text_component.preferred_height
		text_component.size = Vector2(vs.x, maxf(vs.y, ph + 2.0))
	else:
		var pw := text_component.preferred_width
		text_component.size = Vector2(maxf(vs.x, pw + caret_width + 2.0), vs.y)
	if vertical_scrollbar:
		vertical_scrollbar.max_value = text_component.size.y
		vertical_scrollbar.page = vs.y
		vertical_scrollbar.visible = multi_line and text_component.size.y > vs.y + 0.5


func _max_scroll() -> Vector2:
	var vs := text_viewport.size
	return Vector2(maxf(0.0, text_component.size.x - vs.x), maxf(0.0, text_component.size.y - vs.y))


func _apply_scroll() -> void:
	text_component.position = -_scroll
	if vertical_scrollbar and not is_equal_approx(vertical_scrollbar.value, _scroll.y):
		vertical_scrollbar.set_value_no_signal(_scroll.y)
	if _overlay:
		_overlay.queue_redraw()


func _on_scrollbar(v: float) -> void:
	_scroll.y = v
	_apply_scroll()


func _caret_moved() -> void:
	_blink = 0.0
	_caret_visible = true
	if text_component == null or text_viewport == null:
		return
	# Keep the caret inside the viewport.
	var r := _caret_local()
	var vs := text_viewport.size
	if r.position.x - _scroll.x < 0.0:
		_scroll.x = r.position.x
	elif r.end.x - _scroll.x > vs.x:
		_scroll.x = r.end.x - vs.x
	if multi_line:
		if r.position.y - _scroll.y < 0.0:
			_scroll.y = r.position.y
		elif r.end.y - _scroll.y > vs.y:
			_scroll.y = r.end.y - vs.y
	var ms := _max_scroll()
	_scroll = Vector2(clampf(_scroll.x, 0.0, ms.x), clampf(_scroll.y, 0.0, ms.y))
	_apply_scroll()
	if DisplayServer.has_feature(DisplayServer.FEATURE_IME) and has_focus():
		DisplayServer.window_set_ime_position(Vector2i(get_screen_position() + text_viewport.position + r.position - _scroll + Vector2(0, r.size.y)))


func _process(delta: float) -> void:
	if caret_blink_rate > 0.0:
		_blink += delta
		var period := 1.0 / caret_blink_rate
		var vis := fmod(_blink, period) < period * 0.5
		if vis != _caret_visible:
			_caret_visible = vis
			if _overlay:
				_overlay.queue_redraw()


func _draw_caret() -> void:
	if text_component == null:
		return
	var info := text_component.text_info
	var off := text_component.position
	var show_sel := has_focus() or keep_text_selection_visible
	if show_sel and _anchor != _focus and info.character_count > 0:
		var lo := mini(_anchor, _focus)
		var hi := maxi(_anchor, _focus)
		var rects := {}
		for i in info.character_count:
			var c: TypesetterCharacterInfo = info.character_info[i]
			if c.index < lo or c.index >= hi:
				continue
			var line: TypesetterLineInfo = info.line_info[c.line_number]
			var top := minf(line.ascender, line.descender)
			var h := absf(line.descender - line.ascender)
			var x1 := c.x_advance
			if c.character == "\n":
				x1 = c.origin + text_component.font_size * 0.25
			var r := Rect2(c.origin, top, x1 - c.origin, h)
			if rects.has(c.line_number):
				rects[c.line_number] = rects[c.line_number].merge(r)
			else:
				rects[c.line_number] = r
		for k in rects:
			var rr: Rect2 = rects[k]
			_overlay.draw_rect(Rect2(rr.position + off, rr.size), selection_color)
	if has_focus() and _caret_visible and not read_only:
		var cr := _caret_local()
		var col := caret_color if custom_caret_color else text_component.color
		_overlay.draw_rect(Rect2(cr.position + off, Vector2(caret_width, cr.size.y)), col)
