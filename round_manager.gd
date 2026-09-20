extends Node2D
class_name RoundManager

@export var round_wait_time: Timer

func _ready() -> void:
	round_wait_time.start()
	await round_wait_time.timeout
	GameState.ball.enter_and_serve()
	GameState.player_health_changed.connect(_player_health_changed)
	
func _player_health_changed():
	if GameState.player_health <= 0:
		return
	GameState.ball.reset_to_entrance()
	round_wait_time.start()
	await round_wait_time.timeout
	GameState.ball.enter_and_serve()
