class_name DPMenu
extends Control
## Keyboard / mouse / gamepad menu used for the title screen, the pause menu (including its corrupted
## form) and settings. Up/Down select, Enter activates, Left/Right change a setting, Esc goes back.
##
## items: [{label, action: Callable, value: Callable (optional), adjust: Callable(dir) (optional)}]

var on_back: Callable
var on_timeout: Callable
var _buttons: Array[Button] = []
var _items: Array = []
var _age := 0.0
var _scroll: ScrollContainer


static func create(title: String, subtitle: String, items: Array, footnote := "", corrupted := false) -> DPMenu:
	var m := DPMenu.new()
	m._build(title, subtitle, items, footnote, corrupted)
	return m


func _build(title: String, subtitle: String, items: Array, footnote: String, corrupted: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_items = items
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.86 if corrupted else 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.position = Vector2(120, 0)
	box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	box.offset_left = 120
	box.offset_right = 900
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	if title != "":
		box.add_child(UIStyle.label(title, 30 if corrupted else 46, UIStyle.DANGER if corrupted else UIStyle.TEXT))
	if subtitle != "":
		var s := UIStyle.label(subtitle, 15, UIStyle.DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(s)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	box.add_child(spacer)

	# long lists (settings) scroll - by wheel, by drag on a touch screen - so every row can be reached on a phone
	var list: Container = box
	if items.size() > 10:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(760, 0)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.scroll_deadzone = 12
		box.alignment = BoxContainer.ALIGNMENT_BEGIN
		box.offset_top = 40
		box.offset_bottom = -30
		box.add_child(scroll)
		_scroll = scroll
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(inner)
		list = inner

	for i in items.size():
		var it: Dictionary = items[i]
		var b := UIStyle.flat_button(_label_for(it), 24)
		b.custom_minimum_size = Vector2(560, 0)
		if corrupted:
			b.add_theme_color_override("font_focus_color", UIStyle.DANGER)
			b.add_theme_color_override("font_hover_color", UIStyle.DANGER)
		b.pressed.connect(_on_pressed.bind(i))
		b.gui_input.connect(_on_button_input.bind(i))
		b.mouse_entered.connect(b.grab_focus)
		_buttons.append(b)
		if it.has("adjust"):
			# real arrow buttons you can tap (on a phone there are no Left / Right keys)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(520, 0)
			row.add_child(b)
			for d in [-1, 1]:
				var ab := _arrow_button("<" if d < 0 else ">")
				ab.pressed.connect(_on_arrow.bind(i, d))
				row.add_child(ab)
			list.add_child(row)
		else:
			list.add_child(b)

	if footnote != "":
		var f := UIStyle.label(footnote, 12, Color(0.55, 0.55, 0.55, 0.85))
		f.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		f.offset_left = -560
		f.offset_top = -50
		f.offset_right = -40
		f.offset_bottom = -24
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(f)


func _ready() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()


func set_timeout(seconds: float, callback: Callable) -> void:
	on_timeout = callback
	get_tree().create_timer(seconds, true).timeout.connect(func():
		if is_inside_tree() and on_timeout.is_valid():
			var cb := on_timeout
			on_timeout = Callable()
			cb.call())


func _label_for(it: Dictionary) -> String:
	if it.has("value"):
		return "%s     %s" % [tr(it.label), tr(str(it.value.call()))]
	return it.label


func _arrow_button(text: String) -> Button:
	var ab := Button.new()
	ab.text = text
	ab.focus_mode = Control.FOCUS_NONE
	ab.custom_minimum_size = Vector2(64, 46)
	ab.add_theme_font_size_override("font_size", UIStyle.size(26))
	ab.add_theme_color_override("font_color", UIStyle.TEXT)
	ab.add_theme_color_override("font_hover_color", UIStyle.ACCENT)
	ab.add_theme_color_override("font_pressed_color", UIStyle.ACCENT)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08 if state == "normal" else 0.18)
		sb.set_corner_radius_all(6)
		sb.border_width_bottom = 2
		sb.border_color = Color(1, 1, 1, 0.15)
		ab.add_theme_stylebox_override(state, sb)
	return ab


func _on_arrow(i: int, dir: int) -> void:
	if _age < 0.15:
		return
	_items[i].adjust.call(dir)
	_refresh()
	_buttons[i].grab_focus()


func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].text = _label_for(_items[i])


func _process(delta: float) -> void:
	_age += delta


func _on_pressed(i: int) -> void:
	if _age < 0.15:
		return  # ignore the key press that opened the menu
	var it: Dictionary = _items[i]
	if it.has("adjust"):
		it.adjust.call(2)        # tapping the row itself: the next value, round to the first again after the last
		_refresh()
	elif it.has("action"):
		it.action.call()


func _on_button_input(event: InputEvent, i: int) -> void:
	var it: Dictionary = _items[i]
	if not it.has("adjust"):
		return
	if event.is_action_pressed("ui_left"):
		it.adjust.call(-1)
		_refresh()
		accept_event()
	elif event.is_action_pressed("ui_right"):
		it.adjust.call(1)
		_refresh()
		accept_event()


## A finger dragged over the list scrolls it, wherever it starts (even on a row's button).
func _input(event: InputEvent) -> void:
	if _scroll and is_visible_in_tree() and event is InputEventScreenDrag:
		_scroll.scroll_vertical -= int(event.relative.y)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") and _age >= 0.15 and on_back.is_valid():
		get_viewport().set_input_as_handled()
		on_back.call()
