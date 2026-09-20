class_name BallFlame
extends ColorRect

@export var ball: Ball

@export_group("Heat")
## Seconds to fade in when the ball ignites.
@export var ignite_time: float = 0.18
## Seconds to fade out when it goes out.
@export var extinguish_time: float = 0.4
## Flame colour while ignited normally.
@export var ignite_color: Color = Color(1.0, 0.45, 0.12)

@export_group("Stretch")
## Speed at which the flame reaches full stretch.
@export var stretch_at_speed: float = 1200.0
## Speed at which it starts stretching at all.
@export var stretch_from_speed: float = 400.0
## Seconds of smoothing on the stretch, so it doesn't twitch.
@export var stretch_smoothing: float = 6.0
## The node also grows lengthwise, on top of the shader's stretch.
@export var max_length_scale: float = 1.8

@export_group("Direction")
## How fast the flame swings to a new heading. Lower = more whip.
@export var direction_lag: float = 9.0

var _mat: ShaderMaterial
var _heat := 0.0
var _stretch := 0.0
var _dir := Vector2.RIGHT
var _base_scale := Vector2.ONE
var _heat_tween: Tween

func _ready() -> void:
	_mat = material as ShaderMaterial
	_base_scale = scale
	if ball == null:
		ball = GameState.ball
	ball.ignited_changed.connect(_on_ignited_changed)
	_heat = 1.0 if ball.ignited else 0.0
	_push()

func _process(delta: float) -> void:
	if _mat == null:
		return

	var motion := ball.get_motion()
	var speed := motion.length()

	# Direction lags behind the ball, so a bounce whips the flame around.
	if speed > 1.0:
		var target := motion.normalized()
		_dir = _dir.lerp(target, 1.0 - exp(-direction_lag * delta)).normalized()

	# Stretch ramps with speed, smoothed.
	var target_stretch := clampf(inverse_lerp(stretch_from_speed, stretch_at_speed,
		speed), 0.0, 1.0)
	_stretch = lerpf(_stretch, target_stretch, 1.0 - exp(-stretch_smoothing * delta))

	# Grow the node along the flame's axis so the tail has room to draw.
	var grow := lerpf(1.0, max_length_scale, _stretch)
	scale = Vector2(_base_scale.x * grow, _base_scale.y)
	# The node is scaled in its own space, so rotate it to match the flame.
	rotation = _dir.angle()

	_push()

func _on_ignited_changed(ignited: bool) -> void:
	_set_heat(1.0 if ignited else 0.0,
		ignite_time if ignited else extinguish_time)

## Override the colour, for the ult's palette. Tweens if given a time.
func set_flame_color(color: Color, time: float = 0.0) -> void:
	if _mat == null:
		return
	if time <= 0.0:
		_mat.set_shader_parameter("flame_color", color)
		return
	var from: Color = _mat.get_shader_parameter("flame_color")
	if from == null:
		from = ignite_color
	var tween := create_tween()
	tween.tween_method(
		func(t: float): _mat.set_shader_parameter("flame_color", from.lerp(color, t)),
		0.0, 1.0, time)

## Force the heat directly, for the ult's charge ramp.
func set_heat(value: float) -> void:
	if _heat_tween and _heat_tween.is_valid():
		_heat_tween.kill()
	_heat = clampf(value, 0.0, 1.0)

func _set_heat(target: float, time: float) -> void:
	if _heat_tween and _heat_tween.is_valid():
		_heat_tween.kill()
	_heat_tween = create_tween()
	_heat_tween.tween_property(self, "_heat", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _push() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("heat", _heat)
	_mat.set_shader_parameter("stretch", _stretch)
	# The node is rotated, so the shader works in local space.
	_mat.set_shader_parameter("flame_dir", Vector2.RIGHT)
