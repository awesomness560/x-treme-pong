class_name DummyPaddle
extends CharacterBody2D

## Bare-bones stand-in for the main menu's background rally. Both dummies use
## this same script — the "player" vs "boss" feel comes entirely from the
## exported values on each instance, not from separate code.
##
## Plans each shot once, like ai.gd's TRACK state, and eases into it over the
## real flight time instead of chasing the ball's live position every frame —
## continuous tracking snaps hard every time the ball's y jumps at a bounce,
## which is what read as stiff. Always connects: no miss roll, no feint.

@export var ball: DummyBall
@export var collision_shape: CollisionShape2D
@export var ball_radius: float = 8.0

## Added to the planned intercept, so the two paddles don't aim for the exact
## same point on the ball.
@export var target_offset: float = 0.0

@export_group("Idle Drift")
## Drift speed back toward the resting spot between shots.
@export var recenter_speed: float = 3.0
@export_range(0.0, 1.0) var recenter_strength: float = 0.3

var _locked_x := 0.0
var _half := 0.0

var _tracking := false
var _start_y := 0.0
var _target_y := 0.0
var _shot_duration := 0.0
var _shot_elapsed := 0.0

## Smoothed position, eased toward its target during a shot and drifted
## toward the rest spot between shots — global_position.y just clamps this.
var _clean_y := 0.0
var _recover_from_y := 0.0

func _ready() -> void:
	_locked_x = global_position.x
	_half = _half_height()
	_clean_y = global_position.y
	_recover_from_y = global_position.y

func _physics_process(delta: float) -> void:
	if ball == null:
		return

	var approaching := _is_ball_approaching()

	if approaching and not _tracking:
		_plan_shot()
	elif not approaching and _tracking:
		_tracking = false
		_recover_from_y = _clean_y

	if _tracking:
		_shot_elapsed += delta
		var progress := clampf(_shot_elapsed / _shot_duration, 0.0, 1.0)
		_clean_y = lerpf(_start_y, _target_y, _ease(progress))
	else:
		var court := _get_court_rect()
		var home := lerpf(_recover_from_y, court.get_center().y, recenter_strength)
		_clean_y = lerpf(_clean_y, home, 1.0 - exp(-recenter_speed * delta))

	var court := _get_court_rect()
	global_position.y = clampf(_clean_y, court.position.y + _half, court.end.y - _half)
	global_position.x = _locked_x

## Reads where the ball's actually going to arrive and eases there over the
## real time left — called once per incoming shot, not re-rolled mid-flight.
func _plan_shot() -> void:
	_start_y = _clean_y
	var court := _get_court_rect()
	_target_y = clampf(_predict_intercept_y() + target_offset,
		court.position.y + _half, court.end.y - _half)
	_shot_duration = maxf(_time_to_arrival(), 0.001)
	_shot_elapsed = 0.0
	_tracking = true

## Smoothstep: eases in and out instead of snapping straight to the target.
func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _is_ball_approaching() -> bool:
	var vx := ball.get_motion().x
	return vx != 0.0 and signf(vx) == signf(global_position.x - ball.global_position.x)

func _time_to_arrival() -> float:
	var vx := ball.get_motion().x
	if absf(vx) < 1.0:
		return 1.0
	return maxf(absf(global_position.x - ball.global_position.x) / absf(vx), 0.001)

## Same mirror-off-the-walls prediction as ai.gd's _predict_ball_y().
func _predict_intercept_y() -> float:
	var court := _get_court_rect()
	var v := ball.get_motion()
	if absf(v.x) < 1.0:
		return ball.global_position.y

	var p := ball.global_position
	var face_x := global_position.x - signf(v.x) * (_half + ball_radius)
	var t := maxf((face_x - p.x) / v.x, 0.0)
	var y := p.y + v.y * t

	var top := court.position.y + ball_radius
	var bottom := court.end.y - ball_radius
	var span := bottom - top
	if span > 0.0:
		var folded := fposmod(y - top, span * 2.0)
		y = top + (folded if folded <= span else span * 2.0 - folded)
	return y

func _half_height() -> float:
	var rect := collision_shape.shape as RectangleShape2D
	return rect.size.y * 0.5 * collision_shape.global_scale.y

func _get_court_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
