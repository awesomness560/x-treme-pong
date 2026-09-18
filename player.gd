class_name Paddle
extends CharacterBody2D

signal ball_hit(ball: Ball)

@export var speed: float = 600.0
@export var responsiveness: float = 4000.0

var speed_scale := 1.0
var _locked_x : float

func _ready() -> void:
	_locked_x = global_position.x
	GameState.player = self

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("paddle_up", "paddle_down")
	var desired := direction * speed * speed_scale

	velocity.y = move_toward(velocity.y, desired, responsiveness * delta)
	velocity.x = 0.0
	move_and_slide()
	global_position.x = _locked_x
