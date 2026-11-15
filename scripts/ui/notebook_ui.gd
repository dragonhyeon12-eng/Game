class_name NotebookUI
extends Control
## The open notebook: one lined page of rules, in whoever's handwriting wrote them.

var _age := 0.0
var _closed := false


static func create(title: String, lines: Array) -> NotebookUI:
	var n := NotebookUI.new()
	n._build(title, lines)
	return n


func _build(title: String, lines: Array) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(660, 580)
	var style := UIStyle.panel_style(UIStyle.PAPER, 0)
	style.content_margin_left = 80
	style.content_margin_right = 46
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	paper.add_theme_stylebox_override("panel", style)
	center.add_child(paper)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	paper.add_child(page)
	var head := UIStyle.label(title, 24, UIStyle.ink("Player"), UIStyle.hand_font())
	page.add_child(head)

	if lines.is_empty():
		page.add_child(UIStyle.label("(empty)", 19, Color(0.4, 0.4, 0.45), UIStyle.hand_font()))
	for line in lines:
		var style_name: String = line.get("style", "Player")
		var text: String = line.text
		if int(line.get("number", 0)) > 0:
			text = "%d.  %s" % [line.number, text]
		var size := 21.0
		if style_name == "Pressed":
			size = 23.0
		var l := UIStyle.label(text, size, UIStyle.ink(style_name), UIStyle.ink_font(style_name))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		if style_name == "Pressed":
			l.add_theme_constant_override("outline_size", 2)
			l.add_theme_color_override("font_outline_color", UIStyle.ink("Pressed"))
		var row := MarginContainer.new()
		row.add_theme_constant_override("margin_left", 46 if style_name == "Unknown" else 0)
		row.add_theme_constant_override("margin_top", 10)
		row.add_child(l)
		page.add_child(row)
		var rule := ColorRect.new()
		rule.color = Color(0.55, 0.68, 0.85, 0.45)
		rule.custom_minimum_size = Vector2(0, 1)
		page.add_child(rule)

	var hint := UIStyle.label("N / Esc   close", 13, UIStyle.DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -50
	hint.offset_left = -80
	add_child(hint)


func _process(delta: float) -> void:
	_age += delta


func _close() -> void:
	if _closed or _age < 0.2:
		return
	_closed = true
	Game.close_notebook()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_close()
