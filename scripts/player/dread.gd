class_name Dread
extends Node
## DREAD = the player's FEAR combined with the dream's STABILITY.
##
##   fear rises -> stability falls toward (100 - fear) -> anomalies speed up -> more fear
##
## Fear decays after a calm spell (down to the zone's floor). Stability falls fast and recovers slowly,
## so a frightened dream stays broken for a while. Zones set a profile: the summer city damps fear
## gains so the opening stays comforting. One look over the shoulder is never punished; only
## repeatedly checking behind you is.

signal stage_changed(old_stage: int, new_stage: int)
signal overwhelmed
signal turned_around

enum Stage { CALM, UNEASY, AFRAID, TERRIFIED, OVERWHELMED }
const STAGE_NAMES := ["CALM", "UNEASY", "AFRAID", "TERRIFIED", "OVERWHELMED"]

# Tuning, kept in one place.
const FEAR_WEIGHT := 0.65
const INSTABILITY_WEIGHT := 0.35
const CALM_DELAY := 5.0
const STABILITY_FALL := 6.0
const STABILITY_PANIC_FALL := 11.0
const STABILITY_RECOVER := 1.2
const TURN_WINDOW := 0.45
const TURN_DEGREES := 135.0
const TURN_COOLDOWN := 1.0
const CHECKING_WINDOW := 12.0
const CHECKING_COUNT := 3
const SUSPICIOUS_WINDOW := 4.0

var fear := 0.0
var stability := 100.0
var stage := Stage.CALM

var nightmare := false
var gain := 1.0
var _last_trickle := -100.0
## Fear added so far, by reason (debugging the balance).
var trickles := {}
var floor_fear := 0.0
var decay := 1.5

var _t := 0.0
var _last_fear := -100.0
var _last_suspicious := -100.0
var _last_turn := -100.0
var _yaw_hist: Array = []   # [time, unwrapped yaw]
var _unwrapped := 0.0
var _prev_yaw := 0.0
var _has_yaw := false
var _turns: Array[float] = []
var _overwhelm_fired := false


func value() -> float:
	return clampf(fear * FEAR_WEIGHT + (100.0 - stability) * INSTABILITY_WEIGHT, 0.0, 100.0)


func alpha() -> float:
	return value() / 100.0


static func stage_for(v: float) -> int:
	if v >= 99.5: return Stage.OVERWHELMED
	if v >= 75.0: return Stage.TERRIFIED
	if v >= 50.0: return Stage.AFRAID
	if v >= 25.0: return Stage.UNEASY
	return Stage.CALM


func stage_name() -> String:
	return STAGE_NAMES[stage]


func add_fear(amount: float, reason := "") -> void:
	if amount > 0.0:
		amount *= gain
		# a jolt (a scare, a sound) holds off the calm-down; a steady trickle (per-frame sources like
		# looking down a drop) doesn't - it just outpaces the decay while it lasts, and stops when you stop
		if amount >= 0.5:
			_last_fear = _t
		else:
			_last_trickle = _t
		if reason != "":
			trickles[reason] = float(trickles.get(reason, 0.0)) + amount
	fear = clampf(fear + amount, 0.0, 100.0)


## Raise the DREAD meter itself by `amount` points (fear up, stability down; not scaled by the zone).
func add_dread(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 100.0)
	stability = clampf(stability - amount, 0.0, 100.0)
	_last_fear = _t


func add_stability(delta: float) -> void:
	stability = clampf(stability + delta, 0.0, 100.0)


func set_values(f: float, s: float) -> void:
	fear = clampf(f, 0.0, 100.0)
	stability = clampf(s, 0.0, 100.0)
	stage = stage_for(value())
	_overwhelm_fired = false
	_turns.clear()


func set_profile(is_nightmare: bool, fear_gain: float, fear_floor: float, decay_per_second: float) -> void:
	nightmare = is_nightmare
	gain = fear_gain
	floor_fear = fear_floor
	decay = decay_per_second


func notify_suspicious() -> void:
	_last_suspicious = _t


func _process(delta: float) -> void:
	_t += delta
	_track_look_behind()

	if _t - _last_fear > CALM_DELAY and _t - _last_trickle > 0.3 and fear > floor_fear:
		fear = maxf(floor_fear, fear - decay * delta)
	elif fear < floor_fear:
		fear = minf(floor_fear, fear + 0.5 * delta)

	var target := 100.0 - fear
	if stability > target:
		stability = maxf(target, stability - (STABILITY_PANIC_FALL if fear > 70.0 else STABILITY_FALL) * delta)
	else:
		var calm := _t - _last_fear > CALM_DELAY
		stability = minf(target, stability + STABILITY_RECOVER * (2.5 if calm else 1.0) * delta)

	var v := value()
	var s := stage_for(v)
	if s != stage:
		var old := stage
		stage = s
		stage_changed.emit(old, s)
	if s == Stage.OVERWHELMED and not _overwhelm_fired and nightmare:
		_overwhelm_fired = true
		overwhelmed.emit()
	elif v < 80.0:
		_overwhelm_fired = false


func _track_look_behind() -> void:
	var p := get_parent() as Node3D
	if p == null:
		return
	var yaw := rad_to_deg(p.rotation.y)
	if not _has_yaw:
		_has_yaw = true
		_prev_yaw = yaw
	_unwrapped += wrapf(yaw - _prev_yaw, -180.0, 180.0)
	_prev_yaw = yaw
	_yaw_hist.append([_t, _unwrapped])
	while _yaw_hist.size() > 1 and _t - _yaw_hist[0][0] > TURN_WINDOW:
		_yaw_hist.pop_front()
	if _yaw_hist.size() < 2 or _t - _last_turn < TURN_COOLDOWN:
		return
	if absf(_unwrapped - _yaw_hist[0][1]) < TURN_DEGREES:
		return

	_last_turn = _t
	_yaw_hist.clear()
	turned_around.emit()
	if not nightmare:
		return  # never punish looking around in safe places
	_turns.append(_t)
	_turns = _turns.filter(func(x): return _t - x <= CHECKING_WINDOW)
	if _turns.size() >= CHECKING_COUNT:
		add_fear(4.0 + 2.0 * (_turns.size() - CHECKING_COUNT), "checking behind")
	elif _t - _last_suspicious < SUSPICIOUS_WINDOW:
		add_fear(3.0, "startled turn")
