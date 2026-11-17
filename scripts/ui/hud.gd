class_name HUD
extends CanvasLayer
## Every on-screen element, built in code: DREAD post-processing, crosshair, prompts, thoughts, hints,
## dialogue, the DREAD meter, fades, title cards, menus, the notebook and the tutorial video.
## Gameplay talks to it through small, intention-named calls (show_thought, fade_to, ...).

var _post: ColorRect
var _post_mat: ShaderMaterial
var _crosshair: ColorRect
var _prompt: Label
var _hold_box: VBoxContainer
var _hold_label: Label
var _hold_bar: ProgressBar
var _hint_panel: PanelContainer
var _skip_label: Label
var _obj_panel: PanelContainer
var _obj_label: Label
var _obj_text := ""
var _hint: Label
var _thought: Label
var _meter_box: VBoxContainer
var _meter_label: Label
var _meter_bar: ProgressBar
var _dialogue: PanelContainer
var _speaker: Label
var _line: Label
var _choices: VBoxContainer
var _overlay: Control
var _fade: ColorRect
var _underwater: ColorRect
var _breath_bar: ProgressBar
var _card_box: VBoxContainer
var _card_big: Label
var _card_small: Label
var _menu_layer: Control

var _gameplay_visible := false
var _thought_t := 0.0
var _hint_t := 0.0
var _fade_alpha := 0.0
var _fade_target := 0.0
var _fade_speed := 1.0
var _card_alpha := 0.0
var _card_target := 0.0
var _card_speed := 1.0
var _overlay_open := false


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	Settings.changed.connect(_rebuild_text_sizes)


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _bar(width: float, height: float, fill_color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(width, height)
	var f := StyleBoxFlat.new()
	f.bg_color = fill_color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.13)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", bg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build() -> void:
	var root := _full(Control.new())
	add_child(root)

	_post = _full(ColorRect.new())
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://scripts/ui/post.gdshader")
	_post.material = _post_mat
	root.add_child(_post)

	_underwater = _full(ColorRect.new())
	_underwater.color = Color(0.02, 0.22, 0.28, 0.55)
	_underwater.visible = false
	root.add_child(_underwater)

	_crosshair = ColorRect.new()
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	_prompt = UIStyle.shadowed(UIStyle.label("", 18))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 70
	_prompt.offset_bottom = 110
	root.add_child(_prompt)

	_hold_box = VBoxContainer.new()
	_hold_box.set_anchors_preset(Control.PRESET_CENTER)
	_hold_box.offset_left = -120
	_hold_box.offset_right = 120
	_hold_box.offset_top = 120
	_hold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_label = UIStyle.shadowed(UIStyle.label("", 16, UIStyle.TEXT, UIStyle.italic_font()))
	_hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_box.add_child(_hold_label)
	_hold_bar = _bar(240, 4, UIStyle.ACCENT)
	_hold_box.add_child(_hold_bar)
	root.add_child(_hold_box)

	_breath_bar = _bar(200, 5, Color(0.6, 0.9, 1.0, 0.9))
	_breath_bar.set_anchors_preset(Control.PRESET_CENTER)
	_breath_bar.offset_left = -100
	_breath_bar.offset_right = 100
	_breath_bar.offset_top = 40
	_breath_bar.offset_bottom = 45
	root.add_child(_breath_bar)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_hint_panel.position = Vector2(48, 44)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = UIStyle.label("", 16)
	_hint_panel.add_child(_hint)
	root.add_child(_hint_panel)

	_obj_panel = PanelContainer.new()
	_obj_panel.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_obj_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_obj_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_obj_panel.offset_right = -40
	_obj_panel.offset_top = 40
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_panel.modulate.a = 0.85
	_obj_label = UIStyle.label("", 15)
	_obj_panel.add_child(_obj_label)
	root.add_child(_obj_panel)

	_thought = UIStyle.shadowed(UIStyle.label("", 22, Color(0.95, 0.94, 0.9), UIStyle.italic_font()))
	_thought.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.offset_left = -520
	_thought.offset_right = 520
	_thought.offset_top = -210
	_thought.offset_bottom = -130
	root.add_child(_thought)

	_meter_box = VBoxContainer.new()
	_meter_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_meter_box.offset_left = 48
	_meter_box.offset_top = -80
	_meter_box.offset_bottom = -40
	_meter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_label = UIStyle.label("", 13)
	_meter_box.add_child(_meter_label)
	_meter_bar = _bar(170, 4, Color(0.75, 0.12, 0.1, 0.9))
	_meter_box.add_child(_meter_bar)
	root.add_child(_meter_box)

	_dialogue = PanelContainer.new()
	_dialogue.add_theme_stylebox_override("panel", UIStyle.panel_style(UIStyle.PANEL, 26))
	_dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.offset_left = -460
	_dialogue.offset_right = 460
	_dialogue.offset_top = -330
	_dialogue.offset_bottom = -50
	_dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	_dialogue.add_child(dv)
	_speaker = UIStyle.label("", 17, UIStyle.ACCENT)
	dv.add_child(_speaker)
	_line = UIStyle.label("", 20)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_line)
	_choices = VBoxContainer.new()
	dv.add_child(_choices)
	_dialogue.visible = false
	root.add_child(_dialogue)

	_overlay = _full(Control.new())
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_overlay)

	_fade = _full(ColorRect.new())
	_fade.color = Color(0, 0, 0, 0)
	root.add_child(_fade)

	_card_box = VBoxContainer.new()
	_card_box.set_anchors_preset(Control.PRESET_CENTER)
	_card_box.offset_left = -600
	_card_box.offset_right = 600
	_card_box.offset_top = -60
	_card_box.offset_bottom = 60
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_big = UIStyle.label("", 38, Color(0.92, 0.9, 0.86), UIStyle.italic_font())
	_card_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_small = UIStyle.label("", 15, UIStyle.DIM)
	_card_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_card_big)
	_card_box.add_child(_card_small)
	_card_box.modulate.a = 0.0
	root.add_child(_card_box)

	_skip_label = UIStyle.label(for_touch("[Space / E]  skip"), 15, UIStyle.DIM)
	_skip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_label.offset_right = -40
	_skip_label.offset_bottom = -30
	_skip_label.visible = false
	root.add_child(_skip_label)

	_menu_layer = _full(Control.new())
	_menu_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_menu_layer)


func _rebuild_text_sizes() -> void:
	# Simple and reliable: re-apply the scaled font sizes to the persistent labels.
	for pair in [[_prompt, 18], [_hold_label, 16], [_hint, 16], [_thought, 22], [_meter_label, 13], [_speaker, 17],
			[_line, 20], [_card_big, 38], [_card_small, 15]]:
		pair[0].add_theme_font_size_override("font_size", UIStyle.size(pair[1]))


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	var player = Game.player
	var gameplay := _gameplay_visible and not menu_open() and not _overlay_open
	var prompt: String = player.prompt() if player and not player.controls_locked else ""
	_crosshair.visible = gameplay and not _dialogue.visible
	_crosshair.color = Color(1, 1, 1, 0.9 if prompt != "" else 0.35)
	_prompt.visible = gameplay and not _dialogue.visible and prompt != ""
	_prompt.text = ("USE:  " if TouchControls.wanted() else "[E]  ") + prompt

	var hold := -1.0
	if player:
		hold = maxf(player.manifest_hold, player.wake_hold)
		_hold_label.text = "Wake up..." if player.wake_hold >= 0.0 else "Picturing %s..." % player.manifestation.selected_name()
	_hold_box.visible = gameplay and hold >= 0.0
	_hold_bar.value = hold

	_thought_t = maxf(0.0, _thought_t - delta)
	_thought.visible = _thought_t > 0.0 and not menu_open() and not _overlay_open and not _dialogue.visible
	_thought.modulate.a = clampf(_thought_t / 0.5, 0.0, 1.0)
	if not menu_open() and not _overlay_open:
		_hint_t = maxf(0.0, _hint_t - delta)
	_hint_panel.visible = gameplay and _hint_t > 0.0
	_obj_panel.visible = gameplay and Settings.show_objectives and _obj_text != "" and not _dialogue.visible
	_hint_panel.modulate.a = clampf(_hint_t / 0.6, 0.0, 1.0)

	if player:
		_underwater.visible = player.underwater
		var sea: bool = Game.zone != null and Game.zone.has_method("breathable_at") and Game.zone.breathable_at(player.camera.global_position)
		_underwater.color.a = (0.18 if sea else 0.55) + 0.25 * (1.0 - player.breath)
		_breath_bar.visible = gameplay and player.breath < 0.999
		_breath_bar.value = player.breath
		(_breath_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.6, 0.9, 1.0, 0.9) if player.breath > 0.3 else Color(0.9, 0.2, 0.15, 0.95)
	_meter_box.visible = gameplay and player != null and Settings.show_dread_meter and Game.zone_type != "bedroom"
	if player:
		var a: float = player.dread.alpha()
		_meter_label.text = "DREAD   " + player.dread.stage_name()
		_meter_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82, 0.7).lerp(Color(0.85, 0.1, 0.08, 0.95), a))
		_meter_bar.value = a

	_fade_alpha = move_toward(_fade_alpha, _fade_target, _fade_speed * delta)
	_fade.color.a = _fade_alpha
	_card_alpha = move_toward(_card_alpha, _card_target, _card_speed * delta)
	_card_box.modulate.a = _card_alpha


func set_post(vignette: float, grain: float, desat: float, fringe: float) -> void:
	_post_mat.set_shader_parameter("vignette", vignette)
	_post_mat.set_shader_parameter("grain", grain)
	_post_mat.set_shader_parameter("desat", desat)
	_post_mat.set_shader_parameter("fringe", fringe)


func set_gameplay_visible(v: bool) -> void:
	_gameplay_visible = v


# ------------------------------------------------------------------ text

# ------------------------------------------------------------------ jumpscare

const SCARE_IMAGES := ["res://assets/jumpscare/scare_1.png", "res://assets/jumpscare/scare_2.jpg", "res://assets/jumpscare/scare_3.jpg",
	"res://assets/jumpscare/scare_4.png", "res://assets/jumpscare/scare_5.jpg", "res://assets/jumpscare/scare_6.jpg"]
var _scare_tex: Array[Texture2D] = []


## Faces, flashing at you: a few frames each, jittering, sometimes a white-out. Follows Settings.visual_intensity
## (photosensitivity): lower = slower and no white frames; at 0, a single face held still.
func jumpscare(seconds := 1.6) -> void:
	if _scare_tex.is_empty():
		for p in SCARE_IMAGES:
			var t := load(p) as Texture2D
			if t:
				_scare_tex.append(t)
	if _scare_tex.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var img := TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.add_child(img)
	var intensity := clampf(Settings.visual_intensity, 0.0, 1.0)
	Sfx.stinger("jumpscare", 4.0)
	Sfx.play("static_burst", -2.0 + 6.0 * Settings.audio_intensity, 1.3)
	if intensity <= 0.05:
		img.texture = _scare_tex.pick_random()
		await get_tree().create_timer(seconds * 0.6, true).timeout
		layer.queue_free()
		return
	var step := lerpf(0.16, 0.045, intensity)
	var t := 0.0
	var last := -1
	var size := get_viewport().get_visible_rect().size
	while t < seconds:
		var i := randi() % _scare_tex.size()
		if i == last:
			i = (i + 1) % _scare_tex.size()
		last = i
		img.texture = _scare_tex[i]
		var z := randf_range(1.0, 1.0 + 0.45 * intensity)
		img.pivot_offset = size * 0.5
		img.scale = Vector2(z, z)
		img.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 40.0 * intensity
		img.rotation = randf_range(-0.06, 0.06) * intensity
		var r := randf()
		img.modulate = Color.WHITE if r < 0.5 else (Color(1.0, 0.35, 0.3) if r < 0.75 else Color(1.6, 1.6, 1.6))
		var white := intensity >= 0.5 and randf() < 0.22
		bg.color = Color.WHITE if white else Color.BLACK
		img.visible = not white or randf() < 0.5
		if white:
			img.modulate = Color(0, 0, 0)    # a black face burned into the white
		if randf() < 0.3:
			Sfx.play("screech", -8.0 + 6.0 * Settings.audio_intensity, randf_range(1.2, 1.8))
		await get_tree().create_timer(step * randf_range(0.7, 1.3), true).timeout
		t += step
	layer.queue_free()


## Keys named in hints and thoughts, as the touch buttons are called (on phones and tablets).
const TOUCH_WORDS := [
	["Left mouse: take a bite    Right mouse: let go / toss\nMouse wheel: picture something else",
		"BITE: take a bite    DROP: let go / toss\n< >: picture something else"],
	["Crouch (C / Ctrl)", "Tap CROUCH"], ["Crouch. (C)", "Tap CROUCH."], ["(C / Ctrl)", "(CROUCH)"],
	["(hold Q)", "(hold PICTURE)"], ["Hold Q", "Hold PICTURE"], ["hold Q", "hold PICTURE"],
	["Hold T", "Hold WAKE"], ["hold T", "hold WAKE"], ["[Space / E]  skip", "SKIP"], ["[E]  ", ""],
]


## The same, for the Korean text (keys are written "Q 길게 누르기" and so on in data/Lang_ko.json).
const TOUCH_WORDS_KO := [
	["왼쪽 마우스: 한 입 먹기    오른쪽 마우스: 놓기 / 던지기\n마우스 휠: 다른 것 상상하기", "한입: 한 입 먹기    놓기: 놓기 / 던지기\n< >: 다른 것 상상하기"],
	["(C / Ctrl)", "(웅크리기 버튼)"], ["(C)", "(웅크리기 버튼)"],
	["Q 길게 누르기", "상상 버튼 길게 누르기"], ["T 길게 누르기", "깨기 버튼 길게 누르기"],
	["[Space / E]  건너뛰기", "건너뛰기"], ["[E]  ", ""],
]


## Text as the player should read it: in their language, naming touch buttons instead of keys on touch screens.
static func for_touch(text: String) -> String:
	var ko := Loc.korean()
	if ko:
		text = Loc.t(text)
	if not TouchControls.wanted():
		return text
	for pair in (TOUCH_WORDS_KO if ko else TOUCH_WORDS):
		text = text.replace(pair[0], pair[1])
	return text


func show_thought(text: String, seconds := 4.0) -> void:
	_thought.text = for_touch(text)
	_thought_t = seconds


## Objective list: [[text, done], ...]
func set_objectives(list: Array) -> void:
	var lines := PackedStringArray()
	for o in list:
		lines.append(("[x]  " if o[1] else "[  ]  ") + for_touch(String(o[0])))
	var txt := "\n".join(lines)
	if txt == _obj_text:
		return
	var newly_done: bool = _obj_text != "" and txt.count("[x]") > _obj_text.count("[x]")
	_obj_text = txt
	_obj_label.text = "OBJECTIVES\n" + txt if txt != "" else ""
	if newly_done:
		Sfx.play("page", -8.0, 1.2)


func show_hint(text: String, seconds := 6.0) -> void:
	_hint.text = for_touch(text)
	_hint_t = seconds


func clear_text() -> void:
	_thought_t = 0.0
	_hint_t = 0.0
	hide_dialogue()


# ------------------------------------------------------------------ screen

func fade_to(alpha: float, seconds: float, color := Color.BLACK) -> void:
	_fade.color = Color(color.r, color.g, color.b, _fade_alpha)
	_fade_target = clampf(alpha, 0.0, 1.0)
	if seconds <= 0.0:
		_fade_alpha = _fade_target
		_fade_speed = 1000.0
	else:
		_fade_speed = maxf(0.01, absf(_fade_target - _fade_alpha) / seconds)


func set_fade(alpha: float, color := Color.BLACK) -> void:
	_fade_alpha = clampf(alpha, 0.0, 1.0)
	_fade_target = _fade_alpha
	_fade.color = Color(color.r, color.g, color.b, _fade_alpha)


func show_card(big: String, small := "", seconds := 1.0) -> void:
	_card_big.text = big
	_card_small.text = small
	_card_target = 1.0
	_card_speed = 1000.0 if seconds <= 0.0 else 1.0 / seconds


func show_skip(on: bool) -> void:
	_skip_label.visible = on


func hide_card(seconds := 1.0) -> void:
	_card_target = 0.0
	_card_speed = 1000.0 if seconds <= 0.0 else 1.0 / seconds
	if seconds <= 0.0:
		_card_alpha = 0.0


# ------------------------------------------------------------------ dialogue

func show_dialogue(speaker: String, text: String, choices: Array) -> void:
	_dialogue.visible = true
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_line.text = text
	_line.add_theme_color_override("font_color", UIStyle.DIM if speaker == "" else UIStyle.TEXT)
	if speaker == "":
		_line.add_theme_font_override("font", UIStyle.italic_font())
	else:
		_line.remove_theme_font_override("font")
	for c in _choices.get_children():
		c.queue_free()
	if choices.is_empty():
		var b := UIStyle.flat_button(for_touch("[E]  Continue"), 18)
		b.pressed.connect(func(): Dialogue.advance())
		_choices.add_child(b)
	for i in choices.size():
		var b := UIStyle.flat_button("%d.  %s" % [i + 1, choices[i]], 18)
		b.pressed.connect(func(): Dialogue.choose(i))
		_choices.add_child(b)


func hide_dialogue() -> void:
	_dialogue.visible = false
	for c in _choices.get_children():
		c.queue_free()


# ------------------------------------------------------------------ menus

func menu_open() -> bool:
	return _menu_layer.get_child_count() > 0


func _set_menu(m: Control) -> void:
	for c in _menu_layer.get_children():
		_menu_layer.remove_child(c)
		c.queue_free()
	_menu_layer.add_child(m)


func close_menu() -> void:
	for c in _menu_layer.get_children():
		_menu_layer.remove_child(c)
		c.queue_free()


func open_title(has_save: bool) -> void:
	var items := []
	if has_save:
		items.append({"label": "CONTINUE", "action": Game.continue_game})
	items.append({"label": "NEW GAME", "action": Game.start_new_game})
	items.append({"label": "DREAM JOURNAL", "action": func(): _set_menu(JournalUI.create(func(): open_title(Game.has_checkpoint())))})
	items.append({"label": "SETTINGS", "action": func(): _settings(func(): open_title(Game.has_checkpoint()))})
	if not OS.has_feature("web"):   # a browser tab can't quit itself
		items.append({"label": "QUIT", "action": Game.quit_game})
	_set_menu(DPMenu.create("DREAM PROTOCOL", "a lucid dream", items, "Vertical slice - work in progress"))


func open_pause(corrupted: bool, may_self_unpause: bool) -> void:
	if not corrupted:
		_normal_pause()
		return
	# All three really do resume.
	var resume := func(): Game.resume()
	var m := DPMenu.create("WHY ARE YOU HIDING?", "", [
		{"label": "RESUME", "action": resume}, {"label": "RESUME", "action": resume}, {"label": "RESUME", "action": resume}],
		"(Note from dev: press ESC to actually leave. Sorry man)", true)
	m.on_back = _normal_pause
	_set_menu(m)
	if may_self_unpause:
		m.set_timeout(6.0, func(): Game.resume(true))


func _normal_pause() -> void:
	var m := DPMenu.create("PAUSED", "", [
		{"label": "EXIT", "action": Game.quit_game},
		{"label": "MENU", "action": _pause_submenu},
		{"label": "RESUME", "action": func(): Game.resume()}])
	m.on_back = func(): Game.resume()
	_set_menu(m)


func _pause_submenu() -> void:
	var m := DPMenu.create("MENU", "Progress is saved at the start of each area.", [
		{"label": "DREAM JOURNAL", "action": func(): _set_menu(JournalUI.create(_pause_submenu))},
		{"label": "SETTINGS", "action": func(): _settings(_pause_submenu)},
		{"label": "RETURN TO TITLE", "action": Game.return_to_title},
		{"label": "BACK", "action": _normal_pause}])
	m.on_back = _normal_pause
	_set_menu(m)


func _settings(back: Callable) -> void:
	var pct := func(v): return "%d%%" % roundi(v * 100.0)
	var onoff := func(v): return "ON" if v else "OFF"
	var num := func(key: String, lo: float, hi: float, step: float, fmt: Callable) -> Dictionary:
		return {"label": "", "key": key,
			"value": func(): return fmt.call(Settings.get(key)),
			"adjust": func(dir: int): Settings.set_value(key, clampf(snappedf(Settings.get(key) + dir * step, step), lo, hi))}
	var flag := func(key: String) -> Dictionary:
		return {"label": "", "key": key,
			"value": func(): return onoff.call(Settings.get(key)),
			"adjust": func(_dir: int): Settings.set_value(key, not Settings.get(key))}
	var rows := [
		["Mouse sensitivity", num.call("mouse_sensitivity", 0.2, 3.0, 0.1, func(v): return "%.1f" % v)],
		["Invert look", flag.call("invert_y")],
		["Field of view", num.call("fov", 60.0, 100.0, 5.0, func(v): return "%d" % roundi(v))],
		["Head bob", flag.call("head_bob")],
		["Camera jolts", flag.call("camera_effects")],
		["Visual intensity", num.call("visual_intensity", 0.0, 1.0, 0.1, pct)],
		["Horror audio intensity", num.call("audio_intensity", 0.0, 1.0, 0.1, pct)],
		["Master volume", num.call("master_volume", 0.0, 1.0, 0.1, pct)],
		["Music volume", num.call("music_volume", 0.0, 1.0, 0.1, pct)],
		["Text size", num.call("text_scale", 1.0, 1.5, 0.25, pct)],
		["DREAD meter", flag.call("show_dread_meter")],
		["Menu corruption", flag.call("menu_corruption")],
		["Game may unpause itself", flag.call("self_unpause")],
		["Graphics quality (next area)", num.call("quality", 0.0, 1.0, 1.0, func(v): return "HIGH" if v >= 1 else "LOW")],
		["Super duper shaders (strong GPU)", flag.call("super_shaders")],
		["Show objectives", flag.call("show_objectives")],
		["Touch controls", num.call("touch_controls", 0.0, 2.0, 1.0, func(v): return ["AUTO", "ON", "OFF"][clampi(roundi(v), 0, 2)])],
		["Language / 언어", num.call("language", 0.0, 1.0, 1.0, func(v): return Loc.NAMES[clampi(roundi(v), 0, 1)])],
	]
	var items := []
	for r in rows:
		var it: Dictionary = r[1]
		it.label = r[0]
		items.append(it)
	items.append({"label": "BACK", "action": back})
	var m := DPMenu.create("SETTINGS", "Left / Right to change. Intensity settings soften flicker, distortion and horror audio.", items)
	m.on_back = back
	_set_menu(m)


# ------------------------------------------------------------------ overlays

func overlay_open() -> bool:
	return _overlay_open


func open_notebook(title: String, lines: Array) -> void:
	close_overlay()
	_overlay.add_child(NotebookUI.create(title, lines))
	_overlay_open = true


func open_tutorial(script_data: Dictionary) -> void:
	close_overlay()
	_overlay.add_child(TutorialUI.create(script_data))
	_overlay_open = true


func close_overlay() -> void:
	for c in _overlay.get_children():
		_overlay.remove_child(c)
		c.queue_free()
	_overlay_open = false
