extends StaticBody2D

enum WallSide { TOP, BOTTOM }

@export var side: WallSide
@export var collision_shape: CollisionShape2D
@export var thickness: float = 20.0

var _shape := RectangleShape2D.new()
var _last_rect := Rect2()

func _ready() -> void:
	collision_shape.shape = _shape
	collision_shape.position = Vector2.ZERO
	_update_placement()

func _process(_delta: float) -> void:
	if _get_world_rect() != _last_rect:
		_update_placement()

func _get_world_rect() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

func _update_placement() -> void:
	var rect := _get_world_rect()
	_last_rect = rect

	_shape.size = Vector2(rect.size.x, thickness)

	var center_x := rect.position.x + rect.size.x / 2.0
	if side == WallSide.TOP:
		global_position = Vector2(center_x, rect.position.y - thickness / 2.0)
	else:
		global_position = Vector2(center_x, rect.end.y + thickness / 2.0)
