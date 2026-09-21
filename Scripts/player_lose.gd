extends Area2D
class_name PlayerLose


func _on_body_entered(body: Node2D) -> void:
	if body is Ball:
		GameState.player_health -= 1
		GameState.player_damaged.emit()
