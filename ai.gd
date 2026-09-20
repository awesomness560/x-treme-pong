class_name EnemyPaddle
extends CharacterBody2D

enum State { RECOVER, REACT, TRACK }

@export var ball: Ball
@export var opponent: Node2D
@export var collision_shape: CollisionShape2D
@export var ball_radius: float = 8.0
@export var visuals : ColorRect
@export var death_particles: CPUParticles2D

@export_group("Timing")
@export var reaction_delay: float = 0.15
## Drift speed back toward the resting spot between shots.
@export var recenter_speed: float = 4.0
@export_range(0.0, 1.0) var recenter_strength: float = 0.3

@export_group("Miss Chance")
@export_range(0.0, 1.0) var base_miss: float = 0.1
## Miss chance added at max ball speed.
@export_range(0.0, 1.0) var speed_miss_max: float = 0.8
## Higher keeps low speeds safe and makes the top end sharp.
@export_range(1.0, 5.0) var speed_miss_exponent: float = 1.8
## Extra miss chance a smash adds at max speed. Near zero at low speeds.
@export_range(0.0, 1.0) var smash_miss_max: float = 0.35
## Higher keeps low-speed smashes safe and makes fast ones lethal.
@export_range(1.0, 5.0) var smash_miss_exponent: float = 3.0
## Miss chance added when the shot needs a full court-height reach.
@export_range(0.0, 1.0) var distance_miss_max: float = 0.45
@export_range(1.0, 4.0) var distance_miss_exponent: float = 2.0
@export var angle_factor: float = 0.03
@export_range(0.0, 1.0) var perfect_bonus: float = 0.15
## Subtracted from the total. Raise per round to make the boss better.
@export_range(0.0, 1.0) var skill: float = 0.0
@export_range(0.0, 1.0) var miss_chance_cap: float = 0.9
@export var guarantee_after_damage: bool = true
@export_group("Miss Margin")
## Margin at a 0% roll: a near thing. In paddle heights past the edge.
@export var min_miss_margin: float = 0.1
## Margin at a 100% roll: beaten badly.
@export var max_miss_margin: float = 1.2

@export_group("Human Feel")
## How wrong the boss's first read is, in paddle heights.
@export var read_error: float = 0.9
## Fraction of the flight spent on the first read before correcting.
@export_range(0.1, 0.9) var read_phase: float = 0.55
@export_range(0.0, 1.0) var feint_chance: float = 0.25
@export var feint_amount: float = 90.0
@export_range(0.0, 1.0) var feint_duration: float = 0.45

@export_group("Returns")
@export_range(0.0, 1.0) var angle_aggression: float = 0.2
@export_range(0.0, 1.0) var steep_offset: float = 0.8
@export_range(0.0, 1.0) var casual_offset: float = 0.3

@export_group("Debug")
## A Label or RichTextLabel to print roll info to. Leave empty to skip.
@export var debug_label: Control
@export var debug_enabled: bool = true

var last_miss_chance := 0.0
var will_miss := false

var _state := State.RECOVER
var _react_timer := 0.0
var _hit_offset := 0.0
var _recover_from_y := 0.0
var _locked_x := 0.0
var _feint := 0.0
var _roll_count := 0
var _guaranteed_return := false

# The planned shot.
var _clean_y := 0.0
var _start_y := 0.0
var _read_y := 0.0
var _final_y := 0.0
var _shot_duration := 0.0
var _shot_elapsed := 0.0
var _needed_travel := 0.0
var _distance_term := 0.0
var _speed_term := 0.0
var _angle_term := 0.0

func _ready() -> void:
	GameState.enemy = self
	ball = GameState.ball
	opponent = GameState.player
	_clean_y = global_position.y
	_recover_from_y = global_position.y
	_locked_x = global_position.x
	ball.paddle_hit.connect(_on_paddle_hit)
	GameState.take_damage.connect(_on_border_damaged)
	GameState.boss_dead.connect(_on_death)

func _on_death():
	visuals.hide()
	death_particles.emitting = true
	await death_particles.finished
	queue_free()

# --- The roll ---

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == self:
		return
	_roll_for_shot()

func _roll_for_shot() -> void:
	var court := _get_court_rect()
	var intercept := _predict_ball_y(court)

	# How far it has to reach, as a fraction of the court height.
	_needed_travel = absf(intercept - global_position.y)
	var reach := clampf(_needed_travel / maxf(court.size.y, 1.0), 0.0, 1.0)

	var angle_deg := absf(rad_to_deg(ball.get_motion().angle()))
	if angle_deg > 90.0:
		angle_deg = 180.0 - angle_deg

	# Speed and reach both flat at the low end, steep at the top.
	_speed_term = speed_miss_max * pow(ball.get_speed_ratio(), speed_miss_exponent)
	_distance_term = distance_miss_max * pow(reach, distance_miss_exponent)
	_angle_term = angle_factor * angle_deg / 10.0
	var _smash_term := 0.0

	# Smashes only really threaten the boss once the ball is fast.
	if GameState.last_hit_was_smash:
		_smash_term = smash_miss_max * pow(ball.get_speed_ratio(), smash_miss_exponent)

	var chance := base_miss + _speed_term + _smash_term + _distance_term + _angle_term
	if GameState.last_hit_perfect:
		chance += perfect_bonus
	chance -= skill

	last_miss_chance = clampf(chance, 0.0, miss_chance_cap)

	if _guaranteed_return:
		will_miss = false
		_guaranteed_return = false
	else:
		will_miss = randf() < last_miss_chance

	_hit_offset = 0.0 if will_miss else _pick_hit_offset()

	_feint = 0.0
	if randf() < feint_chance:
		var away := -signf(intercept - global_position.y)
		if away == 0.0:
			away = 1.0 if randf() < 0.5 else -1.0
		_feint = away * feint_amount

	_state = State.REACT
	_react_timer = reaction_delay

	_roll_count += 1
	_write_debug(angle_deg)

## Sets the destination and the first rough read. Called when tracking starts,
## so the time budget is honest.
func _plan_path() -> void:
	var court := _get_court_rect()
	var half := _half_size().y
	var intercept := _predict_ball_y(court)

	if will_miss:
		# Beaten worse the less likely the return was.
		var margin := lerpf(min_miss_margin, max_miss_margin, last_miss_chance)
		var side := 1.0 if randf() < 0.5 else -1.0
		_final_y = intercept + side * (half + ball_radius + margin * half * 2.0)
	else:
		_final_y = intercept - _hit_offset * half

	_final_y = clampf(_final_y, court.position.y + half, court.end.y - half)
	_needed_travel = absf(_final_y - _start_y)

	# The boss's first, imperfect read of where the ball is going.
	var err := randf_range(-read_error, read_error) * half
	_read_y = clampf(_final_y + err, court.position.y + half, court.end.y - half)

## The border took a hit: no free farming off the rebound.
func _on_border_damaged(_amount: float) -> void:
	if guarantee_after_damage:
		_guaranteed_return = true

# --- Movement: a scheduled path, so arrival is exact ---

func _physics_process(delta: float) -> void:
	var court := _get_court_rect()
	var half := _half_size().y
	var approaching := _is_ball_approaching()

	match _state:
		State.REACT:
			_react_timer -= delta
			if not approaching:
				_enter_recover()
			elif _react_timer <= 0.0:
				_state = State.TRACK
				_shot_elapsed = 0.0
				_start_y = _clean_y
				# Fresh clock: whatever time is genuinely left.
				_shot_duration = maxf(_time_to_arrival(), 0.001)
				_plan_path()
		State.TRACK:
			if not approaching:
				_enter_recover()

	if _state == State.TRACK:
		_shot_elapsed += delta
		var progress := clampf(_shot_elapsed / _shot_duration, 0.0, 1.0)

		if progress < read_phase:
			# First leg: move to the rough read.
			_clean_y = lerpf(_start_y, _read_y, _ease(progress / read_phase))
		else:
			# Second leg: correct onto the real spot.
			_clean_y = lerpf(_read_y, _final_y,
				_ease((progress - read_phase) / (1.0 - read_phase)))

		var offset := 0.0
		if _feint != 0.0:
			offset = _feint * clampf(1.0 - progress / feint_duration, 0.0, 1.0)

		global_position.y = clampf(_clean_y + offset,
			court.position.y + half, court.end.y - half)
	else:
		# Between shots: drift to the resting spot and stay put.
		var home := lerpf(_recover_from_y, court.get_center().y, recenter_strength)
		_clean_y = lerpf(_clean_y, home, 1.0 - exp(-recenter_speed * delta))
		global_position.y = clampf(_clean_y, court.position.y + half, court.end.y - half)

	global_position.x = _locked_x

## Hesitate, commit, settle. Swap this to change how the boss "feels".
func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x) # smoothstep

func _enter_recover() -> void:
	_state = State.RECOVER
	_recover_from_y = global_position.y
	_clean_y = global_position.y
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

func _half_size() -> Vector2:
	var rect := collision_shape.shape as RectangleShape2D
	return rect.size * 0.5 * collision_shape.global_scale

func _get_court_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

# --- Debug ---

func _write_debug(angle_deg: float) -> void:
	if not debug_enabled or debug_label == null:
		return

	var perfect_term := perfect_bonus if GameState.last_hit_perfect else 0.0

	var lines := [
		"Roll #%d: %s" % [_roll_count, "MISS" if will_miss else "HIT"],
		"Miss chance: %.1f%%" % (last_miss_chance * 100.0),
		"  base:     %+.3f" % base_miss,
		"  speed:    %+.3f  (ratio %.2f)" % [_speed_term, ball.get_speed_ratio()],
		"  distance: %+.3f  (%.0f px reach)" % [_distance_term, _needed_travel],
		"  angle:    %+.3f  (%.1f deg)" % [_angle_term, angle_deg],
		"  perfect:  %+.3f" % perfect_term,
		"  skill:    %+.3f" % -skill,
		"Time to arrival: %.2fs" % _time_to_arrival(),
	]
	if will_miss:
		lines.append("Miss margin: %.2f paddle heights" % lerpf(min_miss_margin,
			max_miss_margin, last_miss_chance))
	if _feint != 0.0:
		lines.append("Feint: %+.0f px" % _feint)

	debug_label.set("text", "\n".join(lines))
