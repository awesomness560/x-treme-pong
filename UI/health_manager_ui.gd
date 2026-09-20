class_name HeartBar
extends HBoxContainer

@export var heart_scene: PackedScene

var _hearts: Array[Heart] = []

func _ready() -> void:
	build(GameState.player_health)
	GameState.player_health_changed.connect(_on_player_health_changed)

func _on_player_health_changed():
	set_health(GameState.player_health)

## The only entry point. Grows or shrinks the row to match.
func set_health(value: int) -> void:
	var target := maxi(value, 0)

	while _hearts.size() > target:
		var heart: Heart = _hearts.pop_front()
		heart.lost_finished.connect(heart.queue_free)
		heart.lose()

	while _hearts.size() < target:
		_hearts.append(_add_heart(true))

## Set the row with no animation, for entering the scene.
func build(value: int) -> void:
	for child in get_children():
		child.queue_free()
	_hearts.clear()

	for i in maxi(value, 0):
		_hearts.append(_add_heart(false))

func _add_heart(animate: bool) -> Heart:
	var heart := heart_scene.instantiate() as Heart
	add_child(heart)
	if animate:
		heart.gain()
	return heart
