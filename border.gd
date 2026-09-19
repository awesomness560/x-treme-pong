extends StaticBody2D
class_name Border

@export var starting_health : float = 10

var health : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health = starting_health
	GameState.take_damage.connect(_take_damage)
	
func _take_damage(amount : float):
	health -= amount
	if health <= 0.0:
		GameState.boss_dead.emit()
	##Death check
	GameState.boss_new_health.emit(health / starting_health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
