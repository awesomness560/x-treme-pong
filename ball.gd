class_name Ball
extends CharacterBody2D

signal paddle_hit(paddle: Node2D)

@export var start_speed: float = 400.0
@export var max_speed: float = 1000.0
@export var speed_increase: float = 1.05
@export_range(0.0, 89.0) var max_bounce_angle_deg: float = 60.0
@export_range(0.0, 89.0) var max_launch_angle_deg: float = 30.0

var _speed := 0.0
var _direction := Vector2.ZERO

func _init() -> void:
	GameState.ball = self

func _ready() -> void:
	GameState.ball = self
	launch()

func launch() -> void:
	_speed = start_speed
	var angle := deg_to_rad(randf_range(-max_launch_angle_deg, max_launch_angle_deg))
	var side := 1.0 if randf() < 0.5 else -1.0
	_direction = Vector2(side * cos(angle), sin(angle))

## Boost the ball's speed, for a smash. 1.0 leaves it unchanged.
func smash(multiplier: float) -> void:
	_speed = clampf(_speed * multiplier, 0.0, max_speed)

func get_motion() -> Vector2:
	return _direction * _speed

func get_speed() -> float:
	return _speed

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(_direction * _speed * delta)
	if collision == null:
		return

	var normal := collision.get_normal()
	var collider := collision.get_collider()
	var is_paddle := collider is Paddle or collider is EnemyPaddle
	if is_paddle and absf(normal.x) > 0.5:
		_bounce_off_paddle(collision)
	else:
		_direction = _direction.bounce(normal)

func _bounce_off_paddle(collision: KinematicCollision2D) -> void:
	var shape_node := collision.get_collider_shape() as CollisionShape2D
	var rect := shape_node.shape as RectangleShape2D
	var half_height := rect.size.y * 0.5 * shape_node.global_scale.y

	var offset := (global_position.y - shape_node.global_position.y) / half_height
	offset = clampf(offset, -1.0, 1.0)

	var angle := deg_to_rad(offset * max_bounce_angle_deg)
	_direction = Vector2(signf(collision.get_normal().x) * cos(angle), sin(angle))

	var collider := collision.get_collider()
	if collider is EnemyPaddle:
		_speed = minf(_speed * (collider as EnemyPaddle).return_speed, max_speed)
	else:
		_speed = minf(_speed * speed_increase, max_speed)

	paddle_hit.emit(collider)
