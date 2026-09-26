class_name DummyBall
extends CharacterBody2D

## Cosmetic-only ball for the main menu's background rally. Reuses the real
## ball's paddle-hit angle math so it still feels like *the* ball, but speed
## never changes and nothing here touches GameState/damage/upgrades.

@export var speed: float = 400.0
@export_range(0.0, 89.0) var max_bounce_angle_deg: float = 60.0
@export_range(0.0, 89.0) var max_launch_angle_deg: float = 30.0

var _direction := Vector2.RIGHT

func _ready() -> void:
	_launch()

## Lets dummy_paddle.gd predict where this is actually headed, same as the
## real ball's get_motion() does for ai.gd.
func get_motion() -> Vector2:
	return _direction * speed

func _launch() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var angle := deg_to_rad(randf_range(-max_launch_angle_deg, max_launch_angle_deg))
	_direction = Vector2(side * cos(angle), sin(angle))

func _physics_process(delta: float) -> void:
	var collision := move_and_collide(_direction * speed * delta)
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider is DummyPaddle:
		_bounce_off_paddle(collision, collider)
	else:
		_direction = _direction.bounce(collision.get_normal()).normalized()

## Same offset-from-paddle-center -> angle formula as ball.gd's
## _bounce_off_paddle(), just without any speed change afterward.
func _bounce_off_paddle(collision: KinematicCollision2D, paddle: DummyPaddle) -> void:
	var half_height := _half_height(paddle.collision_shape)
	var offset := clampf((global_position.y - paddle.global_position.y) / half_height, -1.0, 1.0)
	var angle := deg_to_rad(offset * max_bounce_angle_deg)
	_direction = Vector2(signf(collision.get_normal().x) * cos(angle), sin(angle))

func _half_height(shape_node: CollisionShape2D) -> float:
	var rect := shape_node.shape as RectangleShape2D
	return rect.size.y * 0.5 * shape_node.global_scale.y
