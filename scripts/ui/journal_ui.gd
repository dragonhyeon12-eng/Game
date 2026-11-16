class_name JournalUI
extends Control
## The dream journal: a list of the places you have dreamed on the left, the entry on the right,
## written in your own hand. Places you haven't reached yet are just blank lines.

var on_back: Callable
var _page_title: Label
var _page: Label
var _buttons: Array[Button] = []
var _age := 0.0


static func create(back: Callable) -> JournalUI:
	var j := JournalUI.new()
	j.on_back = back
	j._build()
	return j


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(1080, 640)
	var style := UIStyle.panel_style(UIStyle.PAPER, 36)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	paper.add_theme_stylebox_override("panel", style)
	center.add_child(paper)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	paper.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(UIStyle.label("DREAM JOURNAL", 26, UIStyle.ink("Player"), UIStyle.hand_font()))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	left.add_child(gap)

	var first_unlocked := -1
	for i in Data.journal.size():
		var e: Dictionary = Data.journal[i]
		var open := Journal.is_unlocked(e.id)
		var b := UIStyle.flat_button(e.title if open else "- - - - - -", 20)
		b.add_theme_color_override("font_color", UIStyle.ink("Player") if open else Color(0.5, 0.5, 0.5))
		b.add_theme_color_override("font_hover_color", UIStyle.ink("Pressed"))
		b.add_theme_color_override("font_focus_color", UIStyle.ink("Pressed"))
		b.add_theme_font_override("font", UIStyle.hand_font())
		b.disabled = not open
		b.focus_entered.connect(_show.bind(i))
		b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
		left.add_child(b)
		_buttons.append(b)
		if open and first_unlocked < 0:
			first_unlocked = i

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var back := UIStyle.flat_button("BACK", 18)
	back.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	back.pressed.connect(func(): on_back.call())
	left.add_child(back)

	var line := ColorRect.new()
	line.color = Color(0.85, 0.3, 0.3, 0.45)
	line.custom_minimum_size = Vector2(2, 0)
	row.add_child(line)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	_page_title = UIStyle.label("", 28, UIStyle.ink("Pressed"), UIStyle.hand_font())
	right.add_child(_page_title)
	_page = UIStyle.label("", 19, UIStyle.ink("Player"), UIStyle.hand_font())
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.custom_minimum_size = Vector2(640, 0)
	right.add_child(_page)

	if first_unlocked >= 0:
		_show(first_unlocked)
		_buttons[first_unlocked].grab_focus.call_deferred()
	else:
		_page_title.text = ""
		_page.text = "Nothing yet. The pages are empty.\n\nGo to sleep."
		back.grab_focus.call_deferred()


func _show(i: int) -> void:
	var e: Dictionary = Data.journal[i]
	_page_title.text = e.title
	_page.text = e.text


func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _age > 0.15:
		get_viewport().set_input_as_handled()
		on_back.call()
