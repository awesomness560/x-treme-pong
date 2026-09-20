class_name Ball
extends CharacterBody2D

signal paddle_hit(paddle: Node2D)
signal border_hit(border: Node2D, damage: float)
signal ignited_changed(ignited: bool)
signal ignitable_changed(ignitable: bool)

signal border_broken(border: Node2D, damage: float)

@export_group("Speed")
@export var start_speed: float = 400.0
## The reachability ceiling. Set from paddle speed vs court height.
@export var max_speed: float = 1200.0
@export_range(0.0, 89.0) var max_bounce_angle_deg: float = 60.0
@export_range(0.0, 89.0) var max_launch_angle_deg: float = 30.0

@export_group("Taps")
## Taps escalate the rally by this much per hit.
@export var tap_speed_gain: float = 55.0
## Taps stop escalating here, as a fraction of max_speed.
@export_range(0.1, 1.0) var tap_ceiling: float = 0.55

@export_group("Smashes")
## Full-charge smash multiplies the arriving speed by this.
@export var smash_factor: float = 1.45
@export var perfect_factor: float = 1.8

@export_group("Enemy Returns")
## The boss returns at this fraction of what arrived. Near 1 keeps escalation.
@export var enemy_return_factor: float = 0.97
@export var enemy_min_return_speed: float = 380.0

@export_group("Ignition")
## A smash lights the ball only if it arrived at or above this speed ratio.
@export_range(0.0, 1.0) var ignite_min_ratio: float = 0.45
@export var ignite_damage_multiplier: float = 1.5
@export var sprite: Sprite2D
@export var ignited_color: Color = Color(3.0, 1.1, 0.15)
@export var color_fade_time: float = 0.12

@export_group("Border Damage")
## Damage at reference speed, and the floor of the curve.
@export var base_damage: float = 0.35
## Damage at max speed, before ignite and perfect. The cap.
@export var max_damage: float = 3.2
## Higher keeps low speeds weak and makes the top end spike.
@export_range(1.0, 5.0) var damage_exponent: float = 2.6
## Speed that counts as the bottom of the damage curve.
@export var reference_speed: float = 400.0
@export var perfect_bonus: float = 0.3
## Seconds after a border hit during which the enemy paddle can't touch the ball.
@export var border_grace_time: float = 0.35

@export_group("Serve Entrance")
## Where the ball rests before serving. Defaults to wherever it starts.
@export var serve_position: Vector2 = Vector2.ZERO
## Use the ball's own starting position instead of serve_position.
@export var use_start_position: bool = true
## How far above the serve point the ball waits.
@export var entrance_height: float = 300.0
## Time for the drop in.
@export var drop_time: float = 0.55
## How far past the serve point it overshoots, in pixels.
@export var drop_overshoot: float = 60.0
@export var settle_time: float = 0.35
## Pause at the serve point before the ball launches.
@export var serve_delay: float = 0.4

@export_group("Debug")
@export var debug_label: Control
@export var debug_enabled: bool = true

@export_group("Ultimate")
## Speed the ult launches at. Bypasses max_speed deliberately.
@export var ult_speed: float = 3000.0
## Damage the break deals, ignoring the normal formula.
@export var ult_break_damage: float = 4.0
## The collision layer the boss's paddle is on.
@export var enemy_layer: int = 3
var ult_mode := false
var _enemy_layer_saved := 0

var in_play := false
var _serve_point := Vector2.ZERO
var _entrance_tween: Tween

var ignited := false
var ignitable := false

var _speed := 0.0
var _direction := Vector2.ZERO
var _pending_factor := 0.0
var _grace_timer := 0.0
var _base_color := Color.WHITE
var _color_tween: Tween
var _last_event := "serve"
var _hit_count := 0

func _init() -> void:
	GameState.ball = self

func _ready() -> void:
	GameState.ball = self
	if sprite:
		_base_color = sprite.modulate
	_serve_point = global_position if use_start_position else serve_position
	reset_to_entrance()

## Arm the ult. The ball keeps drifting; the slow time scale does the rest.
func begin_ult() -> void:
	ult_mode = true
	_pending_factor = 0.0
	_last_event = "ult charging"
	_set_enemy_solid(false)

## Release along whatever direction it drifted to.
func launch_ult() -> void:
	_speed = ult_speed
	GameState.last_hit_was_smash = true
	_last_event = "ULT LAUNCH"

func cancel_ult() -> void:
	ult_mode = false
	_set_enemy_solid(true)

## Turns the boss's paddle intangible so the ult passes through it.
func _set_enemy_solid(solid: bool) -> void:
	var enemy := GameState.enemy
	if enemy == null:
		return
	if solid:
		if _enemy_layer_saved != 0:
			enemy.collision_layer = _enemy_layer_saved
			_enemy_layer_saved = 0
	else:
		if _enemy_layer_saved == 0:
			_enemy_layer_saved = enemy.collision_layer
			enemy.collision_layer = 0

## Kill all motion and park the ball above the serve point.
func reset_to_entrance() -> void:
	_kill_entrance()
	in_play = false
	_speed = 0.0
	_direction = Vector2.ZERO
	_pending_factor = 0.0
	_grace_timer = 0.0
	_hit_count = 0
	_last_event = "waiting"

	GameState.last_hit_was_smash = false
	GameState.last_hit_perfect = false
	_set_ignited(false)
	_update_ignitable()

	global_position = _serve_point - Vector2(0.0, entrance_height)

## Drop in, settle, pause, then serve.
func enter_and_serve() -> void:
	_kill_entrance()

	_entrance_tween = create_tween()
	# Fall in, overshooting past the serve point.
	_entrance_tween.tween_property(self, "global_position",
		_serve_point + Vector2(0.0, drop_overshoot), drop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Spring back up to rest.
	_entrance_tween.tween_property(self, "global_position", _serve_point, settle_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Beat, then go.
	_entrance_tween.tween_interval(serve_delay)
	_entrance_tween.tween_callback(_serve)

func _serve() -> void:
	in_play = true
	launch()

func _kill_entrance() -> void:
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()

func launch() -> void:
	_speed = start_speed
	_pending_factor = 0.0
	_last_event = "serve"
	_hit_count = 0
	var angle := deg_to_rad(randf_range(-max_launch_angle_deg, max_launch_angle_deg))
	var side := 1.0 if randf() < 0.5 else -1.0
	_direction = Vector2(side * cos(angle), sin(angle))
	GameState.last_hit_was_smash = false
	GameState.last_hit_perfect = false
	_set_ignited(false)
	_update_ignitable()
	paddle_hit.emit(null)

## Queue a smash. `power` is charge 0 to 1. Applied at contact.
func smash(power: float, is_perfect: bool) -> void:
	var factor := perfect_factor if is_perfect else smash_factor
	# Partial charge slides between no gain and the full factor.
	_pending_factor = lerpf(1.0, factor, clampf(power, 0.0, 1.0))

func get_motion() -> Vector2:
	return _direction * _speed

func get_speed() -> float:
	return _speed

func get_horizontal_speed() -> float:
	return absf(_direction.x * _speed)

## 0 at reference speed, 1 at max speed. The main difficulty axis.
func get_speed_ratio() -> float:
	return clampf(inverse_lerp(reference_speed, max_speed, _speed), 0.0, 1.0)

# --- Ignition ---

## True when the ball is fast enough that a smash would ignite it.
func _update_ignitable() -> void:
	var now := get_speed_ratio() >= ignite_min_ratio
	if now == ignitable:
		return
	ignitable = now
	GameState.ball_ignitable = ignitable
	ignitable_changed.emit(ignitable)
	if ignitable:
		_on_became_ignitable()
	else:
		_on_lost_ignitable()

## Hook: the ball is hot enough to ignite on a smash. Signal it to the player.
func _on_became_ignitable() -> void:
	pass

## Hook: the ball cooled below the ignition threshold.
func _on_lost_ignitable() -> void:
	pass

## Ignition is set by events, not derived from speed.
func _set_ignited(value: bool) -> void:
	if value == ignited:
		return
	ignited = value
	GameState.ball_ignited = ignited
	_apply_ignition_color()
	ignited_changed.emit(ignited)
	if ignited:
		_on_ignited()
	else:
		_on_extinguished()

## Hook for ignition effects: trail, particles, sound, screen tint.
func _on_ignited() -> void:
	pass

## Hook for the ball cooling off.
func _on_extinguished() -> void:
	pass

func _apply_ignition_color() -> void:
	if sprite == null:
		return
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	var target := ignited_color if ignited else _base_color
	_color_tween = create_tween()
	_color_tween.tween_property(sprite, "modulate", target, color_fade_time)

# --- Movement ---

func _physics_process(delta: float) -> void:
	if not in_play:
		return
	_grace_timer = maxf(_grace_timer - delta, 0.0)

	var collision := move_and_collide(_direction * _speed * delta)
	if collision == null:
		return

	var normal := collision.get_normal()
	var collider := collision.get_collider()

	if collider.is_in_group("Border"):
		_direction = _direction.bounce(normal)
		_hit_border(collider)
	elif collider is EnemyPaddle and _grace_timer > 0.0:
		pass # Just cracked the border: pass through the boss's paddle.
	elif (collider is Paddle or collider is EnemyPaddle) and absf(normal.x) > 0.5:
		_bounce_off_paddle(collision)
	else:
		_direction = _direction.bounce(normal)

# --- Border ---

func _hit_border(border: Node2D) -> void:
	if ult_mode:
		_break_border(border)
		return

	var damage := _compute_damage()
	_speed = start_speed
	_pending_factor = 0.0
	_grace_timer = border_grace_time
	_last_event = "border (%.2f dmg)" % damage
	_set_ignited(false)
	_update_ignitable()
	GameState.last_hit_was_smash = false

	GameState.take_damage.emit(damage)
	border_hit.emit(border, damage)

## The ult's payload: fixed damage, its own signal.
func _break_border(border: Node2D) -> void:
	ult_mode = false
	set_collision_mask_value(enemy_layer, true)

	_speed = start_speed
	_pending_factor = 0.0
	_grace_timer = border_grace_time
	_last_event = "ULT BREAK (%.2f dmg)" % ult_break_damage
	_set_ignited(false)
	_update_ignitable()
	GameState.last_hit_was_smash = false
	GameState.last_hit_perfect = false

	GameState.take_damage.emit(ult_break_damage)
	GameState.ult_impact.emit()
	border_broken.emit(border, ult_break_damage)

func _compute_damage() -> float:
	# Exponential from base to max across the speed range, then capped.
	var t := pow(get_speed_ratio(), damage_exponent)
	var damage := lerpf(base_damage, max_damage, t)

	var ignite_mult := ignite_damage_multiplier if ignited else 1.0
	damage *= GameState.combo_multiplier * ignite_mult
	if GameState.last_hit_perfect:
		damage += perfect_bonus
	return damage

# --- Paddle returns ---

func _bounce_off_paddle(collision: KinematicCollision2D) -> void:
	var shape_node := collision.get_collider_shape() as CollisionShape2D
	var rect := shape_node.shape as RectangleShape2D
	var half_height := rect.size.y * 0.5 * shape_node.global_scale.y

	var offset := clampf((global_position.y - shape_node.global_position.y) / half_height,
		-1.0, 1.0)

	var angle := deg_to_rad(offset * max_bounce_angle_deg)
	_direction = Vector2(signf(collision.get_normal().x) * cos(angle), sin(angle))

	var collider := collision.get_collider()
	var before := _speed

	if collider is EnemyPaddle:
		_speed = _enemy_return_speed()
		GameState.last_hit_was_smash = false
		_last_event = "boss return"
	elif _pending_factor > 1.0:
		# Ignition is earned: a smash landed while the ball was already hot.
		var hot := ignitable
		_speed = minf(_speed * _pending_factor, max_speed)
		GameState.last_hit_was_smash = true
		_last_event = "SMASH x%.2f%s" % [_pending_factor, " IGNITE" if hot else ""]
		_pending_factor = 0.0
		if hot:
			_set_ignited(true)
	else:
		_speed = _tap_speed()
		GameState.last_hit_was_smash = false
		_last_event = "tap"

	_last_event += " (%.0f -> %.0f)" % [before, _speed]
	_hit_count += 1
	_update_ignitable()
	paddle_hit.emit(collider)

## Taps escalate up to the ceiling, then hold. Never slows a fast ball.
func _tap_speed() -> float:
	var ceiling := max_speed * tap_ceiling
	if _speed >= ceiling:
		return _speed
	return minf(_speed + tap_speed_gain, ceiling)

## The boss keeps the pace, so a returned smash leaves the rally escalated.
func _enemy_return_speed() -> float:
	return clampf(_speed * enemy_return_factor, enemy_min_return_speed, max_speed)

# --- Debug ---

func _process(_delta: float) -> void:
	_write_debug()

func _write_debug() -> void:
	if not debug_enabled or debug_label == null:
		return

	var tap_cap := max_speed * tap_ceiling
	var lines := [
		"Speed: %.0f / %.0f  (ratio %.2f)" % [_speed, max_speed, get_speed_ratio()],
		"  horizontal: %.0f   angle: %.1f deg" % [get_horizontal_speed(),
			rad_to_deg(_direction.angle())],
		"Ignitable: %s" % ("YES - smash to ignite" if ignitable else "no"),
		"Ignited: %s   (needs ratio %.2f + smash)" % [
			"YES" if ignited else "no", ignite_min_ratio],
		"Tap ceiling: %.0f  (ratio %.2f)" % [tap_cap,
			clampf(inverse_lerp(reference_speed, max_speed, tap_cap), 0.0, 1.0)],
		"Last: %s  (hit #%d)" % [_last_event, _hit_count],
		"Pending smash: %s" % ("x%.2f" % _pending_factor if _pending_factor > 1.0 else "none"),
		"Border damage now: %.2f" % _compute_damage(),
	]
	debug_label.set("text", "\n".join(lines))
