extends Node
## Player options (including the accessibility controls for horror intensity) and input bindings.
## Stored in user://settings.cfg, separate from progress.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0
var invert_y := false
var fov := 80.0
var head_bob := true
var camera_effects := true
## 0..1: vignette/grain/desaturation/flicker depth/red flash.
var visual_intensity := 1.0
## Epilepsy-safe mode: no flashing, strobing or flicker anywhere (overrides visual_intensity's flashing parts).
var epilepsy_safe := false
## 0..1: drone, knocks, hum intensity.
var audio_intensity := 1.0
var master_volume := 0.8
var music_volume := 0.6
var text_scale := 1.0
var show_dread_meter := true
var menu_corruption := true
var self_unpause := true
## 0 = low (fast, for older Macs), 1 = high (SDFGI, volumetric fog, SSAO).
var quality := 1.0
## Every expensive effect on: global illumination, reflections, volumetric fog, MSAA + TAA. Needs a strong GPU.
var super_shaders := false
var show_objectives := true
## How many times the waking-up sequence has been seen (after the first, it can be skipped).
var deaths_seen := 0
## On-screen touch controls: 0 = automatic (when there is a touch screen), 1 = always, 2 = never.
var touch_controls := 0.0
## 0 = English, 1 = 한국어 (see Loc). Until it's chosen, it follows the system / browser language.
var language := 1.0 if OS.get_locale_language() == "ko" else 0.0

const KEYS := ["mouse_sensitivity", "invert_y", "fov", "head_bob", "camera_effects", "visual_intensity",
	"audio_intensity", "master_volume", "music_volume", "text_scale", "show_dread_meter", "menu_corruption", "self_unpause", "quality", "super_shaders", "show_objectives", "deaths_seen", "touch_controls", "language", "epilepsy_safe"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in KEYS:
			set(k, cfg.get_value("settings", k, get(k)))
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in KEYS:
		cfg.set_value("settings", k, get(k))
	cfg.save(PATH)


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X if super_shaders else Viewport.MSAA_DISABLED
		vp.use_taa = super_shaders
	changed.emit()


## How strong flashing/flicker/distortion effects may be: 0 in epilepsy-safe mode.
func visual() -> float:
	return 0.0 if epilepsy_safe else visual_intensity


## May lights flicker, spark or strobe at all?
func flashing_ok() -> bool:
	return not epilepsy_safe


func set_value(key: String, value) -> void:
	set(key, value)
	save_settings()
	apply()


# ------------------------------------------------------------------ input

func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _axis(axis: JoyAxis, dir: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	return e


func _setup_input() -> void:
	_add("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1)])
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1)])
	_add("look_left", [_axis(JOY_AXIS_RIGHT_X, -1)])
	_add("look_right", [_axis(JOY_AXIS_RIGHT_X, 1)])
	_add("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1)])
	_add("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1)])
	_add("jump", [_key(KEY_SPACE), _pad(JOY_BUTTON_A)])
	_add("sprint", [_key(KEY_SHIFT), _pad(JOY_BUTTON_LEFT_STICK)])
	_add("crouch", [_key(KEY_CTRL), _key(KEY_C), _pad(JOY_BUTTON_RIGHT_STICK)])
	_add("interact", [_key(KEY_E), _key(KEY_F), _pad(JOY_BUTTON_X)])
	_add("manifest", [_key(KEY_Q), _pad(JOY_BUTTON_LEFT_SHOULDER)])
	_add("use_item", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1)])
	_add("throw_item", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1)])
	_add("cycle_next", [_mouse(MOUSE_BUTTON_WHEEL_UP), _pad(JOY_BUTTON_DPAD_RIGHT)])
	_add("cycle_prev", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _pad(JOY_BUTTON_DPAD_LEFT)])
	_add("wake", [_key(KEY_T), _pad(JOY_BUTTON_DPAD_UP)])
	_add("notebook", [_key(KEY_N), _key(KEY_TAB), _pad(JOY_BUTTON_BACK)])
	_add("pause", [_key(KEY_ESCAPE), _key(KEY_P), _pad(JOY_BUTTON_START)])
	_add("choice_1", [_key(KEY_1)])
	_add("choice_2", [_key(KEY_2)])
	_add("choice_3", [_key(KEY_3)])
	_add("choice_4", [_key(KEY_4)])
	_add("choice_5", [_key(KEY_5)])
