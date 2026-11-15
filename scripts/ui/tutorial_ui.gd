class_name TutorialUI
extends Control
## The fictional video "HOW TO LUCID DREAM TONIGHT! (100% WORKING)", full-screen on the bedroom PC.
## Lines advance on a timer (Space skips a line, Esc skips the video). When a line names a rule, the
## player writes it into the notebook - shown in the margin.

var _script: Dictionary
var _lines: Array
var _index := -1
var _line_t := 0.0
var _elapsed := 0.0
var _total := 1.0
var _age := 0.0
var _done := false
var _caption: Label
var _bar: ProgressBar
var _margin: VBoxContainer
var _written := 0


static func create(script_data: Dictionary) -> TutorialUI:
	var t := TutorialUI.new()
	t._build(script_data)
	return t


func _build(data: Dictionary) -> void:
	_script = data
	_lines = data.get("lines", [])
	_total = 0.0
	for l in _lines:
		_total += maxf(0.5, float(l.get("duration", 4.0)))
	_total = maxf(_total, 1.0)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var page := ColorRect.new()
	page.color = Color(0.07, 0.07, 0.08)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 60
	row.offset_top = 40
	row.offset_right = -60
	row.offset_bottom = -40
	row.add_theme_constant_override("separation", 36)
	add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var video := PanelContainer.new()
	video.size_flags_vertical = Control.SIZE_EXPAND_FILL
	video.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.015, 0.02, 0.035), 70))
	col.add_child(video)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	video.add_child(vbox)
	_caption = UIStyle.label("", 32, Color(0.95, 0.95, 1.0))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_caption)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.15)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.3, 0.3, 0.3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	col.add_child(_bar)

	col.add_child(UIStyle.label(data.get("title", ""), 24, UIStyle.TEXT))
	col.add_child(UIStyle.label("%s   -   %s" % [data.get("channel", ""), data.get("views", "")], 15, UIStyle.DIM))
	col.add_child(UIStyle.label("Space  skip line        Esc  skip video", 12, Color(0.45, 0.45, 0.45)))

	var notebook := PanelContainer.new()
	notebook.custom_minimum_size = Vector2(400, 0)
	notebook.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PAPER, 26))
	row.add_child(notebook)
	_margin = VBoxContainer.new()
	_margin.add_theme_constant_override("separation", 10)
	notebook.add_child(_margin)
	_margin.add_child(UIStyle.label(Data.notebook_title, 21, UIStyle.ink("Player"), UIStyle.hand_font()))
	_enter(0)


func _enter(i: int) -> void:
	_index = i
	_line_t = 0.0
	if i >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[i]
	_caption.text = line.get("text", "")
	var rule: String = line.get("writeRule", "")
	if rule != "" and Data.rules.has(rule):
		_written += 1
		var l := UIStyle.label("%d. %s" % [_written, Data.rules[rule].text], 18, UIStyle.ink("Player"), UIStyle.hand_font())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_margin.add_child(l)
		Notebook.write(rule)
		Sfx.play("page", -10.0, 1.3)


func _finish() -> void:
	if _done:
		return
	_done = true
	_caption.text = ""
	Game.on_tutorial_finished()


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_line_t += delta
	_elapsed += delta
	_bar.value = clampf(_elapsed / _total, 0.0, 1.0)
	if _index < _lines.size() and _line_t >= maxf(0.5, float(_lines[_index].get("duration", 4.0))):
		_enter(_index + 1)


func _input(event: InputEvent) -> void:
	if _done or _age < 0.3:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _index < _lines.size():
			_elapsed += maxf(0.0, float(_lines[_index].get("duration", 4.0)) - _line_t)
		_enter(_index + 1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		while not _done:   # skipping still writes every rule down
			_enter(_index + 1)
