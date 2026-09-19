class_name Paddle
extends CharacterBody2D

signal ball_hit(ball: Ball)

@export var use_mouse: bool = false

@export_group("Keys")
## Top speed when moving with keys.
@export var speed: float = 1200.0
## How fast velocity can change, in px/s per second. Lower feels heavier.
@export var responsiveness: float = 6000.0

@export_group("Mouse")
## Cap on how fast the paddle can chase the cursor.
@export var mouse_max_speed: float = 2000.0
## How hard it pulls toward the cursor. Higher tracks more exactly.
@export var follow_strength: float = 30.0
## Gap in pixels below which it just snaps, to kill micro-jitter.
@export var snap_distance: float = 2.0

var speed_scale := 1.0

var _locked_x := 0.0

func _ready() -> void:
	GameState.player = self
	_locked_x = global_position.x
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN

func _physics_process(delta: float) -> void:
	if use_mouse:
		_move_with_mouse(delta)
	else:
		_move_with_keys(delta)

	velocity.x = 0.0
	move_and_slide()
	global_position.x = _locked_x

## Chases the cursor's y as closely as it can. Position-based.
func _move_with_mouse(_delta: float) -> void:
	var max_speed := mouse_max_speed * speed_scale
	var gap := get_global_mouse_position().y - global_position.y

	if absf(gap) <= snap_distance:
		velocity.y = 0.0
		return

	# No acceleration limit: the point is to be on the cursor, not to feel heavy.
	velocity.y = clampf(gap * follow_strength, -max_speed, max_speed)

## Accelerates toward full speed while held. Velocity-based.
func _move_with_keys(delta: float) -> void:
	var direction := Input.get_axis("paddle_up", "paddle_down")
	var desired := direction * speed * speed_scale
	velocity.y = move_toward(velocity.y, desired, responsiveness * delta)
