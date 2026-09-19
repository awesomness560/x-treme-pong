class_name EnemyPaddle
extends CharacterBody2D

enum State { RECOVER, REACT, TRACK }

@export var ball: Ball
@export var opponent: Node2D
@export var collision_shape: CollisionShape2D
@export var ball_radius: float = 8.0

@export_group("Movement")
@export var speed: float = 1200.0
@export var acceleration: float = 6000.0
@export var responsiveness: float = 6.0
@export var damping: float = 2.0
@export var arrive_tolerance: float = 4.0
@export var reaction_delay: float = 0.15

@export_group("Miss Chance")
@export_range(0.0, 1.0) var base_miss: float = 0.25
## Added miss chance per 100 px/s above the comfortable speed.
@export var speed_factor: float = 0.04
@export var comfortable_speed: float = 650.0
## Added miss chance per 10 degrees of shot angle.
@export var angle_factor: float = 0.03
@export_range(0.0, 1.0) var perfect_bonus: float = 0.2
## Subtracted from the total. Raise per round to make the boss better.
@export_range(0.0, 1.0) var skill: float = 0.0
@export_range(0.0, 1.0) var miss_chance_cap: float = 0.85

@export_group("Miss Margin")
## How far past the paddle edge a miss lands, as a fraction of paddle height.
@export var min_miss_margin: float = 0.15
@export var max_miss_margin: float = 0.9
@export var margin_max_at_speed: float = 1000.0

@export_group("Human Feel")
## 0 = shadow the ball's height, 1 = go straight to the interception point.
@export var commit_curve: float = 2.0
## Fraction of available time it aims to use. Below 1 it arrives early.
@export_range(0.3, 1.0) var pacing: float = 0.85
@export var idle_sway_amount: float = 6.0
@export var idle_sway_speed: float = 1.7
@export var wander_amount: float = 18.0
@export var wander_speed: float = 0.4
@export_range(0.0, 1.0) var feint_chance: float = 0.25
@export var feint_amount: float = 90.0
@export_range(0.0, 1.0) var feint_duration: float = 0.45

@export_group("Returns")
@export var return_speed: float = 0.8
@export_range(0.0, 1.0) var angle_aggression: float = 0.2
@export_range(0.0, 1.0) var steep_offset: float = 0.8
@export_range(0.0, 1.0) var casual_offset: float = 0.3

@export_group("Positioning")
@export_range(0.0, 1.0) var recenter_strength: float = 0.3

@export_group("Debug")
## A Label or RichTextLabel to print roll info to. Leave empty to skip.
@export var debug_label: Control
@export var debug_enabled: bool = true

var last_miss_chance := 0.0
var will_miss := false

var _state := State.RECOVER
var _react_timer := 0.0
var _aim_offset := 0.0
var _hit_offset := 0.0
var _recover_from_y := 0.0
var _locked_x := 0.0
var _feint := 0.0
var _shot_duration := 0.0
var _noise_seed := 0.0

var _roll_count := 0

func _ready() -> void:
	GameState.enemy = self
	ball = GameState.ball
	opponent = GameState.player
	_recover_from_y = global_position.y
	_locked_x = global_position.x
	_noise_seed = randf() * 100.0
	ball.paddle_hit.connect(_on_paddle_hit)

# --- The dice roll ---

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == self:
		return
	_roll_for_shot()

func _roll_for_shot() -> void:
	var incoming_speed := ball.get_horizontal_speed()
	var angle_deg := absf(rad_to_deg(ball.get_motion().angle()))
	if angle_deg > 90.0:
		angle_deg = 180.0 - angle_deg # Measure from horizontal either way.

	var chance := base_miss
	chance += speed_factor * (incoming_speed - comfortable_speed) / 100.0
	chance += angle_factor * angle_deg / 10.0
	if GameState.last_hit_perfect:
		chance += perfect_bonus
	chance -= skill

	last_miss_chance = clampf(chance, 0.0, miss_chance_cap)
	will_miss = randf() < last_miss_chance

	if will_miss:
		var t := clampf(inverse_lerp(comfortable_speed, margin_max_at_speed,
			incoming_speed), 0.0, 1.0)
		var margin := lerpf(min_miss_margin, max_miss_margin, t)
		var side := 1.0 if randf() < 0.5 else -1.0
		# Clear the paddle edge and the ball, then miss by `margin` paddle-heights.
		var clearance := _half_size().y + ball_radius
		_aim_offset = side * (clearance + margin * _half_size().y * 2.0)
		_hit_offset = 0.0
	else:
		_aim_offset = 0.0
		_hit_offset = _pick_hit_offset()

	_shot_duration = _time_to_arrival()
	_feint = 0.0
	if randf() < feint_chance:
		var away := -signf(_predict_ball_y(_get_court_rect()) - global_position.y)
		if away == 0.0:
			away = 1.0 if randf() < 0.5 else -1.0
		_feint = away * feint_amount

	_state = State.REACT
	_react_timer = reaction_delay
	
	_roll_count += 1
	_write_debug(incoming_speed, angle_deg)

# --- Movement ---

func _physics_process(delta: float) -> void:
	var court := _get_court_rect()
	var approaching := _is_ball_approaching()

	match _state:
		State.REACT:
			_react_timer -= delta
			if not approaching:
				_enter_recover()
			elif _react_timer <= 0.0:
				_state = State.TRACK
		State.TRACK:
			if not approaching:
				_enter_recover()

	var target_y: float
	if _state == State.TRACK:
		var predicted := _predict_ball_y(court) + _aim_offset - _hit_offset * _half_size().y
		var remaining := _time_to_arrival()

		# Commit gradually: shadow the ball early, converge on the real spot late.
		var progress := 1.0 - clampf(remaining / maxf(_shot_duration, 0.001), 0.0, 1.0)
		target_y = lerpf(ball.global_position.y, predicted, pow(progress, commit_curve))

		# Feint decays over the first part of the shot.
		if _feint != 0.0:
			target_y += _feint * clampf(1.0 - progress / feint_duration, 0.0, 1.0)
	else:
		target_y = lerpf(_recover_from_y, court.get_center().y, recenter_strength)

	# Never quite still.
	var t_now := Time.get_ticks_msec() / 1000.0 + _noise_seed
	target_y += sin(t_now * idle_sway_speed * TAU) * idle_sway_amount
	target_y += sin(t_now * wander_speed * TAU) * wander_amount

	var gap := target_y - global_position.y
	var desired := 0.0
	if absf(gap) > arrive_tolerance:
		desired = gap * responsiveness - velocity.y * damping
		# Pace it: only move fast enough to arrive roughly on time.
		if _state == State.TRACK:
			var budget := maxf(_time_to_arrival() * pacing, 0.05)
			var pace_limit := absf(gap) / budget
			desired = clampf(desired, -pace_limit, pace_limit)
		desired = clampf(desired, -speed, speed)

	velocity.y = move_toward(velocity.y, desired, acceleration * delta)
	velocity.x = 0.0
	move_and_slide()
	global_position.x = _locked_x

func _enter_recover() -> void:
	_state = State.RECOVER
	_recover_from_y = global_position.y
	will_miss = false
	_feint = 0.0

func _pick_hit_offset() -> float:
	if randf() >= angle_aggression:
		return randf_range(-casual_offset, casual_offset)
	var court := _get_court_rect()
	var dir := 1.0 if randf() < 0.5 else -1.0
	if opponent:
		dir = 1.0 if opponent.global_position.y < court.get_center().y else -1.0
	return dir * steep_offset

func _is_ball_approaching() -> bool:
	var vx := ball.get_motion().x
	return vx != 0.0 and signf(vx) == signf(global_position.x - ball.global_position.x)

func _time_to_arrival() -> float:
	var vx := ball.get_motion().x
	if absf(vx) < 1.0:
		return 1.0
	return maxf(absf(global_position.x - ball.global_position.x) / absf(vx), 0.001)

## Always predicts properly. Missing is decided by the roll, not by bad reading.
func _predict_ball_y(court: Rect2) -> float:
	var v := ball.get_motion()
	if absf(v.x) < 1.0:
		return ball.global_position.y

	var p := ball.global_position
	var face_x := global_position.x - signf(v.x) * (_half_size().x + ball_radius)
	var t := maxf((face_x - p.x) / v.x, 0.0)
	var y := p.y + v.y * t

	# Mirror off the top and bottom walls as many times as needed.
	var top := court.position.y + ball_radius
	var bottom := court.end.y - ball_radius
	var span := bottom - top
	if span > 0.0:
		var folded := fposmod(y - top, span * 2.0)
		y = top + (folded if folded <= span else span * 2.0 - folded)
	return y

func _write_debug(incoming_speed: float, angle_deg: float) -> void:
	if not debug_enabled or debug_label == null:
		return

	# Each term, so you can see what's driving the number.
	var speed_term := speed_factor * (incoming_speed - comfortable_speed) / 100.0
	var angle_term := angle_factor * angle_deg / 10.0
	var perfect_term := perfect_bonus if GameState.last_hit_perfect else 0.0

	var lines := [
		"Roll #%d: %s" % [_roll_count, "MISS" if will_miss else "HIT"],
		"Miss chance: %.1f%%" % (last_miss_chance * 100.0),
		"  base:    %+.3f" % base_miss,
		"  speed:   %+.3f  (%.0f px/s)" % [speed_term, incoming_speed],
		"  angle:   %+.3f  (%.1f deg)" % [angle_term, angle_deg],
		"  perfect: %+.3f" % perfect_term,
		"  skill:   %+.3f" % -skill,
	]
	if will_miss:
		lines.append("Miss margin: %.0f px" % _aim_offset)
	if _feint != 0.0:
		lines.append("Feint: %+.0f px" % _feint)

	debug_label.set("text", "\n".join(lines))

func _half_size() -> Vector2:
	var rect := collision_shape.shape as RectangleShape2D
	return rect.size * 0.5 * collision_shape.global_scale

func _get_court_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
