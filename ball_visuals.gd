class_name BallSquash
extends Sprite2D

@export var ball: Ball
@export var speed_for_stretch_start: float = 500.0

@export_group("Speed Stretch")
@export var speed_for_max_stretch: float = 1000.0
@export var max_stretch: float = 0.35
@export var stretch_smoothing: float = 10.0

@export_group("Impact Squash")
@export var impact_squash: float = 0.45
@export var recover_time: float = 0.25
@export_range(0.0, 1.0) var overshoot: float = 0.3

var _base_scale := Vector2.ONE
var _base_rotation := 0.0
var _stretch := 0.0
var _impact := 0.0
var _impact_tween: Tween

func _ready() -> void:
	_base_scale = scale
	_base_rotation = rotation
	if ball == null:
		ball = GameState.ball
	ball.paddle_hit.connect(_on_hit)

func _process(delta: float) -> void:
	var motion := ball.get_motion()

	if motion.length_squared() > 1.0:
		rotation = _base_rotation + motion.angle()
	var t := clampf(inverse_lerp(speed_for_stretch_start, speed_for_max_stretch,
		motion.length()), 0.0, 1.0)
	var target := max_stretch * t * t
	_stretch = lerpf(_stretch, target, 1.0 - exp(-stretch_smoothing * delta))

	var amount := _stretch - _impact * impact_squash
	scale = _base_scale * Vector2(1.0 + amount, 1.0 / (1.0 + amount))

func _on_hit(paddle: Node2D) -> void:
	squash(1.0)

## Call this directly for any other impact (walls, smashes).
func squash(strength: float = 1.0) -> void:
	_impact = clampf(strength, 0.0, 1.0)
	if _impact_tween and _impact_tween.is_valid():
		_impact_tween.kill()
	_impact_tween = create_tween()
	if overshoot > 0.0:
		_impact_tween.tween_property(self, "_impact", -overshoot, recover_time * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(self, "_impact", 0.0, recover_time * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
