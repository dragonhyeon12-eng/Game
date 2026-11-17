class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (and touch laptops, if switched on in Settings).
##
##  - left side: a floating stick (put your thumb down anywhere on the left, drag to walk);
##  - right side: drag to look around;
##  - buttons: USE, JUMP, CROUCH, RUN (toggle), PICTURE (hold), WAKE (hold), BITE / DROP while holding
##    something, and MENU / NOTES at the top.
##
## Buttons send the same input actions as the keyboard (press and release events), so every system
## that listens for "interact", "jump", "manifest"... works unchanged. The stick sets movement action
## strengths; looking calls Player.look(). While playing, touches are NOT turned into mouse clicks (a
## tap would otherwise also "bite"); in menus they are, so menus work by tapping.

const STICK_RADIUS := 110.0
const KNOB_RADIUS := 46.0
const LOOK_SPEED := 2.4

var _pad: Control
var _buttons: Array = []         # dicts: id, label, action, kind ("tap" / "hold" / "toggle"), pos, r, on
var _touch := {}                 # touch index -> {"role": "stick" / "look" / button id, ...}
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _stick_index := -1
var _run_on := false
var _was_active := false


func _init() -> void:
	layer = 9                    # under the HUD's menus (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_define_buttons()


static func wanted() -> bool:
	match int(Settings.touch_controls):
		1: return true
		2: return false
	return DisplayServer.is_touchscreen_available()


func _define_buttons() -> void:
	_buttons = [
		{"id": "use", "label": "USE", "action": "interact", "kind": "tap", "r": 62.0, "modes": ["game", "dialogue", "overlay"]},
		{"id": "jump", "label": "JUMP", "action": "jump", "kind": "tap", "r": 50.0, "modes": ["game"]},
		{"id": "crouch", "label": "CROUCH", "action": "crouch", "kind": "tap", "r": 46.0, "modes": ["game"]},
		{"id": "run", "label": "RUN", "action": "sprint", "kind": "toggle", "r": 46.0, "modes": ["game"]},
		{"id": "picture", "label": "PICTURE", "action": "manifest", "kind": "hold", "r": 42.0, "modes": ["game"]},
		{"id": "wake", "label": "WAKE", "action": "wake", "kind": "hold", "r": 42.0, "modes": ["game"], "zones": ["city", "maze"]},
		{"id": "bite", "label": "BITE", "action": "use_item", "kind": "tap", "r": 40.0, "modes": ["game"], "holding": true},
		{"id": "drop", "label": "DROP", "action": "throw_item", "kind": "tap", "r": 40.0, "modes": ["game"], "holding": true},
		{"id": "menu", "label": "MENU", "action": "pause", "kind": "tap", "r": 34.0, "modes": ["game", "dialogue", "cinematic"]},
		{"id": "notes", "label": "NOTES", "action": "notebook", "kind": "tap", "r": 34.0, "modes": ["game", "overlay"]},
	]


func _layout() -> void:
	var s := _pad.size
	var spots := {
		"use": Vector2(s.x - 150, s.y - 170), "jump": Vector2(s.x - 300, s.y - 110),
		"crouch": Vector2(s.x - 110, s.y - 330), "run": Vector2(s.x - 260, s.y - 270),
		"picture": Vector2(s.x - 440, s.y - 100), "wake": Vector2(s.x - 410, s.y - 220),
		"bite": Vector2(s.x - 560, s.y - 100), "drop": Vector2(s.x - 540, s.y - 200),
		"menu": Vector2(s.x * 0.5 + 50, 56), "notes": Vector2(s.x * 0.5 - 50, 56),
	}
	for b in _buttons:
		b["pos"] = spots[b.id]


func _active() -> bool:
	return Game.player != null and wanted() and Game.mode in ["game", "dialogue", "overlay", "cinematic"] \
		and not Game.hud.menu_open()


func _shown(b: Dictionary) -> bool:
	if not Game.mode in b.modes:
		return false
	if b.has("zones") and not Game.zone_type in b.zones:
		return false
	if b.get("holding", false) and (Game.player == null or Game.player.manifestation.held == null):
		return false
	return true


func _process(_delta: float) -> void:
	var active := _active()
	if active != _was_active:
		_was_active = active
		if not active:
			_release_all()
	_pad.visible = active
	# tapping is clicking only where there is something to click
	Input.emulate_mouse_from_touch = not (active and Game.mode in ["game", "cinematic"])
	if active:
		_layout()
		_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		var t = _touch.get(event.index)
		if t == null:
			return
		if t.role == "stick":
			_stick_vec = (event.position - _stick_origin).limit_length(STICK_RADIUS) / STICK_RADIUS
			_apply_stick()
		elif t.role == "look" and Game.mode == "game":
			Game.player.look(event.relative * LOOK_SPEED)
		get_viewport().set_input_as_handled()


func _touch_down(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if _shown(b) and pos.distance_to(b.pos) <= b.r * 1.15:
			_touch[index] = {"role": b.id}
			_press_button(b, true)
			get_viewport().set_input_as_handled()
			return
	if Game.mode != "game":
		return          # menus and dialogue choices take the tap as a click
	if pos.x < _pad.size.x * 0.4 and _stick_index < 0:
		_stick_index = index
		_stick_origin = pos
		_stick_vec = Vector2.ZERO
		_touch[index] = {"role": "stick"}
	else:
		_touch[index] = {"role": "look"}
	get_viewport().set_input_as_handled()


func _touch_up(index: int) -> void:
	var t = _touch.get(index)
	_touch.erase(index)
	if t == null:
		return
	if t.role == "stick":
		_stick_index = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	elif t.role != "look":
		for b in _buttons:
			if b.id == t.role:
				_press_button(b, false)
	get_viewport().set_input_as_handled()


func _press_button(b: Dictionary, down: bool) -> void:
	match b.kind:
		"tap", "hold":
			_send(b.action, down)
			b["on"] = down
		"toggle":
			if down:
				_run_on = not _run_on
				_send(b.action, _run_on)
				b["on"] = _run_on


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _apply_stick() -> void:
	var v := _stick_vec
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_forward", -v.y], ["move_back", v.y]]:
		if pair[1] > 0.08:
			Input.action_press(pair[0], clampf(pair[1], 0.0, 1.0))
		else:
			Input.action_release(pair[0])


func _release_all() -> void:
	for t in _touch.values():
		if t.role != "stick" and t.role != "look":
			for b in _buttons:
				if b.id == t.role and b.kind != "toggle":
					_send(b.action, false)
					b["on"] = false
	_touch.clear()
	_stick_index = -1
	_stick_vec = Vector2.ZERO
	_apply_stick()
	if _run_on:
		_run_on = false
		_send("sprint", false)
		for b in _buttons:
			if b.id == "run":
				b["on"] = false


# ------------------------------------------------------------------ drawing

func _draw_pad() -> void:
	var font := ThemeDB.fallback_font
	var ink := Color(0.95, 0.94, 0.9)
	if _stick_index >= 0:
		_pad.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.07))
		_pad.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0, true)
		_pad.draw_circle(_stick_origin + _stick_vec * STICK_RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.3))
	elif Game.mode == "game":
		# a faint hint where the stick lives
		var hint := Vector2(200, _pad.size.y - 190)
		_pad.draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.1), 2.0, true)
		_pad.draw_string(font, hint + Vector2(-40, 6), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(1, 1, 1, 0.25))
	for b in _buttons:
		if not _shown(b):
			continue
		var on: bool = b.get("on", false)
		_pad.draw_circle(b.pos, b.r, Color(0.62, 0.71, 1.0, 0.45) if on else Color(0.05, 0.05, 0.08, 0.42))
		_pad.draw_arc(b.pos, b.r, 0, TAU, 40, Color(1, 1, 1, 0.45 if on else 0.28), 2.0, true)
		var fs := 17 if b.r > 40 else 14
		_pad.draw_string(font, b.pos + Vector2(-b.r, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, b.r * 2, fs, ink)
