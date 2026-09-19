class_name Ball
extends CharacterBody2D

signal paddle_hit(paddle: Node2D)
signal border_hit(border: Node2D, damage: float)
signal ignited_changed(ignited: bool)

@export_group("Speed")
@export var start_speed: float = 400.0
@export var max_speed: float = 1000.0
@export_range(0.0, 89.0) var max_bounce_angle_deg: float = 60.0
@export_range(0.0, 89.0) var max_launch_angle_deg: float = 30.0

@export_group("Taps")
## Fraction of the arriving speed a tap returns at, once past the tap range.
@export var tap_return_factor: float = 1.0
## Speed a tap adds while below the ramp ceiling.
@export var tap_speed_gain: float = 90.0
## Taps ramp speed up to this fraction of ignite_speed, then only creep.
@export_range(0.1, 1.0) var tap_ramp_ceiling: float = 0.7
## Speed a tap adds once past the ceiling. Small, so taps never ignite alone.
@export var tap_creep_gain: float = 12.0
## Hard cap for tap-only rallies, as a fraction of ignite_speed.
@export_range(0.1, 1.0) var tap_hard_ceiling: float = 0.92

@export_group("Enemy Returns")
## Speed the boss adds while the rally is still building.
@export var enemy_speed_gain: float = 60.0
## Fraction of the arriving speed the boss returns at, once past the tap range.
@export var enemy_return_factor: float = 1.0

@export_group("Ignition")
## Speed at which the ball catches fire.
@export var ignite_speed: float = 750.0
## Drops out of ignition below this. Keep it under ignite_speed to avoid flicker.
@export var extinguish_speed: float = 650.0
@export var ignite_damage_multiplier: float = 1.5
@export var sprite: Sprite2D
@export var ignited_color: Color = Color(3.0, 1.1, 0.15)
@export var color_fade_time: float = 0.12

@export_group("Border Damage")
@export var base_damage: float = 1.0
## Ball speed that counts as "1x" damage. Usually the serve speed.
@export var reference_speed: float = 400.0
## Flat bonus when the hit that sent the ball in was a perfect smash.
@export var perfect_bonus: float = 0.5
## Seconds after a border hit during which the enemy paddle can't touch the ball.
@export var border_grace_time: float = 0.35

@export_group("Debug")
## A Label or RichTextLabel to print ball info to. Leave empty to skip.
@export var debug_label: Control
@export var debug_enabled: bool = true

var ignited := false

var _speed := 0.0
var _direction := Vector2.ZERO
var _pending_smash := 0.0
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
	launch()

func launch() -> void:
	_speed = start_speed
	_pending_smash = 0.0
	_last_event = "serve"
	_hit_count = 0
	var angle := deg_to_rad(randf_range(-max_launch_angle_deg, max_launch_angle_deg))
	var side := 1.0 if randf() < 0.5 else -1.0
	_direction = Vector2(side * cos(angle), sin(angle))
	_update_ignition()

## Queue a smash. Applied when the ball actually reaches the paddle.
func smash(multiplier: float) -> void:
	_pending_smash = maxf(multiplier, 1.0)

func get_motion() -> Vector2:
	return _direction * _speed

func get_speed() -> float:
	return _speed

## Horizontal speed only. Use this where reaction difficulty matters.
func get_horizontal_speed() -> float:
	return absf(_direction.x * _speed)

# --- Ignition ---

## Call after any speed change. Hysteresis keeps it from flickering.
func _update_ignition() -> void:
	var now := ignited
	if ignited and _speed < extinguish_speed:
		now = false
	elif not ignited and _speed >= ignite_speed:
		now = true

	if now == ignited:
		return

	ignited = now
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
		# Just cracked the border: let the ball pass through the boss's paddle.
		pass
	elif (collider is Paddle or collider is EnemyPaddle) and absf(normal.x) > 0.5:
		_bounce_off_paddle(collision)
	else:
		_direction = _direction.bounce(normal)

# --- Border ---

func _hit_border(border: Node2D) -> void:
	var damage := _compute_damage()

	# The wall absorbs the hit: the ball drops out at serve speed.
	_speed = start_speed
	_pending_smash = 0.0
	_grace_timer = border_grace_time
	_last_event = "border (%.2f dmg)" % damage
	_update_ignition()

	GameState.take_damage.emit(damage)
	border_hit.emit(border, damage)

func _compute_damage() -> float:
	var speed_ratio := _speed / maxf(reference_speed, 1.0)
	var ignite_mult := ignite_damage_multiplier if ignited else 1.0

	var damage := base_damage * speed_ratio * GameState.combo_multiplier * ignite_mult
	if GameState.last_hit_perfect:
		damage += perfect_bonus
	return damage

# --- Paddle returns ---

func _bounce_off_paddle(collision: KinematicCollision2D) -> void:
	var shape_node := collision.get_collider_shape() as CollisionShape2D
	var rect := shape_node.shape as RectangleShape2D
	var half_height := rect.size.y * 0.5 * shape_node.global_scale.y

	var offset := (global_position.y - shape_node.global_position.y) / half_height
	offset = clampf(offset, -1.0, 1.0)

	var angle := deg_to_rad(offset * max_bounce_angle_deg)
	_direction = Vector2(signf(collision.get_normal().x) * cos(angle), sin(angle))

	var collider := collision.get_collider()
	var before := _speed
	if collider is EnemyPaddle:
		_speed = _enemy_return_speed()
		_last_event = "boss return"
	elif _pending_smash > 1.0:
		_speed = clampf(_speed * _pending_smash, 0.0, max_speed)
		_last_event = "SMASH %.2fx" % _pending_smash
		_pending_smash = 0.0
	else:
		_speed = _tap_speed()
		_last_event = "tap"

	_last_event += " (%.0f -> %.0f)" % [before, _speed]
	_hit_count += 1

	_update_ignition()
	paddle_hit.emit(collider)

## Taps build the rally below the ceiling, and preserve speed above it.
func _tap_speed() -> float:
	var ceiling := ignite_speed * tap_ramp_ceiling
	var hard_cap := ignite_speed * tap_hard_ceiling
	if _speed < ceiling:
		return minf(_speed + tap_speed_gain, ceiling)
	if _speed <= hard_cap:
		return minf(_speed + tap_creep_gain, hard_cap)
	# Already faster than taps can build: keep it, minus a little.
	return minf(_speed * tap_return_factor, max_speed)

## Builds the rally below the tap ceiling, decays smashes above it.
func _enemy_return_speed() -> float:
	var ceiling := ignite_speed * tap_hard_ceiling
	if _speed <= ceiling:
		return minf(_speed + enemy_speed_gain, ceiling)
	# Past the tap range: bleed speed off, but never below the build ceiling.
	return clampf(_speed * enemy_return_factor, ceiling, max_speed)

# --- Debug ---

func _process(_delta: float) -> void:
	_write_debug()

func _write_debug() -> void:
	if not debug_enabled or debug_label == null:
		return

	var ceiling := ignite_speed * tap_ramp_ceiling
	var hard_cap := ignite_speed * tap_hard_ceiling

	var lines := [
		"Speed: %.0f / %.0f px/s" % [_speed, max_speed],
		"  horizontal: %.0f" % get_horizontal_speed(),
		"  angle: %.1f deg" % rad_to_deg(_direction.angle()),
		"Ignited: %s" % ("YES" if ignited else "no"),
		"  ignite at %.0f, out at %.0f" % [ignite_speed, extinguish_speed],
		"Tap range: %.0f -> %.0f (cap %.0f)" % [start_speed, ceiling, hard_cap],
		"Last event: %s  (hit #%d)" % [_last_event, _hit_count],
		"Pending smash: %s" % ("%.2fx" % _pending_smash if _pending_smash > 1.0 else "none"),
		"Border grace: %.2fs" % _grace_timer,
		"Next border damage: %.2f" % _compute_damage(),
	]
	debug_label.set("text", "\n".join(lines))
