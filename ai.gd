class_name EnemyPaddle
extends CharacterBody2D

enum State { RECOVER, REACT, TRACK }

@export var ball: Ball
@export var opponent: Node2D
@export var collision_shape: CollisionShape2D
@export var ball_radius: float = 8.0

@export_group("Movement")
@export var speed: float = 280.0
@export var acceleration: float = 2000.0
@export var responsiveness: float = 6.0
@export var damping: float = 2.0
@export var arrive_tolerance: float = 4.0

@export_group("Reading")
@export var reaction_delay: float = 0.15
@export_range(0, 3) var prediction_depth: int = 0
@export var base_aim_error: float = 40.0
@export var error_per_speed: float = 0.08

@export_group("Positioning")
@export_range(0.0, 1.0) var recenter_strength: float = 0.3

@export_group("Returns")
@export var return_speed: float = 0.8
@export_range(0.0, 1.0) var angle_aggression: float = 0.2
@export_range(0.0, 1.0) var steep_offset: float = 0.8
@export_range(0.0, 1.0) var casual_offset: float = 0.3

var _state := State.RECOVER
var _react_timer := 0.0
var _aim_error := 0.0
var _hit_offset := 0.0
var _recover_from_y := 0.0

var _locked_x : float

func _ready() -> void:
	_locked_x = global_position.x
	GameState.enemy = self
	ball = GameState.ball
	opponent = GameState.player
	_recover_from_y = global_position.y

func _physics_process(delta: float) -> void:
	var court := _get_court_rect()
	var approaching := _is_ball_approaching()

	match _state:
		State.RECOVER:
			if approaching:
				_state = State.REACT
				_react_timer = reaction_delay
		State.REACT:
			_react_timer -= delta
			if not approaching:
				_enter_recover()
			elif _react_timer <= 0.0:
				_start_tracking(court)
		State.TRACK:
			if not approaching:
				_enter_recover()

	var target_y: float
	if _state == State.TRACK:
		target_y = _predict_ball_y(court) + _aim_error - _hit_offset * _half_size().y
	else:
		target_y = lerpf(_recover_from_y, court.get_center().y, recenter_strength)
	
	var gap := target_y - global_position.y
	var desired := 0.0
	if absf(gap) > arrive_tolerance:
		# Damped: pull toward the target, minus a term that resists current speed.
		desired = clampf(gap * responsiveness - velocity.y * damping, -speed, speed)
	
	velocity.y = move_toward(velocity.y, desired, acceleration * delta)
	velocity.x = 0.0
	move_and_slide()
	
	global_position.x = _locked_x

func _enter_recover() -> void:
	_state = State.RECOVER
	_recover_from_y = global_position.y

func _start_tracking(court: Rect2) -> void:
	_state = State.TRACK
	var max_error := base_aim_error + error_per_speed * ball.get_motion().length()
	_aim_error = randf_range(-max_error, max_error)
	_hit_offset = _pick_hit_offset(court)

func _pick_hit_offset(court: Rect2) -> float:
	if randf() >= angle_aggression:
		return randf_range(-casual_offset, casual_offset)
	var dir := 1.0 if randf() < 0.5 else -1.0
	if opponent:
		dir = 1.0 if opponent.global_position.y < court.get_center().y else -1.0
	return dir * steep_offset

func _is_ball_approaching() -> bool:
	var vx := ball.get_motion().x
	return vx != 0.0 and signf(vx) == signf(global_position.x - ball.global_position.x)

func _predict_ball_y(court: Rect2) -> float:
	if prediction_depth == 0:
		return ball.global_position.y

	var v := ball.get_motion()
	var p := ball.global_position
	var face_x := global_position.x - signf(v.x) * (_half_size().x + ball_radius)
	var t := maxf((face_x - p.x) / v.x, 0.0)
	var y := p.y + v.y * t

	var top := court.position.y + ball_radius
	var bottom := court.end.y - ball_radius
	var bounces := prediction_depth
	while bounces > 0 and (y < top or y > bottom):
		y = 2.0 * top - y if y < top else 2.0 * bottom - y
		bounces -= 1
	return clampf(y, top, bottom)

func _half_size() -> Vector2:
	var rect := collision_shape.shape as RectangleShape2D
	return rect.size * 0.5 * collision_shape.global_scale

func _get_court_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
