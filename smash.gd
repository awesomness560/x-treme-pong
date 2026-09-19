class_name PaddleFlex
extends Line2D

@export var player : Paddle
@export var length: float = 100.0
@export_range(3, 32) var point_count: int = 7
@export var facing: float = 1.0 # 1 = ball comes from the right, -1 = from the left

@export_group("Logic")
@export var time_to_full : float = 0.6
@export var min_time_held : float = 0.15
@export var perfect_window: float = 0.1 # seconds before contact
@export var smash_window: float = 0.3
@export var speed_slowdown : float = 0.7
@export var smash_multiplier: float = 4
@export var perfect_multiplier: float = 10

@export_group("Wind Up")
@export var max_bend: float = 12.0
@export var max_pullback: float = 4.0
@export var glow_color: Color = Color(2.5, 2.5, 2.5)

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

var time_held : float = 0.0
var _hitstop_active := false

#WARNING: If the ball enters here and dies this might fuck us over
var ball_in_area : bool = false

var bend: float = 0.0:
	set(value):
		bend = value
		_update_points()

var shift: float = 0.0:
	set(value):
		shift = value
		_update_points()

var _tween: Tween

func _ready() -> void:
	_update_points()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_released("charge_up"):
		if time_held < min_time_held or not ball_in_area:
			_on_whiff_or_cancel()
		else:
			_on_smash()
	elif Input.is_action_pressed("charge_up"):
		if is_animating():
			return # Recovery: can't charge while a smash is still playing.
		time_held = minf(time_held + delta, time_to_full)
		set_charge(time_held / time_to_full)

func _on_whiff_or_cancel() -> void:
	time_held = 0.0
	animate_relax()

func _on_smash() -> void:
	var power := time_held / time_to_full
	var t := time_to_impact()

	if t < 0.0 or t > smash_window:
		_on_whiff_or_cancel()
		return

	var multiplier := perfect_multiplier if t <= perfect_window else smash_multiplier
	if multiplier == perfect_multiplier:
		_on_perfect()
	else:
		GameState.last_hit_perfect = false
	GameState.ball.smash(lerpf(1.0, multiplier, power))

	animate_smash(power)
	time_held = 0.0

func _on_perfect():
	GameState.last_hit_perfect = true
	_do_hitstop()

func _do_hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = hitstop_scale
	# Timers run on scaled time, so scale the wait to get real seconds.
	await get_tree().create_timer(hitstop_time * hitstop_scale).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false

## charge: 0 = flat, 1 = fully wound up. Cancels any running animation.
func set_charge(charge: float) -> void:
	kill_animation()
	charge = clampf(charge, 0.0, 1.0)
	bend = -charge * max_bend
	shift = -charge * max_pullback
	self_modulate = Color.WHITE.lerp(glow_color, charge)

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
	_tween = create_tween()
	_add_step(-charge * max_bend, -charge * max_pullback, time,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "self_modulate",
		Color.WHITE.lerp(glow_color, charge), time)

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
	_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, time)

func _update_points() -> void:
	var new_points := PackedVector2Array()
	for i in point_count:
		var t := lerpf(-1.0, 1.0, float(i) / (point_count - 1))
		var x := (shift + bend * (1.0 - t * t)) * facing
		new_points.append(Vector2(x, t * length * 0.5))
	points = new_points

## Time until the ball reaches the paddle, or -1 if it isn't incoming.
func time_to_impact() -> float:
	var ball := GameState.ball
	var motion := ball.get_motion()
	var gap := (ball.global_position.x - global_position.x) * facing

	if gap < 0.0 or signf(motion.x) == facing:
		return -1.0
	return gap / absf(motion.x)

func _on_hit_area_body_entered(body: Node2D) -> void:
	if body is Ball:
		ball_in_area = true

func _on_hit_area_body_exited(body: Node2D) -> void:
	if body is Ball:
		ball_in_area = false
