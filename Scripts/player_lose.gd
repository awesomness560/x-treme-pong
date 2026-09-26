extends Area2D
class_name PlayerLose


func _on_body_entered(body: Node2D) -> void:
	if not body is Ball:
		return

	var next_health : float = GameState.player_health - 1
	if next_health <= 0 and GameState.consume_last_stand():
		next_health = 1

	GameState.player_health = next_health
	GameState.hp_lost_this_run += 1
	GameState.player_damaged.emit()

	if GameState.player_health <= 0:
		GameState.game_over.emit()
