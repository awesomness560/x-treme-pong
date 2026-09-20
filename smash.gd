class_name PaddleFlex
extends Line2D

@export var player: Paddle
@export var length: float = 100.0
@export_range(3, 32) var point_count: int = 7
@export var facing: float = 1.0 # 1 = ball comes from the right, -1 = from the left

@export_group("Logic")
@export var time_to_full: float = 0.6
@export var min_time_held: float = 0.15
@export var perfect_window: float = 0.1 # seconds before contact
@export var smash_window: float = 0.3
## Smash window while armed. Wider, so firing the ult is easier to land.
@export var armed_smash_window: float = 0.5
## Vertical half-range the ball must arrive within to be hittable.
@export var reach: float = 70.0

@export_group("Wind Up")
@export var max_bend: float = 12.0
@export var max_pullback: float = 4.0
@export var charge_brightness: float = 2.5

@export_group("Armed")
@export var armed_color: Color = Color(2.2, 1.6, 0.45)
## Beats per second. Match the ult bar's pulse so they read as one system.
@export var armed_pulse_speed: float = 1.6
## How far the gold dims at the bottom of the beat.
@export_range(0.0, 1.0) var armed_pulse_depth: float = 0.35
@export var armed_fade_time: float = 0.25

@export_group("Smash Animation")
@export var smash_bend: float = 14.0
@export var smash_lunge: float = 18.0
@export_range(0.0, 1.0) var rebound_amount: float = 0.5
@export var snap_time: float = 0.05
@export var rebound_time: float = 0.12
@export var settle_time: float = 0.3

@export_group("Hitstop")
@export var hitstop_scale: float = 0.05
@export var hitstop_time: float = 0.5

var time_held: float = 0.0

var bend: float = 0.0:
	set(value):
		bend = value
		_update_points()

var shift: float = 0.0:
	set(value):
		shift = value
		_update_points()

var _tween: Tween
var _hitstop_active := false
var _pending_perfect := false
## 0 = normal, 1 = fully gold. Tweened on arming so the change eases in.
var _armed_blend := 0.0
var _armed_tween: Tween
var _pulse_phase := 0.0

func _ready() -> void:
	_update_points()
	GameState.ball.paddle_hit.connect(_on_paddle_hit)
	GameState.ult_armed_changed.connect(_on_armed_changed)
	_armed_blend = 1.0 if GameState.ult_armed else 0.0
	self_modulate = _rest_color()

func _physics_process(delta: float) -> void:
	_pulse_phase += delta * armed_pulse_speed * TAU

	if Input.is_action_just_released("charge_up"):
		if time_held < min_time_held or not _in_vertical_reach():
			_on_whiff_or_cancel()
		else:
			_on_smash()
	elif Input.is_action_pressed("charge_up"):
		if is_animating():
			return # Recovery: can't charge while a smash is still playing.
		time_held = minf(time_held + delta, time_to_full)
		set_charge(time_held / time_to_full)
	elif not is_animating():
		# Idle: hold the resting colour, pulsing gold when armed.
		self_modulate = _rest_color()

# --- Colour ---

## The paddle's colour when it isn't charging: white, or a pulsing gold.
func _rest_color() -> Color:
	if _armed_blend <= 0.0:
		return Color.WHITE
	var beat := 0.5 + 0.5 * sin(_pulse_phase)
	var gold := Color.WHITE.lerp(armed_color, 1.0 - armed_pulse_depth * (1.0 - beat))
	return Color.WHITE.lerp(gold, _armed_blend)

func _on_armed_changed(armed: bool) -> void:
	if _armed_tween and _armed_tween.is_valid():
		_armed_tween.kill()
	if armed:
		_pulse_phase = 0.0
	_armed_tween = create_tween()
	_armed_tween.tween_property(self, "_armed_blend", 1.0 if armed else 0.0,
		armed_fade_time)

# --- Smash logic ---

func _on_whiff_or_cancel() -> void:
	time_held = 0.0
	_pending_perfect = false
	animate_relax()

func _on_smash() -> void:
	var t := time_to_impact()
	var armed := GameState.ult_armed
	var window := armed_smash_window if armed else smash_window

	if t < 0.0 or t > window:
		_on_whiff_or_cancel()
		return

	# Armed: the ult replaces the smash entirely, at full strength.
	if armed and GameState.ult_runner and GameState.ult_runner.activate():
		animate_smash(1.0)
		time_held = 0.0
		return

	var power := time_held / time_to_full
	var is_perfect := t <= perfect_window
	GameState.last_hit_perfect = is_perfect
	_pending_perfect = is_perfect

	GameState.ball.smash(power, is_perfect)
	animate_smash(power)
	time_held = 0.0

## Fires at actual contact, so the hitstop lands on the impact.
func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle != player:
		return
	if _pending_perfect:
		_pending_perfect = false
		_do_hitstop()

func _do_hitstop() -> void:
	if _hitstop_active or GameState.ult_active:
		return
	_hitstop_active = true
	Engine.time_scale = hitstop_scale
	# Timers run on scaled time, so scale the wait to get real seconds.
	await get_tree().create_timer(hitstop_time * hitstop_scale).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false

## Time until the ball reaches the paddle, or -1 if it isn't incoming.
func time_to_impact() -> float:
	var ball := GameState.ball
	var motion := ball.get_motion()
	var gap := (ball.global_position.x - global_position.x) * facing

	if gap < 0.0 or signf(motion.x) == facing:
		return -1.0
	return gap / absf(motion.x)

## Is the ball going to arrive close enough vertically to be hittable?
func _in_vertical_reach() -> bool:
	var ball := GameState.ball
	var t := time_to_impact()
	if t < 0.0:
		return false
	# Where the ball will be when it arrives, not where it is now.
	var arrival_y := ball.global_position.y + ball.get_motion().y * t
	return absf(arrival_y - global_position.y) <= reach

# --- Normalized control ---

## charge: 0 = flat, 1 = fully wound up. Cancels any running animation.
func set_charge(charge: float) -> void:
	kill_animation()
	charge = clampf(charge, 0.0, 1.0)
	bend = -charge * max_bend
	shift = -charge * max_pullback
	# Brighten the resting colour rather than fading toward white.
	var base := _rest_color()
	var lit := base * lerpf(1.0, charge_brightness, charge)
	lit.a = base.a
	self_modulate = lit

## amount: -1 = fully wound back, 0 = flat, 1 = fully lunged forward.
func set_flex(amount: float) -> void:
	kill_animation()
	amount = clampf(amount, -1.0, 1.0)
	if amount < 0.0:
		bend = amount * max_bend
		shift = amount * max_pullback
	else:
		bend = amount * smash_bend
		shift = amount * smash_lunge

# --- Tweened animations (call once, they play themselves) ---

## Winds up to `charge` over `time`.
func animate_charge(charge: float, time: float) -> void:
	kill_animation()
	charge = clampf(charge, 0.0, 1.0)
	var base := _rest_color()
	var lit := base * lerpf(1.0, charge_brightness, charge)
	lit.a = base.a
	_tween = create_tween()
	_add_step(-charge * max_bend, -charge * max_pullback, time,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "self_modulate", lit, time)

## Snap forward, rebound the other way, then settle flat. Scaled by `power` (0 to 1).
func animate_smash(power: float = 1.0) -> void:
	kill_animation()
	power = clampf(power, 0.0, 1.0)

	var forward_bend := power * smash_bend
	var forward_shift := power * smash_lunge

	_tween = create_tween()
	_add_step(forward_bend, forward_shift, snap_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_add_step(-forward_bend * rebound_amount, -forward_shift * rebound_amount,
		rebound_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_add_step(0.0, 0.0, settle_time, Tween.TRANS_SINE, Tween.EASE_OUT)
	_fade_glow(snap_time + rebound_time)

## Eases back to flat, for a cancelled charge or a whiff.
func animate_relax(time: float = 0.1) -> void:
	kill_animation()
	_tween = create_tween()
	_add_step(0.0, 0.0, time, Tween.TRANS_SINE, Tween.EASE_OUT)
	_fade_glow(time)

func is_animating() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

func kill_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

# --- Internals ---

func _add_step(to_bend: float, to_shift: float, time: float,
		trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_tween.tween_property(self, "bend", to_bend, time) \
		.set_trans(trans).set_ease(ease_type)
	_tween.parallel().tween_property(self, "shift", to_shift, time) \
		.set_trans(trans).set_ease(ease_type)

func _fade_glow(time: float) -> void:
	_tween.parallel().tween_property(self, "self_modulate", _rest_color(), time)

func _update_points() -> void:
	var new_points := PackedVector2Array()
	for i in point_count:
		var t := lerpf(-1.0, 1.0, float(i) / (point_count - 1))
		var x := (shift + bend * (1.0 - t * t)) * facing
		new_points.append(Vector2(x, t * length * 0.5))
	points = new_points
